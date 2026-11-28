// 러너리 서버 함수. Firebase가 직접 지원하지 않는 카카오·네이버 로그인을 Firebase 계정으로 바꿔 주고,
// 회원 탈퇴 때 서버 데이터를 지웁니다. 크루 함께 달리기 모집(대기실)과 크루 초대 코드의 규칙도 여기서 지킵니다.
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore, Timestamp } = require('firebase-admin/firestore');
const { ProofError, checkProof, deleteUserData } = require('./delete_account');
const { KakaoTokenError, verifyKakaoToken } = require('./kakao');
const { NaverLoginError, naverIdFromCode, stateFor, validState } = require('./naver');
const { RunError, decide, decideTick } = require('./crew_run');
const { CodeError, makeCode, normalizeCode, decideJoin, decideIssue } = require('./crew_code');
const { randomInt } = require('node:crypto');

initializeApp();

const REGION = 'asia-northeast3';

/** 네이버 Client Secret. `firebase functions:secrets:set NAVER_CLIENT_SECRET`로 넣고 코드·GitHub에는 두지 않습니다. */
const naverClientSecret = defineSecret('NAVER_CLIENT_SECRET');

/** 네이버 로그인 웹 화면이 끝나면 돌아갈 앱 주소. */
const NAVER_APP_CALLBACK = 'runnerynaverlogin://callback';

/** 네이버 로그인을 마친 뒤 앱이 결과를 가져갈 수 있는 시간. */
const NAVER_LOGIN_TTL_MS = 5 * 60 * 1000;

/** 계정이 없으면 만들고 Firebase 로그인 표(커스텀 토큰)를 만듭니다. */
async function customTokenFor(uid, provider) {
  const auth = getAuth();
  try {
    await auth.getUser(uid);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    await auth.createUser({ uid });
  }
  return auth.createCustomToken(uid, { provider });
}

/**
 * 카카오 로그인: 앱이 보낸 카카오 액세스 토큰을 확인하고 Firebase 로그인 표(커스텀 토큰)를 돌려줍니다.
 * 계정 이름(uid)은 `kakao:카카오회원번호`라서 같은 카카오 계정은 늘 같은 러너리 계정이 됩니다.
 * 카카오에서 이름·사진·이메일은 받지 않습니다.
 */
exports.kakaoLogin = onCall({ region: REGION, maxInstances: 10 }, async (request) => {
  let kakaoId;
  try {
    kakaoId = await verifyKakaoToken(request.data && request.data.accessToken);
  } catch (e) {
    if (e instanceof KakaoTokenError) throw new HttpsError('unauthenticated', e.message);
    logger.error('카카오 확인 실패', e);
    throw new HttpsError('unavailable', '카카오 로그인을 확인하지 못했어요. 잠시 후 다시 시도해주세요');
  }
  return { customToken: await customTokenFor(`kakao:${kakaoId}`, 'kakao') };
});

/**
 * 네이버 로그인 1단계: 네이버 로그인 웹 화면이 끝나면 네이버가 이 주소로 확인 코드를 보냅니다.
 * 비밀 키로 코드를 바꿔 네이버 회원번호를 얻고, 결과(계정 이름)를 잠깐 저장한 뒤 앱으로 돌려보냅니다.
 * 로그인 표는 여기서 넘기지 않습니다. 앱 주소는 다른 앱이 가로챌 수 있어, 표는 2단계(naverFinish)에서
 * 처음에 앱이 만든 확인 값을 가진 쪽에만 줍니다. 네이버에서 이름·이메일 같은 정보는 받지 않습니다.
 */
exports.naverCallback = onRequest(
  { region: REGION, secrets: [naverClientSecret], invoker: 'public', maxInstances: 10 },
  async (req, res) => {
    const { code, state, error } = req.query;
    const back = (query) => res.redirect(302, `${NAVER_APP_CALLBACK}?${new URLSearchParams(query)}`);
    if (!validState(state)) return back({ error: 'state' });
    if (error) return back({ error: error === 'access_denied' ? 'cancel' : 'naver', state });
    try {
      const naverId = await naverIdFromCode({ code, state, clientSecret: naverClientSecret.value() });
      await getFirestore()
        .collection('naverLogins')
        .doc(state)
        .set({ uid: `naver:${naverId}`, expiresAt: Timestamp.fromMillis(Date.now() + NAVER_LOGIN_TTL_MS) });
      return back({ state });
    } catch (e) {
      logger.error('네이버 로그인 확인 실패', e instanceof NaverLoginError ? e.message : e);
      return back({ error: 'naver', state });
    }
  },
);

