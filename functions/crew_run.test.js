// 크루 모집 규칙 테스트(진짜 서버를 부르지 않습니다). 실행: npm test
const test = require('node:test');
const assert = require('node:assert');
const { RunError, decide, decideTick, votesNeeded, STARTED_LOCK_MS, VOTE_AFTER_MS, VOTE_WAIT_MS } = require('./crew_run');

const now = Date.UTC(2026, 10, 28, 11);
const crew = { members: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'x'] };
const noBlock = () => false;
const base = { crew, lockRun: null, lockId: null, runId: 'r1', blocked: noBlock, now };

function open(extra = {}) {
  return { host: 'a', title: '반포대교 한 바퀴', members: ['a'], colors: { a: 0 }, ready: {}, status: 'open', ...extra };
}

test('모집을 열면 연 사람이 팀장이고 채팅방에 안내가 남아요', () => {
  const r = decide({ ...base, action: 'create', uid: 'a', run: null, runId: null, data: { title: '  반포대교 한 바퀴 ' } });
  assert.strictEqual(r.run.host, 'a');
  assert.strictEqual(r.run.title, '반포대교 한 바퀴');
  assert.deepStrictEqual(r.run.members, ['a']);
  assert.deepStrictEqual(r.lockSet, ['a']);
  assert.strictEqual(r.message.kind, 'run');
});

test('제목이 없거나 20자를 넘으면 막아요', () => {
  assert.throws(() => decide({ ...base, action: 'create', uid: 'a', run: null, data: { title: ' ' } }), RunError);
  assert.throws(() => decide({ ...base, action: 'create', uid: 'a', run: null, data: { title: '가'.repeat(21) } }), RunError);
});

test('한 사람은 모집 하나만 열고, 하나에만 참여해요', () => {
  const mine = open();
  assert.throws(
    () => decide({ ...base, action: 'create', uid: 'a', run: null, lockRun: mine, lockId: 'r0', data: { title: '또 열기' } }),
    /이미 연 모집/,
  );
  assert.throws(
    () => decide({ ...base, action: 'join', uid: 'a', run: open({ host: 'b', members: ['b'] }), lockRun: mine, lockId: 'r0' }),
    /다른 모집/,
  );
});

test('닫히거나 오래전에 출발한 모집은 붙잡지 않아요', () => {
  const closed = open({ status: 'closed' });
  const oldStart = open({ status: 'started', startedAt: now - STARTED_LOCK_MS - 1 });
  for (const lockRun of [closed, oldStart]) {
    const r = decide({ ...base, action: 'create', uid: 'a', run: null, lockRun, lockId: 'r0', data: { title: '새 모집' } });
    assert.strictEqual(r.run.host, 'a');
  }
});

