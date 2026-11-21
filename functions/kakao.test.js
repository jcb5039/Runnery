// 카카오 토큰 확인 테스트(진짜 카카오 서버를 부르지 않습니다). 실행: npm test
const test = require('node:test');
const assert = require('node:assert');
const { KAKAO_APP_ID, KakaoTokenError, verifyKakaoToken } = require('./kakao');

const fakeFetch = (status, body) => async (url, options) => {
  assert.strictEqual(url, 'https://kapi.kakao.com/v1/user/access_token_info');
  assert.match(options.headers.Authorization, /^Bearer /);
  return { status, ok: status >= 200 && status < 300, json: async () => body };
};

test('우리 앱의 토큰이면 카카오 회원번호를 돌려줘요', async () => {
  const id = await verifyKakaoToken('a'.repeat(40), fakeFetch(200, { id: 12345, app_id: KAKAO_APP_ID }));
  assert.strictEqual(id, '12345');
});

test('다른 앱에서 받은 토큰은 거절해요', async () => {
  await assert.rejects(
    verifyKakaoToken('a'.repeat(40), fakeFetch(200, { id: 12345, app_id: 999 })),
    KakaoTokenError,
  );
});

test('만료되거나 잘못된 토큰은 거절해요', async () => {
  await assert.rejects(verifyKakaoToken('a'.repeat(40), fakeFetch(401, {})), KakaoTokenError);
  await assert.rejects(verifyKakaoToken('', fakeFetch(200, {})), KakaoTokenError);
  await assert.rejects(verifyKakaoToken(undefined, fakeFetch(200, {})), KakaoTokenError);
});

test('카카오 서버 오류는 거절이 아니라 다시 시도할 오류예요', async () => {
  await assert.rejects(verifyKakaoToken('a'.repeat(40), fakeFetch(500, {})), (e) => !(e instanceof KakaoTokenError));
});
