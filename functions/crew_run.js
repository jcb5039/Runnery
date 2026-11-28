// 크루 함께 달리기 모집(대기실) 규칙. 서버 함수 crewRun이 이 판단을 한 번에 하나씩(트랜잭션) 적용합니다.
// 판단 부분(decide)은 서버에 닿지 않아 node --test로 시험합니다.
//
// 모집 문서 crews/{크루}/runs/{번호}: host(팀장), title, members(참여자, 10명까지), colors(uid → 색 번호),
// ready(uid → 준비 완료), status('open' 모집 중 · 'started' 출발함 · 'ended' 팀 기록 끝 · 'closed' 닫힘),
// createdAt, startedAt, endedAt, results(uid → 각자 끝낸 기록), team(uid → 팀 기록: 팀장이 끝낸 때의 거리·시간).
// 한 사람이 지금 들어가 있는 모집은 crewRunners/{uid}({crewId, runId})에 적어, 한 사람이 모집 하나만 열고
// 하나에만 참여하게 합니다.

/** 모집 하나의 최대 인원. */
const MAX_RUNNERS = 10;

/** 고를 수 있는 이름표 색 수(앱의 CrewRun.colors와 같습니다). */
const COLOR_COUNT = 16;

/** 제목 최대 글자 수. */
const MAX_TITLE = 20;

/**
 * 출발한 모집을 '아직 달리는 중'으로 보는 시간. 끝내기(3-3)·종료 투표(3-4)가 생기기 전까지
 * 이 시간이 지나면 다른 모집에 들어갈 수 있게 합니다.
 */
const STARTED_LOCK_MS = 3 * 60 * 60 * 1000;

/** 출발한 뒤 이만큼 지나도 팀이 끝나지 않으면 종료 투표를 엽니다. */
const VOTE_AFTER_MS = 2 * 60 * 60 * 1000;

/** 투표를 연 뒤 이만큼 기다립니다. 그동안 '끝내지 않기'가 없으면 끝내고, 있으면 다시 묻습니다. */
const VOTE_WAIT_MS = 30 * 60 * 1000;

/** 팀을 끝내는 데 필요한 '종료' 수: 참가자의 20%(올림), 최소 1명. */
function votesNeeded(memberCount) {
  return Math.max(1, Math.ceil(memberCount * 0.2));
}

class RunError extends Error {}

/** [run]이 아직 그 사람을 붙잡고 있는 모집인지(모집 중이거나, 출발한 지 얼마 안 됨). */
function isActive(run, now) {
  if (!run) return false;
  if (run.status === 'open') return true;
  if (run.status === 'started') {
    const at = run.startedAt == null ? 0 : run.startedAt;
    return now - at < STARTED_LOCK_MS;
  }
  return false;
}

/** 팀을 끝낸 모집(팀 기록 확정). 모두 풀어 주고, 서버가 지켜보던 목록에서도 뺍니다. */
function ended(run, live, now) {
  const { vote, ...rest } = run;
  return {
    run: { ...rest, status: 'ended', endedAt: now, team: teamRecord(run, live) },
    lockClear: [...(run.members || [])],
    activeClear: true,
  };
}

/**
 * 서버가 5분마다 출발한 모집을 살펴봅니다(앱이 꺼져 있어도 지키기 위해).
 * 2시간이 지나면 투표를 열고, 30분 동안 '끝내지 않기'가 없으면 끝내며, 있으면 투표를 다시 엽니다.
 */
function decideTick(run, live, now) {
  if (!run || run.status !== 'started') return { activeClear: true };
  const vote = run.vote;
  if (!vote) {
    if (now - (run.startedAt || now) < VOTE_AFTER_MS) return {};
    return { run: { ...run, vote: { askedAt: now, end: [], keep: [] } } };
  }
  if ((vote.end || []).length >= votesNeeded((run.members || []).length)) return ended(run, live, now);
  if (now - vote.askedAt < VOTE_WAIT_MS) return {};
  if ((vote.keep || []).length === 0) return ended(run, live, now);
  return { run: { ...run, vote: { askedAt: now, end: [], keep: [] } } };
}