/**
 * 네이버 로그인 2단계: 앱이 처음에 만든 확인 값(verifier)을 보내면, 1단계 결과를 꺼내(한 번만) 로그인 표를 줍니다.
 * 저장소(naverLogins)는 보안 규칙상 앱에서 직접 읽을 수 없고 서버만 씁니다.
 */
exports.naverFinish = onCall({ region: REGION, maxInstances: 10 }, async (request) => {
  const verifier = request.data && request.data.verifier;
  if (!validVerifier(verifier)) {
    throw new HttpsError('invalid-argument', '네이버 로그인 요청이 올바르지 않아요');
  }
  const uid = await takeNaverLogin(verifier);
  if (!uid) throw new HttpsError('not-found', '네이버 로그인이 만료됐어요. 다시 시도해주세요');
  return { customToken: await customTokenFor(uid, 'naver') };
});

function validVerifier(verifier) {
  return typeof verifier === 'string' && verifier.length >= 32 && verifier.length <= 200;
}

/** 네이버 로그인 1단계 결과(계정 이름)를 한 번만 꺼냅니다. 없거나 만료됐으면 null. */
async function takeNaverLogin(verifier) {
  if (!validVerifier(verifier)) return null;
  const db = getFirestore();
  const ref = db.collection('naverLogins').doc(stateFor(verifier));
  const snapshot = await db.runTransaction(async (t) => {
    const found = await t.get(ref);
    if (found.exists) t.delete(ref);
    return found;
  });
  if (!snapshot.exists || snapshot.get('expiresAt').toMillis() < Date.now()) return null;
  return snapshot.get('uid');
}

/**
 * 회원 탈퇴: 본인 확인을 한 뒤 서버 데이터(러닝 기록, 프로필, 아이디, 친구 데이터)를 모두 지우고
 * 마지막에 로그인 계정을 지웁니다. 관리자 권한으로 지우므로 보안 규칙을 풀지 않습니다.
 * 본인 확인은 delete_account.js의 checkProof를 봅니다. 중간에 실패해도 다시 부르면 이어 지웁니다.
 */
exports.deleteAccount = onCall({ region: REGION, maxInstances: 10, timeoutSeconds: 300 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', '로그인이 필요해요');
  const uid = request.auth.uid;
  try {
    await checkProof({
      uid,
      authTime: request.auth.token.auth_time,
      data: request.data,
      now: Date.now(),
      verifyKakao: verifyKakaoToken,
      takeNaverLogin,
    });
  } catch (e) {
    if (e instanceof ProofError || e instanceof KakaoTokenError) {
      throw new HttpsError('permission-denied', e instanceof ProofError ? e.message : '카카오 로그인을 확인하지 못했어요. 다시 시도해주세요');
    }
    logger.error('탈퇴 본인 확인 실패', e);
    throw new HttpsError('unavailable', '본인 확인을 하지 못했어요. 잠시 후 다시 시도해주세요');
  }
  try {
    await deleteUserData(getFirestore(), uid, FieldValue);
    await getAuth().deleteUser(uid).catch((e) => {
      if (e.code !== 'auth/user-not-found') throw e;
    });
  } catch (e) {
    logger.error('탈퇴 데이터 삭제 실패', uid, e);
    throw new HttpsError('internal', '탈퇴하지 못했어요. 잠시 후 다시 시도해주세요');
  }
  logger.info('회원 탈퇴 완료', uid);
  return { ok: true };
});

