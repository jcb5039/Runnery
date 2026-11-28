// 크루 팀 기록의 지나간 길 테스트(진짜 서버를 부르지 않습니다). 실행: npm test
const test = require('node:test');
const assert = require('node:assert');
const {
  CLEANUP_AFTER_MS,
  STILL_RUNNING_MS,
  meters,
  parseLiveRoute,
  privateRoute,
  routeDoc,
  decideCleanup,
} = require('./crew_route');

/** 북쪽으로 [step]m마다 점을 [n]개 찍은 길. */
function straight(n, step = 50) {
  // 한 점 간격이 [step]m보다 조금 길게(경계에서 소수 오차로 잘리지 않게).
  const dLat = step / 111000;
  return Array.from({ length: n }, (_, i) => [37.5 + dLat * i, 127.0]);
}

test('실시간 상태의 길을 순서대로 읽고 이상한 점은 빼요', () => {
  assert.deepStrictEqual(parseLiveRoute(['1,37.5001,127', '0,37.5,127', 'x', '2,a,127']), [
    [37.5, 127],
    [37.5001, 127],
  ]);
  assert.deepStrictEqual(parseLiveRoute(null), []);
});

test('출발·도착 200m 안은 잘라 내요', () => {
  const route = straight(21); // 1km
  const kept = privateRoute(route);
  assert.ok(meters(kept[0], route[0]) >= 200);
  assert.ok(meters(kept[kept.length - 1], route[route.length - 1]) >= 200);
  assert.strictEqual(kept.length, 13);
});

test('남는 길이 짧으면 아무것도 남기지 않아요', () => {
  assert.deepStrictEqual(privateRoute(straight(8)), []); // 350m
  assert.deepStrictEqual(privateRoute([]), []);
});

test('점이 많으면 고르게 줄여요', () => {
  const kept = privateRoute(straight(3000, 10), 200, 600);
  assert.strictEqual(kept.length, 600);
});

test('저장할 문서는 좌표를 펼쳐 담고 고른 색을 함께 남겨요', () => {
  const live = { route: straight(21).map(([a, b], i) => `${i},${a},${b}`) };
  const doc = routeDoc(live, 6);
  assert.strictEqual(doc.color, 6);
  assert.strictEqual(doc.points.length, 26);
  assert.deepStrictEqual(routeDoc(null, undefined), { points: [], color: 0 });
});

test('팀이 끝나고 1시간이 지나면 실시간 상태를 지우고, 아직 달리는 사람은 기다려요', () => {
  const endedAt = Date.UTC(2026, 10, 28, 10);
  const lives = [
    { uid: 'a', updatedAt: endedAt },
    { uid: 'b', updatedAt: null },
  ];
  assert.deepStrictEqual(decideCleanup(endedAt, lives, endedAt + 1000), { remove: [], done: false });
  const later = endedAt + CLEANUP_AFTER_MS + 1;
  assert.deepStrictEqual(decideCleanup(endedAt, lives, later), { remove: ['a', 'b'], done: true });
  const running = [...lives, { uid: 'c', updatedAt: later - STILL_RUNNING_MS / 2 }];
  assert.deepStrictEqual(decideCleanup(endedAt, running, later), { remove: ['a', 'b'], done: false });
});
