// 카카오 로그인 확인: 앱이 보낸 카카오 확인 표(액세스 토큰)가 진짜이고 우리 앱에서 받은 것인지 카카오에 묻습니다.

/** 카카오 개발자 콘솔의 러너리 앱 ID. 공개 값이라 코드에 둡니다. */
const KAKAO_APP_ID = 1660545;

class KakaoTokenError extends Error {}

/**
 * 토큰이 우리 앱의 유효한 카카오 토큰이면 카카오 회원번호(문자열)를 돌려줍니다.
 * 아니면 KakaoTokenError를 던집니다.
 * @param {unknown} accessToken
 * @param {typeof fetch} fetchImpl 테스트에서 가짜를 넣습니다.
 */
async function verifyKakaoToken(accessToken, fetchImpl = fetch) {
  if (typeof accessToken !== 'string' || accessToken.length < 10 || accessToken.length > 2000) {
    throw new KakaoTokenError('카카오 확인 표가 올바르지 않아요');
  }
  let response;
  try {
    response = await fetchImpl('https://kapi.kakao.com/v1/user/access_token_info', {
      headers: { Authorization: `Bearer ${accessToken}` },
      signal: AbortSignal.timeout(10000),
    });
  } catch (_) {
    throw new Error('카카오 서버에 닿지 못했어요');
  }
  if (response.status === 401 || response.status === 400) {
    throw new KakaoTokenError('카카오 로그인이 만료됐어요. 다시 시도해주세요');
  }
  if (!response.ok) throw new Error(`카카오 서버 오류 ${response.status}`);
  const info = await response.json();
  // 다른 앱에서 받은 토큰으로 우리 계정에 들어오지 못하게 앱 ID를 확인합니다.
  if (Number(info.app_id) !== KAKAO_APP_ID || info.id == null) {
    throw new KakaoTokenError('러너리에서 받은 카카오 로그인이 아니에요');
  }
  return String(info.id);
}

module.exports = { KAKAO_APP_ID, KakaoTokenError, verifyKakaoToken };
