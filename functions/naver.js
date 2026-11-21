// 네이버 로그인 확인: 네이버 로그인 웹 화면이 우리 서버로 보낸 확인 코드를 우리 앱의 비밀 키로 바꿔
// 네이버 회원번호를 얻습니다. 비밀 키가 있어야 바꿀 수 있어서, 우리 앱에서 시작한 로그인만 통과합니다.
const crypto = require('node:crypto');

/** 네이버 개발자 센터의 러너리 Client ID. 공개 값이라 코드에 둡니다(비밀 키는 서버 비밀 저장소에). */
const NAVER_CLIENT_ID = '16Yu9d6lDo16Rl8g1rlM';

class NaverLoginError extends Error {}

/** 앱이 만든 확인 값(verifier)으로 로그인 요청 번호(state)를 만듭니다. 앱과 같은 방식(SHA-256, 16진수)입니다. */
function stateFor(verifier) {
  return crypto.createHash('sha256').update(verifier).digest('hex');
}

/** state는 SHA-256 16진수 64글자만 받습니다. */
function validState(state) {
  return typeof state === 'string' && /^[0-9a-f]{64}$/.test(state);
}

/**
 * 확인 코드를 네이버 회원번호(문자열)로 바꿉니다.
 * @param {{code: string, state: string, clientSecret: string, fetchImpl?: typeof fetch}} p
 */
async function naverIdFromCode({ code, state, clientSecret, fetchImpl = fetch }) {
  if (typeof code !== 'string' || code.length < 4 || code.length > 500) {
    throw new NaverLoginError('네이버 확인 코드가 올바르지 않아요');
  }
  const params = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: NAVER_CLIENT_ID,
    client_secret: clientSecret,
    code,
    state,
  });
  const tokenResponse = await fetchImpl(`https://nid.naver.com/oauth2.0/token?${params}`, {
    signal: AbortSignal.timeout(10000),
  });
  if (!tokenResponse.ok) throw new Error(`네이버 토큰 서버 오류 ${tokenResponse.status}`);
  const token = await tokenResponse.json();
  if (!token.access_token) {
    throw new NaverLoginError(`네이버 로그인을 확인하지 못했어요(${token.error || '알 수 없음'})`);
  }
  const meResponse = await fetchImpl('https://openapi.naver.com/v1/nid/me', {
    headers: { Authorization: `Bearer ${token.access_token}` },
    signal: AbortSignal.timeout(10000),
  });
  if (!meResponse.ok) throw new Error(`네이버 회원 정보 서버 오류 ${meResponse.status}`);
  const me = await meResponse.json();
  const id = me && me.response && me.response.id;
  if (me.resultcode !== '00' || typeof id !== 'string' || id.length === 0) {
    throw new NaverLoginError('네이버 회원 정보를 받지 못했어요');
  }
  return id;
}

module.exports = { NAVER_CLIENT_ID, NaverLoginError, naverIdFromCode, stateFor, validState };