/** 서버 시각(밀리초) ↔ Firestore 시각. 모집 판단은 밀리초로 합니다. */
function runFromDoc(d) {
  if (!d) return null;
  const ms = (v) => (v && typeof v.toMillis === 'function' ? v.toMillis() : v == null ? null : v);
  const results = {};
  for (const [k, v] of Object.entries(d.results || {})) results[k] = { ...v, finishedAt: ms(v.finishedAt) };
  return {
    ...d,
    results,
    createdAt: ms(d.createdAt),
    startedAt: ms(d.startedAt),
    endedAt: ms(d.endedAt),
  };
}

function runToDoc(r) {
  const ts = (v) => (v == null ? null : Timestamp.fromMillis(v));
  const results = {};
  for (const [k, v] of Object.entries(r.results || {})) results[k] = { ...v, finishedAt: ts(v.finishedAt) };
  return {
    ...r,
    results,
    createdAt: ts(r.createdAt),
    startedAt: ts(r.startedAt),
    endedAt: ts(r.endedAt),
  };
}

/**
 * 크루 함께 달리기 모집: 열기(create)·참여(join)·색 고르기(color)·준비(ready)·나가기(leave)·시작(start),
 * 출발한 뒤 각자 끝내기(finish)·팀장의 팀 끝내기(end).
 * 한 사람이 모집 하나만 열고 하나에만 참여하기, 10명 제한, 팀장이 나가면 닫기처럼 여러 사람이 동시에 눌러도
 * 지켜야 하는 규칙이라 서버가 트랜잭션으로 한 번에 하나씩 처리합니다. 판단은 crew_run.js의 decide를 봅니다.
 * 앱은 모집 문서를 읽기만 하고(보안 규칙에서 쓰기를 막음), 바꾸는 건 모두 이 함수로 합니다.
 */
exports.crewRun = onCall({ region: REGION, maxInstances: 20 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', '로그인이 필요해요');
  const uid = request.auth.uid;
  const data = request.data || {};
  const action = String(data.action || '');
  const crewId = typeof data.crewId === 'string' ? data.crewId : '';
  if (!crewId) throw new HttpsError('invalid-argument', '크루를 찾을 수 없어요');
  const db = getFirestore();
  const crewRef = db.collection('crews').doc(crewId);
  const runRef = action === 'create'
    ? crewRef.collection('runs').doc()
    : crewRef.collection('runs').doc(typeof data.runId === 'string' && data.runId ? data.runId : '_');
  const lockRef = (who) => db.collection('crewRunners').doc(who);
  try {
    await db.runTransaction(async (t) => {
      const crewSnap = await t.get(crewRef);
      const runSnap = action === 'create' ? null : await t.get(runRef);
      const lockSnap = await t.get(lockRef(uid));
      const lock = lockSnap.exists ? lockSnap.data() : null;
      let lockRun = null;
      if (lock && lock.crewId && lock.runId) {
        const ref = db.collection('crews').doc(lock.crewId).collection('runs').doc(lock.runId);
        lockRun = runFromDoc((await t.get(ref)).data());
      }
      const run = runSnap && runSnap.exists ? runFromDoc(runSnap.data()) : null;
      // 참여할 때만 차단 관계를 읽습니다(한쪽이라도 차단했으면 같은 모집에 못 들어감).
      const blockedPairs = new Set();
      if (action === 'join' && run) {
        for (const m of run.members || []) {
          const [mine, theirs] = await Promise.all([
            t.get(db.collection('users').doc(uid).collection('blocks').doc(m)),
            t.get(db.collection('users').doc(m).collection('blocks').doc(uid)),
          ]);
          if (mine.exists || theirs.exists) blockedPairs.add(m);
        }
      }
      // 팀 끝내기·종료 투표는 아직 달리는 사람의 지금 기록(실시간 상태)으로 팀 기록을 남깁니다.
      const live = action === 'end' || action === 'vote' ? await readLive(t, runRef, run) : {};
      const result = decide({
        live,
        action,
        uid,
        crew: crewSnap.exists ? crewSnap.data() : null,
        run,
        runId: action === 'create' ? null : runRef.id,
        lockRun,
        lockId: lock ? lock.runId : null,
        blocked: (a, b) => (a === uid ? blockedPairs.has(b) : blockedPairs.has(a)),
        now: Date.now(),
        data,
      });
      // 다른 모집을 붙잡고 있는 사람의 기록은 지우지 않도록, 풀기 전에 그 사람의 기록을 읽어 둡니다.
      const clears = [];
      for (const who of result.lockClear || []) {
        const snap = who === uid ? lockSnap : await t.get(lockRef(who));
        if (snap.exists && snap.get('runId') === runRef.id) clears.push(who);
      }
      writeRun(t, db, crewId, runRef, result, clears);
      for (const who of result.lockSet || []) {
        t.set(lockRef(who), { crewId, runId: runRef.id });
      }
      if (result.message) {
        t.set(crewRef.collection('messages').doc(), {
          uid,
          kind: 'run',
          runId: runRef.id,
          title: result.message.title,
          createdAt: FieldValue.serverTimestamp(),
        });
        t.update(crewRef, {
          lastMessage: {
            uid,
            text: `함께 달리기를 열었어요: ${result.message.title}`.slice(0, 100),
            at: FieldValue.serverTimestamp(),
          },
        });
      }
    });
  } catch (e) {
    if (e instanceof RunError) throw new HttpsError('failed-precondition', e.message);
    logger.error('크루 모집 실패', action, crewId, uid, e);
    throw new HttpsError('internal', '잠시 후 다시 시도해주세요');
  }
  return { ok: true, runId: runRef.id };
});

