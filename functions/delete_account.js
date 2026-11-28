// 회원 탈퇴: 본인 확인과 서버 데이터 지우기.
// 본인 확인은 진짜 서버를 부르지 않고 시험할 수 있게 필요한 함수(카카오 확인, 네이버 결과 꺼내기)를 받아서 씁니다.

/** 이메일·구글 계정은 로그인(본인 확인)한 지 이 시간 안이어야 탈퇴할 수 있습니다. */
const RECENT_LOGIN_MS = 5 * 60 * 1000;

/** 본인 확인이 맞지 않을 때. [message]는 앱 화면에 그대로 보여 줍니다. */
class ProofError extends Error {}

/**
 * 탈퇴를 요청한 사람이 계정 주인인지 확인합니다.
 * - 카카오 계정(`kakao:번호`): 방금 받은 카카오 토큰의 회원번호가 같아야 합니다.
 * - 네이버 계정(`naver:번호`): 방금 마친 네이버 로그인 결과의 계정이 같아야 합니다.
 * - 그 밖(이메일·구글): 앱이 방금 다시 로그인(비밀번호·구글)해서 로그인 시각이 5분 안이어야 합니다.
 */
async function checkProof({ uid, authTime, data, now, verifyKakao, takeNaverLogin }) {
  if (uid.startsWith('kakao:')) {
    const kakaoId = await verifyKakao(data && data.kakaoAccessToken);
    if (`kakao:${kakaoId}` !== uid) throw new ProofError('가입한 카카오 계정으로 로그인해주세요');
    return;
  }
  if (uid.startsWith('naver:')) {
    const found = await takeNaverLogin(data && data.naverVerifier);
    if (!found) throw new ProofError('네이버 로그인이 만료됐어요. 다시 시도해주세요');
    if (found !== uid) throw new ProofError('가입한 네이버 계정으로 로그인해주세요');
    return;
  }
  if (typeof authTime !== 'number' || now - authTime * 1000 > RECENT_LOGIN_MS) {
    throw new ProofError('본인 확인이 만료됐어요. 다시 시도해주세요');
  }
}

/** 문서들을 500개씩 나눠 지웁니다. */
async function deleteRefs(db, refs) {
  for (let i = 0; i < refs.length; i += 500) {
    const batch = db.batch();
    for (const ref of refs.slice(i, i + 500)) batch.delete(ref);
    await batch.commit();
  }
}

/**
 * 한 계정의 서버 데이터를 모두 지웁니다. 중간에 실패해도 다시 부르면 남은 것부터 이어 지웁니다.
 * 다른 사람 문서에 걸친 것(친구 목록, 응원, 친구 요청, 함께 달리기, 크루, 크루 초대)을 먼저 정리하고,
 * 내 문서(`users/{uid}` 아래 전부, 공개 프로필, 아이디)를 지웁니다. 로그인 계정은 부르는 쪽이 마지막에 지웁니다.
 */
