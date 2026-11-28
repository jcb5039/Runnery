// 크루 초대 코드 규칙 테스트(진짜 서버를 부르지 않습니다). 실행: npm test
const test = require('node:test');
const assert = require('node:assert');
const { CODE_ALPHABET, CodeError, makeCode, normalizeCode, decideJoin, decideIssue } = require('./crew_code');

const crew = { owner: 'a', code: 'RK7Q2M', members: ['a', 'b'] };
const ok = { crew, code: 'RK7Q2M', uid: 'x', banned: false, blocked: false };

test('코드는 헷갈리는 글자 없이 영어 대문자·숫자 6자리예요', () => {
  for (const c of '0O1IL') assert.ok(!CODE_ALPHABET.includes(c));
  let i = 0;
  const code = makeCode(() => (i++ * 0.13) % 1);
  assert.match(code, /^[A-Z2-9]{6}$/);
  assert.strictEqual(normalizeCode(code), code);
  // 맨 끝 글자까지 고를 수 있어요.
  assert.strictEqual(makeCode(() => 0.9999), '999999');
});

test('입력한 코드는 대문자로 바꾸고, 코드 모양이 아니면 null이에요', () => {
  assert.strictEqual(normalizeCode(' rk7 q2m '), 'RK7Q2M');
  assert.strictEqual(normalizeCode('RK7Q2'), null);
  assert.strictEqual(normalizeCode('RK7Q20'), null);
  assert.strictEqual(normalizeCode(null), null);
});

test('맞는 코드면 들어가고, 이미 멤버면 그대로예요', () => {
  assert.strictEqual(decideJoin(ok), 'join');
  assert.strictEqual(decideJoin({ ...ok, uid: 'b' }), 'member');
});

test('없거나 바뀐 코드, 지워진 크루는 들어갈 수 없어요', () => {
  assert.throws(() => decideJoin({ ...ok, code: 'AAAAAA' }), CodeError);
  assert.throws(() => decideJoin({ ...ok, crew: null }), /코드를 다시 확인해 주세요/);
});

test('내보내진 사람·차단 관계·200명이면 못 들어와요', () => {
  assert.throws(() => decideJoin({ ...ok, banned: true }), /코드로 들어갈 수 없어요/);
  assert.throws(() => decideJoin({ ...ok, blocked: true }), /들어갈 수 없어요/);
  const full = { ...crew, members: Array.from({ length: 200 }, (_, i) => `m${i}`) };
  assert.throws(() => decideJoin({ ...ok, crew: full }), /200명/);
});

test('코드는 크루장만 새로 만들어요', () => {
  assert.doesNotThrow(() => decideIssue({ crew, uid: 'a' }));
  assert.throws(() => decideIssue({ crew, uid: 'b' }), /크루장만/);
  assert.throws(() => decideIssue({ crew: null, uid: 'a' }), /찾을 수 없어요/);
});