/**
 * 크루 초대 코드: 코드 만들기·바꾸기(issue, 크루장만)와 코드로 들어가기(join). 판단은 crew_code.js를 봅니다.
 * 코드로 크루를 찾는 crewCodes 문서는 앱이 읽지 못해서, 코드를 모르면 크루를 찾을 수 없습니다.
 * 친구가 아니어도 코드만 있으면 들어올 수 있고, 크루장이 내보낸 사람(banned)은 코드로 못 들어옵니다.
 */
exports.crewCode = onCall({ region: REGION, maxInstances: 20 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', '로그인이 필요해요');
  const uid = request.auth.uid;
  const data = request.data || {};
  const action = String(data.action || '');
  const db = getFirestore();
  try {
    if (action === 'issue') {
      const crewId = typeof data.crewId === 'string' ? data.crewId : '';
      if (!crewId) throw new CodeError('크루를 찾을 수 없어요');
      const crewRef = db.collection('crews').doc(crewId);
      // 드물게 이미 쓰는 코드가 나오면 다시 뽑습니다.
      for (let i = 0; i < 5; i++) {
        const code = makeCode(() => randomInt(1e9) / 1e9);
        const done = await db.runTransaction(async (t) => {
          const crewSnap = await t.get(crewRef);
          const codeRef = db.collection('crewCodes').doc(code);
          const codeSnap = await t.get(codeRef);
          const crew = crewSnap.exists ? crewSnap.data() : null;
          decideIssue({ crew, uid });
          if (codeSnap.exists) return false;
          // 예전 코드는 지워서 더는 들어올 수 없게 합니다.
          if (crew.code) t.delete(db.collection('crewCodes').doc(crew.code));
          t.set(codeRef, { crewId, createdAt: FieldValue.serverTimestamp() });
          t.update(crewRef, { code });
          return true;
        });
        if (done) return { ok: true, code };
      }
      throw new Error('코드를 만들지 못함');
    }
    if (action === 'join') {
      const code = normalizeCode(data.code);
      if (!code) throw new CodeError('코드 6자리를 확인해 주세요');
      const codeSnap = await db.collection('crewCodes').doc(code).get();
      const crewId = codeSnap.exists ? String(codeSnap.get('crewId') || '') : '';
      if (!crewId) throw new CodeError('코드를 다시 확인해 주세요');
      const crewRef = db.collection('crews').doc(crewId);
      await db.runTransaction(async (t) => {
        const crewSnap = await t.get(crewRef);
        const crew = crewSnap.exists ? crewSnap.data() : null;
        const owner = crew && crew.owner;
        const [bannedSnap, mine, theirs] = await Promise.all([
          t.get(crewRef.collection('banned').doc(uid)),
          owner ? t.get(db.collection('users').doc(uid).collection('blocks').doc(owner)) : null,
          owner ? t.get(db.collection('users').doc(owner).collection('blocks').doc(uid)) : null,
        ]);
        const result = decideJoin({
          crew,
          code,
          uid,
          banned: bannedSnap.exists,
          blocked: Boolean((mine && mine.exists) || (theirs && theirs.exists)),
        });
        if (result === 'member') return;
        t.update(crewRef, { members: FieldValue.arrayUnion(uid) });
        t.set(crewRef.collection('members').doc(uid), {
          joinedAt: FieldValue.serverTimestamp(),
          lastReadAt: FieldValue.serverTimestamp(),
          muted: false,
        });
        t.set(crewRef.collection('messages').doc(), {
          uid,
          kind: 'join',
          createdAt: FieldValue.serverTimestamp(),
        });
        // 받아 둔 초대가 있으면 함께 지웁니다.
        t.delete(db.collection('crewInvites').doc(`${crewId}_${uid}`));
      });
      return { ok: true, crewId };
    }
    throw new CodeError('잠시 후 다시 시도해주세요');
  } catch (e) {
    if (e instanceof CodeError) throw new HttpsError('failed-precondition', e.message);
    logger.error('크루 코드 실패', action, uid, e);
    throw new HttpsError('internal', '잠시 후 다시 시도해주세요');
  }
});

