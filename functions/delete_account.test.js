// 회원 탈퇴 본인 확인 테스트(진짜 서버를 부르지 않습니다). 실행: npm test
const test = require('node:test');
const assert = require('node:assert');
const { RECENT_LOGIN_MS, ProofError, checkProof } = require('./delete_account');

const now = Date.UTC(2026, 10, 23, 12);
const base = {
  now,
  data: {},
  verifyKakao: async () => assert.fail('카카오 확인을 부르면 안 돼요'),
  takeNaverLogin: async () => assert.fail('네이버 결과를 꺼내면 안 돼요'),
};

test('이메일 계정은 방금 다시 로그인했으면 통과해요', async () => {
  await checkProof({ ...base, uid: 'abc', authTime: (now - 60 * 1000) / 1000 });
});

test('이메일 계정은 로그인한 지 5분이 지났으면 거절해요', async () => {
  await assert.rejects(
    checkProof({ ...base, uid: 'abc', authTime: (now - RECENT_LOGIN_MS - 1000) / 1000 }),
    ProofError,
  );
  await assert.rejects(checkProof({ ...base, uid: 'abc', authTime: undefined }), ProofError);
});

test('카카오 계정은 같은 카카오 회원번호여야 해요', async () => {
  const verifyKakao = async (token) => (token === 'mine' ? '1001' : '2002');
  await checkProof({ ...base, uid: 'kakao:1001', data: { kakaoAccessToken: 'mine' }, verifyKakao });
  await assert.rejects(
    checkProof({ ...base, uid: 'kakao:1001', data: { kakaoAccessToken: 'other' }, verifyKakao }),
    /가입한 카카오 계정/,
  );
});

test('카카오 계정은 로그인 시각만으로는 통과하지 않아요', async () => {
  const verifyKakao = async () => { throw new Error('토큰 없음'); };
  await assert.rejects(
    checkProof({ ...base, uid: 'kakao:1001', authTime: now / 1000, verifyKakao }),
    /토큰 없음/,
  );
});

test('네이버 계정은 방금 마친 네이버 로그인의 계정이 같아야 해요', async () => {
  await checkProof({ ...base, uid: 'naver:7', takeNaverLogin: async () => 'naver:7' });
  await assert.rejects(
    checkProof({ ...base, uid: 'naver:7', takeNaverLogin: async () => 'naver:8' }),
    /가입한 네이버 계정/,
  );
  await assert.rejects(
    checkProof({ ...base, uid: 'naver:7', takeNaverLogin: async () => null }),
    /만료/,
  );
});