/** 팀 기록을 확정합니다: 끝낸 사람은 끝낸 기록, 아직 달리는 사람은 지금(live)의 거리·시간. */
function teamRecord(run, live) {
  const team = {};
  for (const m of run.members || []) {
    const done = (run.results || {})[m];
    const now = (live || {})[m];
    team[m] = done
      ? { distanceKm: done.distanceKm, movingSeconds: done.movingSeconds, finished: true }
      : { distanceKm: now ? now.distanceKm : 0, movingSeconds: now ? now.movingSeconds : 0, finished: false };
  }
  return team;
}

/** 아직 아무도 쓰지 않은 가장 앞 색 번호. */
function firstFreeColor(colors) {
  const used = new Set(Object.values(colors || {}));
  for (let i = 0; i < COLOR_COUNT; i += 1) if (!used.has(i)) return i;
  return 0;
}

/**
 * 할 일 하나를 판단해 바뀔 내용을 돌려줍니다. 고칠 수 없는 요청이면 RunError(화면에 보여 줄 한국어)를 던집니다.
 *
 * @param {object} p
 * @param {string} p.action create · join · color · ready · leave · start
 * @param {string} p.uid 요청한 사람
 * @param {{members: string[]}} p.crew 크루
 * @param {object|null} p.run 대상 모집(create면 null)
 * @param {object|null} p.lockRun 요청한 사람이 지금 들어가 있는 모집(없으면 null)
 * @param {string|null} p.lockId 그 모집 번호
 * @param {string|null} p.runId 대상 모집 번호
 * @param {(a: string, b: string) => boolean} p.blocked 두 사람 중 한쪽이 다른 쪽을 차단했는지
 * @param {number} p.now 지금(밀리초)
 * @param {object} p.data 요청 값(title, color, ready)
 * @returns {{run?: object|null, lockSet?: string[], lockClear?: string[], message?: object}}
 *   run: 새 모집 문서 전체(null이면 바꾸지 않음), lockSet/lockClear: 붙잡을·풀 사람, message: 채팅방에 남길 안내
 */