/** 모집 참여자들의 지금 실시간 상태(거리·시간). 트랜잭션 안에서 읽습니다. */
async function readLive(t, runRef, run) {
  const live = {};
  for (const m of (run && run.members) || []) {
    const snap = await t.get(runRef.collection('live').doc(m));
    if (snap.exists) live[m] = { distanceKm: snap.get('distanceKm') || 0, movingSeconds: snap.get('movingSeconds') || 0 };
  }
  return live;
}

/**
 * 판단 결과를 씁니다: 모집 문서, 풀어 줄 사람(clears, 미리 확인한 사람만), 서버가 지켜볼 출발한 모집 목록
 * (crewActiveRuns: 5분마다 종료 투표를 살피는 데 씁니다).
 */
function writeRun(t, db, crewId, runRef, result, clears) {
  if (result.run) t.set(runRef, runToDoc(result.run));
  for (const who of clears) t.delete(db.collection('crewRunners').doc(who));
  const active = db.collection('crewActiveRuns').doc(`${crewId}_${runRef.id}`);
  if (result.activeSet) t.set(active, { crewId, runId: runRef.id });
  if (result.activeClear) t.delete(active);
}

/**
 * 출발한 크루 모집을 5분마다 살핍니다: 2시간이 지나면 종료 투표를 열고, 30분 동안 '끝내지 않기'가 없으면
 * 팀을 끝내며(그때의 기록이 팀 기록), 있으면 투표를 다시 엽니다. 앱이 모두 꺼져 있어도 지켜집니다.
 */
exports.crewRunTick = onSchedule({ region: REGION, schedule: 'every 5 minutes', timeZone: 'Asia/Seoul' }, async () => {
  const db = getFirestore();
  const active = await db.collection('crewActiveRuns').limit(200).get();
  for (const doc of active.docs) {
    const { crewId, runId } = doc.data();
    if (!crewId || !runId) {
      await doc.ref.delete();
      continue;
    }
    const runRef = db.collection('crews').doc(crewId).collection('runs').doc(runId);
    try {
      await db.runTransaction(async (t) => {
        const run = runFromDoc((await t.get(runRef)).data());
        const live = await readLive(t, runRef, run);
        const result = decideTick(run, live, Date.now());
        const clears = [];
        for (const who of result.lockClear || []) {
          const snap = await t.get(db.collection('crewRunners').doc(who));
          if (snap.exists && snap.get('runId') === runId) clears.push(who);
        }
        writeRun(t, db, crewId, runRef, result, clears);
      });
    } catch (e) {
      logger.error('크루 모집 살피기 실패', crewId, runId, e);
    }
  }
});