async function deleteUserData(db, uid, FieldValue) {
  const userRef = db.collection('users').doc(uid);

  // 1. 친구들 목록에서 나를 빼고, 친구 글에 남긴 내 응원을 지웁니다.
  const friends = await userRef.collection('friends').get();
  for (const friend of friends.docs) {
    const friendRef = db.collection('users').doc(friend.id);
    const posts = await friendRef.collection('posts').get();
    await deleteRefs(db, [
      friendRef.collection('friends').doc(uid),
      ...posts.docs.map((p) => p.ref.collection('cheers').doc(uid)),
    ]);
  }

  // 2. 내가 보내거나 받은 친구 요청.
  const [sent, received] = await Promise.all([
    db.collection('friendRequests').where('from', '==', uid).get(),
    db.collection('friendRequests').where('to', '==', uid).get(),
  ]);
  await deleteRefs(db, [...sent.docs, ...received.docs].map((d) => d.ref));

  // 3. 함께 달리기: 내가 만든 약속(또는 나를 빼면 혼자 남는 약속)은 지우고, 아니면 나만 뺍니다.
  const togethers = await db.collection('together').where('members', 'array-contains', uid).get();
  for (const t of togethers.docs) {
    const members = t.get('members') || [];
    if (t.get('host') === uid || members.length <= 2) {
      await db.recursiveDelete(t.ref);
    } else {
      await t.ref.update({
        members: FieldValue.arrayRemove(uid),
        [`statuses.${uid}`]: FieldValue.delete(),
      });
      await t.ref.collection('live').doc(uid).delete();
    }
  }

  // 4. 크루: 혼자 남은 크루는 지우고, 방장이면 가장 오래된 멤버에게 넘긴 뒤 나만 뺍니다.
  //    채팅 메시지는 남기되(다른 멤버의 대화), 내 멤버 정보와 내가 보내거나 받은 초대는 지웁니다.
  const crews = await db.collection('crews').where('members', 'array-contains', uid).get();
  for (const crew of crews.docs) {
    const others = (crew.get('members') || []).filter((m) => m !== uid);
    if (others.length === 0) {
      await db.recursiveDelete(crew.ref);
      continue;
    }
    // 함께 달린 모집에 남은 내 위치·지나간 길(실시간 상태, 팀 기록의 길)도 지웁니다. 팀 기록의 거리·시간은 남깁니다.
    const runs = await crew.ref.collection('runs').select().get();
    await deleteRefs(
      db,
      runs.docs.flatMap((r) => [r.ref.collection('live').doc(uid), r.ref.collection('routes').doc(uid)]),
    );
    const update = { members: FieldValue.arrayRemove(uid) };
    if (crew.get('owner') === uid) {
      update.owner = await oldestMember(crew.ref, others);
    }
    await crew.ref.update(update);
    await crew.ref.collection('members').doc(uid).delete();
  }
  // 들어가 있던 크루 모집: 팀장이면 모집을 닫고(다른 참여자도 풀어 줌), 아니면 나만 뺍니다.
  const lockRef = db.collection('crewRunners').doc(uid);
  const lock = await lockRef.get();
  if (lock.exists && lock.get('crewId') && lock.get('runId')) {
    const runRef = db.collection('crews').doc(lock.get('crewId')).collection('runs').doc(lock.get('runId'));
    const run = await runRef.get();
    if (run.exists && run.get('status') === 'open') {
      if (run.get('host') === uid) {
        await runRef.update({ status: 'closed' });
        await deleteRefs(db, (run.get('members') || []).map((m) => db.collection('crewRunners').doc(m)));
      } else {
        await runRef.update({
          members: FieldValue.arrayRemove(uid),
          [`colors.${uid}`]: FieldValue.delete(),
          [`ready.${uid}`]: FieldValue.delete(),
        });
      }
    }
    await lockRef.delete();
  }
  const [invitesSent, invitesReceived] = await Promise.all([
    db.collection('crewInvites').where('from', '==', uid).get(),
    db.collection('crewInvites').where('to', '==', uid).get(),
  ]);
  await deleteRefs(db, [...invitesSent.docs, ...invitesReceived.docs].map((d) => d.ref));

  // 5. 아이디(내 것일 때만)와 공개 프로필.
  const profile = await userRef.get();
  const id = profile.exists ? profile.get('id') : null;
  if (typeof id === 'string' && id) {
    const idRef = db.collection('usernames').doc(id);
    const owner = await idRef.get();
    if (owner.exists && owner.get('uid') === uid) await idRef.delete();
  }
  await db.collection('profiles').doc(uid).delete();

  // 6. 내 문서 아래 전부: 러닝 기록, 설정, 합계, 친구 목록, 공유한 기록과 응원.
  await db.recursiveDelete(userRef);
}

/**
 * 남은 멤버 [others] 중 크루에 가장 먼저 들어온 사람. 들어온 시각이 없으면 멤버 목록 순서대로 고릅니다.
 */
async function oldestMember(crewRef, others) {
  const members = await crewRef.collection('members').orderBy('joinedAt').get();
  const first = members.docs.find((m) => others.includes(m.id));
  return first ? first.id : others[0];
}

module.exports = { RECENT_LOGIN_MS, ProofError, checkProof, deleteUserData, oldestMember };
