// 네이버 확인 코드 교환 테스트(진짜 네이버 서버를 부르지 않습니다). 실행: npm test
const test = require('node:test');
const assert = require('node:assert');
const { NAVER_CLIENT_ID, NaverLoginError, naverIdFromCode, stateFor, validState } = require('./naver');

const state = stateFor('v'.repeat(43));

function fakeFetch({ token = { access_token: 'AT' }, me = { resultcode: '00', response: { id: 'naver-123' } } } = {}) {
  const calls = [];
  const impl = async (url, options = {}) => {
    calls.push({ url, options });
    if (url.startsWith('https://nid.naver.com/oauth2.0/token?')) {
      return { ok: true, status: 200, json: async () => token };
    }
    assert.strictEqual(url, 'https://openapi.naver.com/v1/nid/me');
    assert.strictEqual(options.headers.Authorization, 'Bearer AT');
    return { ok: true, status: 200, json: async () => me };
  };
  return { impl, calls };
}

test('state는 확인 값의 SHA-256 16진수예요', () => {
  assert.strictEqual(state.length, 64);
  assert.ok(validState(state));
  assert.ok(!validState('abc'));
  assert.ok(!validState(undefined));
});

test('확인 코드를 우리 Client ID·비밀 키로 바꿔 네이버 회원번호를 받아요', async () => {
  const { impl, calls } = fakeFetch();
  const id = await naverIdFromCode({ code: 'CODE1234', state, clientSecret: 'SECRET', fetchImpl: impl });
  assert.strictEqual(id, 'naver-123');
  const params = new URL(calls[0].url).searchParams;
  assert.strictEqual(params.get('client_id'), NAVER_CLIENT_ID);
  assert.strictEqual(params.get('client_secret'), 'SECRET');
  assert.strictEqual(params.get('code'), 'CODE1234');
  assert.strictEqual(params.get('state'), state);
});

test('코드를 바꾸지 못하면(다른 앱 코드·만료) 거절해요', async () => {
  const { impl } = fakeFetch({ token: { error: 'invalid_request' } });
  await assert.rejects(naverIdFromCode({ code: 'CODE1234', state, clientSecret: 'S', fetchImpl: impl }), NaverLoginError);
  await assert.rejects(naverIdFromCode({ code: '', state, clientSecret: 'S', fetchImpl: impl }), NaverLoginError);
});

test('회원 정보가 없으면 거절해요', async () => {
  const { impl } = fakeFetch({ me: { resultcode: '024', message: 'Authentication failed' } });
  await assert.rejects(naverIdFromCode({ code: 'CODE1234', state, clientSecret: 'S', fetchImpl: impl }), NaverLoginError);
});