test('참여하면 아직 안 쓴 첫 색을 받고, 10명이 차면 막아요', () => {
  const r = decide({ ...base, action: 'join', uid: 'b', run: open({ colors: { a: 0 } }) });
  assert.deepStrictEqual(r.run.members, ['a', 'b']);
  assert.strictEqual(r.run.colors.b, 1);
  const full = open({ members: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'] });
  assert.throws(() => decide({ ...base, action: 'join', uid: 'k', run: full }), /자리가 다 찼어요/);
});

test('차단한 사람과 같은 모집에는 참여할 수 없어요', () => {
  const blocked = (x, y) => (x === 'b' && y === 'a') || (x === 'a' && y === 'b');
  assert.throws(() => decide({ ...base, action: 'join', uid: 'b', run: open(), blocked }), /참여할 수 없어요/);
});

test('색은 다른 사람이 고른 것과 겹칠 수 없고, 준비 완료 뒤에는 못 바꿔요', () => {
  const run = open({ members: ['a', 'b'], colors: { a: 0, b: 1 } });
  assert.throws(() => decide({ ...base, action: 'color', uid: 'b', run, data: { color: 0 } }), /다른 사람이 고른 색/);
  assert.strictEqual(decide({ ...base, action: 'color', uid: 'b', run, data: { color: 5 } }).run.colors.b, 5);
  const ready = { ...run, ready: { b: true } };
  assert.throws(() => decide({ ...base, action: 'color', uid: 'b', run: ready, data: { color: 5 } }), /준비 취소/);
});

test('준비 완료면 나갈 수 없고, 준비를 취소하면 나갈 수 있어요', () => {
  const run = open({ members: ['a', 'b'], colors: { a: 0, b: 1 }, ready: { b: true } });
  assert.throws(() => decide({ ...base, action: 'leave', uid: 'b', run }), /준비 취소를 누른 뒤 나갈/);
  const cancelled = decide({ ...base, action: 'ready', uid: 'b', run, data: { ready: false } }).run;
  const r = decide({ ...base, action: 'leave', uid: 'b', run: cancelled });
  assert.deepStrictEqual(r.run.members, ['a']);
  assert.deepStrictEqual(r.lockClear, ['b']);
});

test('팀장이 나가면 모집이 닫히고 모두 풀려나요', () => {
  const run = open({ members: ['a', 'b', 'c'] });
  const r = decide({ ...base, action: 'leave', uid: 'a', run });
  assert.strictEqual(r.run.status, 'closed');
  assert.deepStrictEqual(r.lockClear, ['a', 'b', 'c']);
});

test('러닝 시작은 팀장만, 모두 준비했을 때만 해요', () => {
  const run = open({ members: ['a', 'b', 'c'], ready: { b: true } });
  assert.throws(() => decide({ ...base, action: 'start', uid: 'b', run }), /팀장만/);
  assert.throws(() => decide({ ...base, action: 'start', uid: 'a', run }), /아직 준비하지 않은/);
  assert.throws(() => decide({ ...base, action: 'start', uid: 'a', run: open() }), /함께 달릴 사람/);
  const all = { ...run, ready: { b: true, c: true } };
  const r = decide({ ...base, action: 'start', uid: 'a', run: all });
  assert.strictEqual(r.run.status, 'started');
  assert.strictEqual(r.run.startedAt, now);
});

test('크루 멤버가 아니면 아무것도 못 해요', () => {
  assert.throws(() => decide({ ...base, action: 'join', uid: 'zz', run: open() }), /크루 멤버만/);
});

test('각자 끝내면 내 기록이 남고, 모두 끝내면 팀 기록도 저절로 끝나요', () => {
  const run = open({ members: ['a', 'b'], status: 'started', startedAt: now - 1000 });
  const r1 = decide({ ...base, action: 'finish', uid: 'b', run, data: { result: { recordId: 'x', distanceKm: 5.2, movingSeconds: 1800, kcal: 300 } } });
  assert.strictEqual(r1.run.status, 'started');
  assert.strictEqual(r1.run.results.b.distanceKm, 5.2);
  assert.deepStrictEqual(r1.lockClear, ['b']);
  const r2 = decide({ ...base, action: 'finish', uid: 'a', run: r1.run, data: { result: { distanceKm: 6, movingSeconds: 2000 } } });
  assert.strictEqual(r2.run.status, 'ended');
  assert.deepStrictEqual(r2.run.team.a, { distanceKm: 6, movingSeconds: 2000, finished: true });
  assert.deepStrictEqual(r2.lockClear, ['a', 'b']);
});

test('팀 끝내기는 팀장만, 아직 달리는 사람은 그때의 기록으로 팀 기록에 남아요', () => {
  const run = open({
    members: ['a', 'b', 'c'],
    status: 'started',
    startedAt: now - 1000,
    results: { a: { distanceKm: 5, movingSeconds: 1500 } },
  });
  assert.throws(() => decide({ ...base, action: 'end', uid: 'b', run }), /팀장만/);
  const live = { b: { distanceKm: 4.1, movingSeconds: 1400 } };
  const r = decide({ ...base, action: 'end', uid: 'a', run, live });
  assert.strictEqual(r.run.status, 'ended');
  assert.deepStrictEqual(r.run.team.b, { distanceKm: 4.1, movingSeconds: 1400, finished: false });
  assert.deepStrictEqual(r.run.team.c, { distanceKm: 0, movingSeconds: 0, finished: false });
  assert.deepStrictEqual(r.lockClear, ['a', 'b', 'c']);
  // 팀이 끝난 뒤에 끝낸 사람의 기록도 남지만, 팀 기록은 그대로예요.
  const late = decide({ ...base, action: 'finish', uid: 'b', run: r.run, data: { result: { distanceKm: 7 } } });
  assert.strictEqual(late.run.results.b.distanceKm, 7);
  assert.strictEqual(late.run.team.b.distanceKm, 4.1);
});

test('팀이 끝나면 다른 모집을 열 수 있어요', () => {
  const ended = open({ status: 'ended' });
  const r = decide({ ...base, action: 'create', uid: 'a', run: null, lockRun: ended, lockId: 'r0', data: { title: '다음 모집' } });
  assert.strictEqual(r.run.host, 'a');
});

test('종료에 필요한 수는 참가자의 20%(올림), 최소 1명이에요', () => {
  assert.strictEqual(votesNeeded(1), 1);
  assert.strictEqual(votesNeeded(3), 1);
  assert.strictEqual(votesNeeded(5), 1);
  assert.strictEqual(votesNeeded(6), 2);
  assert.strictEqual(votesNeeded(10), 2);
});

test('출발하고 2시간이 지나면 투표를 열어요', () => {
  const run = open({ members: ['a', 'b', 'c'], status: 'started', startedAt: now - VOTE_AFTER_MS + 1000 });
  assert.deepStrictEqual(decideTick(run, {}, now), {});
  const later = decideTick(run, {}, now + 2000);
  assert.deepStrictEqual(later.run.vote, { askedAt: now + 2000, end: [], keep: [] });
});

test('종료가 20%를 넘으면 바로 끝나고, 그때의 기록이 팀 기록이 돼요', () => {
  const run = open({
    members: ['a', 'b', 'c', 'd', 'e', 'f'],
    status: 'started',
    startedAt: now - VOTE_AFTER_MS,
    vote: { askedAt: now, end: [], keep: [] },
  });
  const one = decide({ ...base, action: 'vote', uid: 'b', run, data: { end: true } });
  assert.strictEqual(one.run.status, 'started');
  const two = decide({ ...base, action: 'vote', uid: 'c', run: one.run, live: { c: { distanceKm: 9, movingSeconds: 4000 } }, data: { end: true } });
  assert.strictEqual(two.run.status, 'ended');
  assert.strictEqual(two.run.vote, undefined);
  assert.deepStrictEqual(two.run.team.c, { distanceKm: 9, movingSeconds: 4000, finished: false });
  assert.strictEqual(two.activeClear, true);
});

test('30분 동안 끝내지 않기가 없으면 저절로 끝나고, 있으면 다시 물어요', () => {
  const asked = { askedAt: now - VOTE_WAIT_MS, end: [], keep: [] };
  const run = open({ members: ['a', 'b', 'c', 'd', 'e', 'f'], status: 'started', startedAt: now - VOTE_AFTER_MS - VOTE_WAIT_MS, vote: asked });
  assert.strictEqual(decideTick(run, {}, now).run.status, 'ended');
  const kept = { ...run, vote: { ...asked, keep: ['b'], end: ['c'] } };
  const again = decideTick(kept, {}, now);
  assert.strictEqual(again.run.status, 'started');
  assert.deepStrictEqual(again.run.vote, { askedAt: now, end: [], keep: [] });
});

test('같은 사람이 다시 답하면 마지막 답만 세요', () => {
  const run = open({ members: ['a', 'b', 'c', 'd', 'e', 'f'], status: 'started', vote: { askedAt: now, end: ['b'], keep: [] } });
  const r = decide({ ...base, action: 'vote', uid: 'b', run, data: { end: false } });
  assert.deepStrictEqual(r.run.vote.end, []);
  assert.deepStrictEqual(r.run.vote.keep, ['b']);
});
