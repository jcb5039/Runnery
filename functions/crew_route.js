// 크루 팀 기록에 남기는 지나간 길. 팀 달리기가 끝나면 서버가 각자의 실시간 상태(live)에서 길을 옮겨
// crews/{크루}/runs/{모집}/routes/{uid}에 저장합니다(크루 멤버만 읽고, 쓰는 건 서버만).
// 집 위치가 드러나지 않도록 친구 피드 공유(앱의 privateRoute)와 같이 출발·도착 200m 안은 잘라 냅니다.
// 실시간 상태는 팀이 끝나고 1시간 뒤 서버가 지웁니다(crewLiveCleanup). 판단 부분은 node --test로 시험합니다.

/** 출발점·도착점에서 이 거리 안의 길은 남기지 않습니다(m). */
const TRIM_METERS = 200;

/** 한 사람 길에 남기는 최대 점 수(문서 크기를 작게 유지). */
const MAX_POINTS = 600;

/** 팀이 끝난 뒤 실시간 상태를 지우기까지 기다리는 시간. */
const CLEANUP_AFTER_MS = 60 * 60 * 1000;

/** 이보다 최근에 올린 실시간 상태는 아직 달리는 중으로 보고 지우지 않습니다(팀이 끝나도 각자 계속 달릴 수 있음). */
const STILL_RUNNING_MS = 10 * 60 * 1000;

/** 두 [위도, 경도] 사이 거리(m). */
function meters(a, b) {
  const r = 6371000;
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b[0] - a[0]);
  const dLng = rad(b[1] - a[1]);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a[0])) * Math.cos(rad(b[0])) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** 실시간 상태의 route('순서,위도,경도' 글자 목록)를 순서대로 [[위도, 경도]]로 바꿉니다. 이상한 점은 뺍니다. */
function parseLiveRoute(route) {
  const points = [];
  for (const p of Array.isArray(route) ? route : []) {
    const [i, a, b] = String(p).split(',').map(Number);
    if (Number.isInteger(i) && Number.isFinite(a) && Number.isFinite(b)) points.push([i, a, b]);
  }
  points.sort((x, y) => x[0] - y[0]);
  return points.map(([, a, b]) => [a, b]);
}

/**
 * 남길 길: 출발점에서 [trim] 안의 앞부분과 도착점에서 [trim] 안의 뒷부분을 잘라 내고, 점은 [maxPoints]개까지
 * 고르게 남기며 좌표는 소수 다섯째 자리(약 1m)로 줄입니다. 남은 길이 짧으면 빈 목록입니다.
 */
function privateRoute(route, trim = TRIM_METERS, maxPoints = MAX_POINTS) {
  if (!Array.isArray(route) || route.length < 2) return [];
  const start = route[0];
  const end = route[route.length - 1];
  let from = 0;
  let to = route.length - 1;
  while (from <= to && meters(route[from], start) < trim) from++;
  while (to >= from && meters(route[to], end) < trim) to--;
  if (to - from < 1) return [];
  const kept = route.slice(from, to + 1);
  const step = kept.length <= maxPoints ? 1 : (kept.length - 1) / (maxPoints - 1);
  const round = (v) => Math.round(v * 100000) / 100000;
  const out = [];
  for (let i = 0; Math.round(i) < kept.length; i += step) {
    const p = kept[Math.round(i)];
    out.push([round(p[0]), round(p[1])]);
  }
  return out;
}

/** 팀 기록에 저장할 한 사람의 길 문서. 좌표는 [위도, 경도, 위도, 경도, …]로 펼쳐 담습니다. */
function routeDoc(live, color) {
  const route = privateRoute(parseLiveRoute(live && live.route));
  return {
    points: route.flat(),
    color: Number.isInteger(color) ? color : 0,
  };
}

/**
 * 팀이 끝나고 [CLEANUP_AFTER_MS]가 지났으면, 지울 실시간 상태(uid 목록)와 정리를 마쳤는지 돌려줍니다.
 * lives: [{ uid, updatedAt(밀리초 또는 null) }]
 */
function decideCleanup(endedAt, lives, now) {
  if (!Number.isFinite(endedAt) || now - endedAt < CLEANUP_AFTER_MS) return { remove: [], done: false };
  const remove = [];
  let waiting = false;
  for (const l of lives) {
    if (Number.isFinite(l.updatedAt) && now - l.updatedAt < STILL_RUNNING_MS) waiting = true;
    else remove.push(l.uid);
  }
  return { remove, done: !waiting };
}

module.exports = {
  TRIM_METERS,
  MAX_POINTS,
  CLEANUP_AFTER_MS,
  STILL_RUNNING_MS,
  meters,
  parseLiveRoute,
  privateRoute,
  routeDoc,
  decideCleanup,
};