function decide(p) {
  const { action, uid, crew, run, lockRun, lockId, runId, blocked, now, data = {} } = p;
  if (!crew || !(crew.members || []).includes(uid)) {
    throw new RunError('크루 멤버만 함께 달리기를 할 수 있어요');
  }
  const busyElsewhere = isActive(lockRun, now) && lockId !== runId;

  if (action === 'create') {
    const title = typeof data.title === 'string' ? data.title.trim() : '';
    if (!title) throw new RunError('제목을 정해 주세요');
    if ([...title].length > MAX_TITLE) throw new RunError('제목은 20자까지예요');
    if (isActive(lockRun, now)) {
      throw new RunError(lockRun.host === uid ? '이미 연 모집이 있어요' : '이미 다른 모집에 참여하고 있어요');
    }
    return {
      run: {
        host: uid,
        title,
        members: [uid],
        colors: { [uid]: 0 },
        ready: {},
        status: 'open',
        createdAt: now,
      },
      lockSet: [uid],
      message: { kind: 'run', uid, title },
    };
  }

  if (!run) throw new RunError('모집을 찾을 수 없어요');
  const members = run.members || [];
  const inRun = members.includes(uid);

  // ── 출발한 뒤: 각자 끝내기(finish)와 팀장의 팀 끝내기(end) ──
  if (action === 'finish') {
    if (!inRun) throw new RunError('이 모집에 참여하지 않았어요');
    // 팀 기록이 이미 끝났어도 내 기록은 남깁니다(팀 기록은 그대로).
    if (run.status !== 'started' && run.status !== 'ended') throw new RunError('출발하지 않은 모집이에요');
    const r = data.result || {};
    const result = {
      recordId: typeof r.recordId === 'string' ? r.recordId.slice(0, 100) : '',
      distanceKm: Math.max(0, Math.min(1000, Number(r.distanceKm) || 0)),
      movingSeconds: Math.max(0, Math.floor(Number(r.movingSeconds) || 0)),
      kcal: Math.max(0, Math.floor(Number(r.kcal) || 0)),
      finishedAt: now,
    };
    const results = { ...(run.results || {}), [uid]: result };
    const next = { ...run, results };
    const allDone = members.every((m) => results[m]);
    if (run.status === 'started' && allDone) {
      // 모두 끝내면 팀 기록도 저절로 끝납니다.
      return ended(next, {}, now);
    }
    return { run: next, lockClear: [uid] };
  }

  if (action === 'end') {
    if (run.host !== uid) throw new RunError('팀장만 팀을 끝낼 수 있어요');
    if (run.status === 'ended') return {};
    if (run.status !== 'started') throw new RunError('출발하지 않은 모집이에요');
    return ended(run, p.live, now);
  }

  // 종료 투표: 열린 투표에 '종료'(end: true) 또는 '끝내지 않기'(end: false)로 답합니다.
  if (action === 'vote') {
    if (!inRun) throw new RunError('이 모집에 참여하지 않았어요');
    if (run.status !== 'started' || !run.vote) return {};
    const yes = new Set(run.vote.end || []);
    const no = new Set(run.vote.keep || []);
    yes.delete(uid);
    no.delete(uid);
    (data.end ? yes : no).add(uid);
    const vote = { ...run.vote, end: [...yes], keep: [...no] };
    if (yes.size >= votesNeeded(members.length)) return ended({ ...run, vote }, p.live, now);
    return { run: { ...run, vote } };
  }

  if (action === 'join') {
    if (inRun) return {};
    if (run.status !== 'open') throw new RunError('모집이 닫혔어요');
    if (busyElsewhere) throw new RunError('이미 다른 모집에 참여하고 있어요');
    if (members.length >= MAX_RUNNERS) throw new RunError('자리가 다 찼어요');
    if (members.some((m) => blocked(uid, m))) {
      throw new RunError('이 모집에는 참여할 수 없어요');
    }
    return {
      run: {
        ...run,
        members: [...members, uid],
        colors: { ...run.colors, [uid]: firstFreeColor(run.colors) },
      },
      lockSet: [uid],
    };
  }

  if (!inRun) throw new RunError('이 모집에 참여하지 않았어요');
  if (run.status !== 'open') throw new RunError('모집이 닫혔어요');
  const isHost = run.host === uid;
  const ready = { ...(run.ready || {}) };

  if (action === 'color') {
    const color = data.color;
    if (!Number.isInteger(color) || color < 0 || color >= COLOR_COUNT) {
      throw new RunError('색을 다시 골라 주세요');
    }
    if (ready[uid]) throw new RunError('준비 취소를 누른 뒤 색을 바꿀 수 있어요');
    const takenBy = Object.entries(run.colors || {}).find(([m, c]) => m !== uid && c === color);
    if (takenBy) throw new RunError('다른 사람이 고른 색이에요');
    return { run: { ...run, colors: { ...run.colors, [uid]: color } } };
  }

  if (action === 'ready') {
    if (isHost) return {};
    if (data.ready) ready[uid] = true;
    else delete ready[uid];
    return { run: { ...run, ready } };
  }

  if (action === 'leave') {
    if (ready[uid]) throw new RunError('준비 취소를 누른 뒤 나갈 수 있어요');
    if (isHost) {
      // 팀장이 나가면 모집이 없어집니다.
      return { run: { ...run, status: 'closed' }, lockClear: [...members] };
    }
    const colors = { ...run.colors };
    delete colors[uid];
    return {
      run: { ...run, members: members.filter((m) => m !== uid), colors, ready },
      lockClear: [uid],
    };
  }

  if (action === 'start') {
    if (!isHost) throw new RunError('팀장만 러닝을 시작할 수 있어요');
    if (members.length < 2) throw new RunError('함께 달릴 사람이 아직 없어요');
    const waiting = members.filter((m) => m !== run.host && !ready[m]);
    if (waiting.length) throw new RunError('아직 준비하지 않은 사람이 있어요');
    return { run: { ...run, status: 'started', startedAt: now }, activeSet: true };
  }

  throw new RunError('알 수 없는 요청이에요');
}

module.exports = {
  MAX_RUNNERS,
  COLOR_COUNT,
  MAX_TITLE,
  STARTED_LOCK_MS,
  VOTE_AFTER_MS,
  VOTE_WAIT_MS,
  votesNeeded,
  decideTick,
  RunError,
  decide,
  isActive,
  firstFreeColor,
  teamRecord,
};
