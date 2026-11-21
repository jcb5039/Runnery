// 러너리 서버 함수. Firebase가 직접 지원하지 않는 카카오(나중에 네이버) 로그인을 Firebase 계정으로 바꿔 줍니다.
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { KakaoTokenError, verifyKakaoToken } = require('./kakao');

initializeApp();

/**
 * 카카오 로그인: 앱이 보낸 카카오 액세스 토큰을 확인하고 Firebase 로그인 표(커스텀 토큰)를 돌려줍니다.
 * 계정 이름(uid)은 `kakao:카카오회원번호`라서 같은 카카오 계정은 늘 같은 러너리 계정이 됩니다.
 * 카카오에서 이름·사진·이메일은 받지 않습니다.
 */
exports.kakaoLogin = onCall({ region: 'asia-northeast3', maxInstances: 10 }, async (request) => {
  let kakaoId;
  try {
    kakaoId = await verifyKakaoToken(request.data && request.data.accessToken);
  } catch (e) {
    if (e instanceof KakaoTokenError) throw new HttpsError('unauthenticated', e.message);
    logger.error('카카오 확인 실패', e);
    throw new HttpsError('unavailable', '카카오 로그인을 확인하지 못했어요. 잠시 후 다시 시도해주세요');
  }
  const uid = `kakao:${kakaoId}`;
  const auth = getAuth();
  try {
    await auth.getUser(uid);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    await auth.createUser({ uid });
  }
  const customToken = await auth.createCustomToken(uid, { provider: 'kakao' });
  return { customToken };
});
