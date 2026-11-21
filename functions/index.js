// 러너리 서버 함수. Firebase가 직접 지원하지 않는 카카오·네이버 로그인을 Firebase 계정으로 바꿔 줍니다.
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { KakaoTokenError, verifyKakaoToken } = require('./kakao');
const { NaverLoginError, naverIdFromCode, stateFor, validState } = require('./naver');

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
  if (typeof verifier !== 'string' || verifier.length < 32 || verifier.length > 200) {
    throw new HttpsError('invalid-argument', '네이버 로그인 요청이 올바르지 않아요');
  }
  const db = getFirestore();
  const ref = db.collection('naverLogins').doc(stateFor(verifier));
  const snapshot = await db.runTransaction(async (t) => {
    const found = await t.get(ref);
    if (found.exists) t.delete(ref);
    return found;
  });
  if (!snapshot.exists || snapshot.get('expiresAt').toMillis() < Date.now()) {
    throw new HttpsError('not-found', '네이버 로그인이 만료됐어요. 다시 시도해주세요');
  }
  return { customToken: await customTokenFor(snapshot.get('uid'), 'naver') };
});
