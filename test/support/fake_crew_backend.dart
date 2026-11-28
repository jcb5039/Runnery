import 'dart:async';

import 'package:runnery_new/friends/data/crew_store.dart';
import 'package:runnery_new/friends/data/friend_models.dart'
    show LiveRun, TogetherResult;
import 'package:runnery_new/friends/data/friend_store.dart';

import 'fake_friend_backend.dart';

/// 테스트용 가짜 크루 서버. 메모리에만 있고, 같은 인스턴스를 여러 CrewStore가 나눠 쓰면
/// 서로 다른 폰의 사람들처럼 동작합니다. 서버 보안 규칙의 주요 제한도 흉내 냅니다.
class FakeCrewBackend implements CrewBackend {
  FakeCrewBackend(this.friends);

  /// 공개 정보와 친구 관계는 가짜 친구 서버의 것을 씁니다.
  final FakeFriendBackend friends;

  DateTime Function() clock = DateTime.now;

  final Map<String, Crew> crewById = {};

  /// 크루 번호 → uid → 멤버 정보.
  final Map<String, Map<String, CrewMember>> membersById = {};
  final Map<String, List<CrewMessage>> messagesById = {};
  final Map<String, CrewInvite> invitesById = {};

  /// 크루 번호/모집 번호 → 모집.
  final Map<String, CrewRun> runs = {};

  /// uid → 지금 들어가 있는 모집('크루 번호/모집 번호').
  final Map<String, String> runnerLocks = {};

  /// '크루 번호/모집 번호' → uid → 실시간 상태.
  final Map<String, Map<String, LiveRun>> liveByRun = {};
  int _seq = 0;

  final _changed = StreamController<void>.broadcast();

  void _notify() => _changed.add(null);

  static const _denied = FriendException('권한이 없어요. 잠시 후 다시 시도해주세요');

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changed.stream) {
      yield read();
    }
  }

  void _put(Crew c) {
    crewById[c.id] = c;
    _notify();
  }

  Crew _copy(
    Crew c, {
    List<String>? members,
    String? owner,
    CrewNotice? notice,
    bool clearNotice = false,
    CrewLastMessage? lastMessage,
  }) => Crew(
    id: c.id,
    name: c.name,
    owner: owner ?? c.owner,
    members: members ?? c.members,
    createdAt: c.createdAt,
    notice: clearNotice ? null : (notice ?? c.notice),
    lastMessage: lastMessage ?? c.lastMessage,
  );

  void _message(
    String id,
    String uid,
    CrewMessageKind kind, {
    String text = '',
    String? target,
    DateTime? at,
  }) {
    (messagesById[id] ??= []).add(
      CrewMessage(
        id: 'm${++_seq}',
        uid: uid,
        kind: kind,
        text: text,
        target: target,
        createdAt: at ?? clock(),
      ),
    );
  }

  Crew _member(String id, String uid) {
    final c = crewById[id];
    if (c == null || !c.members.contains(uid)) throw _denied;
    return c;
  }

  @override
  Future<Map<String, PublicProfile>> profiles(List<String> uids) =>
      friends.profiles(uids);

  @override
  Stream<List<Crew>> watchMyCrews(String uid) => _watch(
    () => [
      for (final c in crewById.values)
        if (c.members.contains(uid)) c,
    ],
  );

  @override
  Stream<Crew?> watchCrew(String id) => _watch(() => crewById[id]);

  @override
  Future<String> createCrew(String owner, String name) async {
    final id = 'c${++_seq}';
    membersById[id] = {
      owner: CrewMember(uid: owner, joinedAt: clock(), lastReadAt: clock()),
    };
    _put(
      Crew(
        id: id,
        name: name,
        owner: owner,
        members: [owner],
        createdAt: clock(),
      ),
    );
    return id;
  }

  @override
  Stream<List<CrewMessage>> watchMessages(String id, {int limit = 50}) =>
      _watch(() {
        final all = messagesById[id] ?? const <CrewMessage>[];
        return all.length <= limit ? [...all] : all.sublist(all.length - limit);
      });

  @override
  Future<void> sendMessage(String id, String uid, String text) async {
    final c = _member(id, uid);
    _message(id, uid, CrewMessageKind.text, text: text);
    _put(
      _copy(
        c,
        lastMessage: CrewLastMessage(uid: uid, text: text, at: clock()),
      ),
    );
  }

  @override
  Future<int> countSince(String id, DateTime since) async => [
    for (final m in messagesById[id] ?? const <CrewMessage>[])
      if (m.createdAt != null && m.createdAt!.isAfter(since)) m,
  ].length;

  @override
  Future<List<CrewMember>> members(String id) async =>
      [...?membersById[id]?.values]
        ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));

  @override
  Future<CrewMember?> member(String id, String uid) async =>
      membersById[id]?[uid];

  @override
  Future<void> markRead(String id, String uid) async {
    final m = membersById[id]?[uid];
    if (m == null) return;
    membersById[id]![uid] = CrewMember(
      uid: uid,
      joinedAt: m.joinedAt,
      lastReadAt: clock(),
      muted: m.muted,
    );
  }

  @override
  Future<void> setMuted(String id, String uid, {required bool muted}) async {
    final m = membersById[id]?[uid];
    if (m == null) throw _denied;
    membersById[id]![uid] = CrewMember(
      uid: uid,
      joinedAt: m.joinedAt,
      lastReadAt: m.lastReadAt,
      muted: muted,
    );
  }

  @override
  Future<void> setNotice(String id, String by, String text) async {
    final c = _member(id, by);
    if (c.owner != by) throw _denied;
    _put(
      text.isEmpty
          ? _copy(c, clearNotice: true)
          : _copy(
              c,
              notice: CrewNotice(text: text, by: by, at: clock()),
            ),
    );
  }

  @override
  Future<void> kick(String id, String owner, String target) async {
    final c = _member(id, owner);
    if (c.owner != owner || target == owner) throw _denied;
    membersById[id]?.remove(target);
    _message(id, owner, CrewMessageKind.kick, target: target);
    _put(_copy(c, members: [...c.members]..remove(target)));
  }

  @override
  Future<void> leave(String id, String me, {String? newOwner}) async {
    final c = _member(id, me);
    membersById[id]?.remove(me);
    if (newOwner == null) {
      if (c.owner != me || c.members.length != 1) throw _denied;
      crewById.remove(id);
      _notify();
      return;
    }
    _message(id, me, CrewMessageKind.leave);
    _put(
      _copy(
        c,
        members: [...c.members]..remove(me),
        owner: newOwner.isEmpty ? null : newOwner,
      ),
    );
  }

  @override
  Future<void> invite(Crew crew, String from, String to) async {
    final c = _member(crew.id, from);
    // 서버 규칙처럼 내 친구만, 멤버가 아닌 사람만, 이미 보낸 초대는 다시 못 보냅니다.
    final key = '${crew.id}_$to';
    if (!(friends.friends[from]?.contains(to) ?? false) ||
        c.members.contains(to) ||
        invitesById.containsKey(key) ||
        (friends.blocks[to]?.contains(from) ?? false)) {
      throw _denied;
    }
    invitesById[key] = CrewInvite(
      crewId: crew.id,
      crewName: c.name,
      from: from,
      to: to,
      createdAt: clock(),
    );
    _notify();
  }

  @override
  Future<List<String>> invitedBy(String crewId, String from) async => [
    for (final i in invitesById.values)
      if (i.crewId == crewId && i.from == from) i.to,
  ];

  @override
  Stream<List<CrewInvite>> watchInvites(String uid) => _watch(
    () => [
      for (final i in invitesById.values)
        if (i.to == uid) i,
    ],
  );

  @override
  Future<void> acceptInvite(CrewInvite invite) async {
    final c = crewById[invite.crewId];
    if (c == null ||
        !invitesById.containsKey(invite.id) ||
        c.members.length >= Crew.maxMembers) {
      throw _denied;
    }
    invitesById.remove(invite.id);
    // 실제 서버처럼 들어온 시각·읽은 시각·들어옴 안내가 같은 시각입니다.
    final at = clock();
    (membersById[c.id] ??= {})[invite.to] = CrewMember(
      uid: invite.to,
      joinedAt: at,
      lastReadAt: at,
    );
    _message(c.id, invite.to, CrewMessageKind.join, at: at);
    _put(_copy(c, members: [...c.members, invite.to]));
  }

  @override
  Future<void> declineInvite(CrewInvite invite) async {
    invitesById.remove(invite.id);
    _notify();
  }

  @override
  Stream<CrewRun?> watchRun(String crewId, String runId) =>
      _watch(() => runs['$crewId/$runId']);

  CrewRun _copyRun(
    CrewRun r, {
    List<String>? members,
    Map<String, int>? colors,
    Set<String>? ready,
    CrewRunStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    Map<String, TogetherResult>? results,
    Map<String, CrewTeamEntry>? team,
    CrewRunVote? vote,
    bool clearVote = false,
  }) => CrewRun(
    id: r.id,
    crewId: r.crewId,
    host: r.host,
    title: r.title,
    members: members ?? r.members,
    colors: colors ?? r.colors,
    ready: ready ?? r.ready,
    status: status ?? r.status,
    createdAt: r.createdAt,
    startedAt: startedAt ?? r.startedAt,
    endedAt: endedAt ?? r.endedAt,
    results: results ?? r.results,
    team: team ?? r.team,
    vote: clearVote ? null : (vote ?? r.vote),
  );

  void _end(String key, CrewRun run) {
    runs[key] = _copyRun(
      run,
      status: CrewRunStatus.ended,
      endedAt: clock(),
      team: _team(run),
      clearVote: true,
    );
    for (final m in run.members) {
      if (runnerLocks[m] == key) runnerLocks.remove(m);
    }
  }

  static int votesNeeded(int members) =>
      (members * .2).ceil().clamp(1, 1 << 30);

  /// 서버가 5분마다 하는 일(functions/crew_run.js의 decideTick)을 흉내 냅니다.
  void tick() {
    final now = clock();
    for (final MapEntry(:key, value: run) in [...runs.entries]) {
      if (!run.isStarted) continue;
      final vote = run.vote;
      if (vote == null) {
        if (now.difference(run.startedAt!) >= const Duration(hours: 2)) {
          runs[key] = _copyRun(run, vote: CrewRunVote(askedAt: now));
        }
        continue;
      }
      if (vote.end.length >= votesNeeded(run.members.length)) {
        _end(key, run);
      } else if (now.difference(vote.askedAt) >= const Duration(minutes: 30)) {
        vote.keep.isEmpty
            ? _end(key, run)
            : runs[key] = _copyRun(run, vote: CrewRunVote(askedAt: now));
      }
    }
    _notify();
  }

  Map<String, CrewTeamEntry> _team(CrewRun r) => {
    for (final m in r.members)
      m: switch ((r.results[m], liveByRun['${r.crewId}/${r.id}']?[m])) {
        (final done?, _) => CrewTeamEntry(
          distanceKm: done.distanceKm,
          movingSeconds: done.movingSeconds,
          finished: true,
        ),
        (null, final live?) => CrewTeamEntry(
          distanceKm: live.distanceKm,
          movingSeconds: live.movingSeconds,
        ),
        _ => const CrewTeamEntry(distanceKm: 0, movingSeconds: 0),
      },
  };

  /// 서버 함수 crewRun(functions/crew_run.js)과 같은 규칙입니다.
  /// 이 가짜는 요청한 사람을 [actor]로 알아야 해서, 테스트에서 부르기 전에 정해 둡니다.
  String actor = '';

  @override
  Future<String> runAction(
    String crewId,
    String action, {
    String? runId,
    String? title,
    int? color,
    bool? ready,
    TogetherResult? result,
    bool? voteEnd,
  }) async {
    final uid = actor;
    final crew = crewById[crewId];
    if (crew == null || !crew.members.contains(uid)) {
      throw const FriendException('크루 멤버만 함께 달리기를 할 수 있어요');
    }
    final lock = runnerLocks[uid];
    final lockRun = lock == null ? null : runs[lock];
    final busy = lockRun != null && (lockRun.isOpen || lockRun.isStarted);
    if (action == 'create') {
      if (busy) {
        throw FriendException(
          lockRun.host == uid ? '이미 연 모집이 있어요' : '이미 다른 모집에 참여하고 있어요',
        );
      }
      final id = 'r${++_seq}';
      runs['$crewId/$id'] = CrewRun(
        id: id,
        crewId: crewId,
        host: uid,
        title: title!.trim(),
        members: [uid],
        colors: {uid: 0},
        createdAt: clock(),
      );
      runnerLocks[uid] = '$crewId/$id';
      (messagesById[crewId] ??= []).add(
        CrewMessage(
          id: 'm${++_seq}',
          uid: uid,
          kind: CrewMessageKind.run,
          text: title.trim(),
          runId: id,
          createdAt: clock(),
        ),
      );
      _notify();
      return id;
    }
    final key = '$crewId/$runId';
    final run = runs[key];
    if (run == null) throw const FriendException('모집을 찾을 수 없어요');
    final inRun = run.members.contains(uid);
    switch (action) {
      case 'join':
        if (inRun) return run.id;
        if (!run.isOpen) throw const FriendException('모집이 닫혔어요');
        if (busy && lock != key) {
          throw const FriendException('이미 다른 모집에 참여하고 있어요');
        }
        if (run.isFull) throw const FriendException('자리가 다 찼어요');
        if (run.members.any(
          (m) =>
              (friends.blocks[uid]?.contains(m) ?? false) ||
              (friends.blocks[m]?.contains(uid) ?? false),
        )) {
          throw const FriendException('이 모집에는 참여할 수 없어요');
        }
        final used = run.colors.values.toSet();
        final free = [
          for (var i = 0; i < CrewRun.colorCount; i++)
            if (!used.contains(i)) i,
        ].first;
        runs[key] = _copyRun(
          run,
          members: [...run.members, uid],
          colors: {...run.colors, uid: free},
        );
        runnerLocks[uid] = key;
      case 'color':
        if (!inRun || !run.isOpen) throw const FriendException('모집이 닫혔어요');
        if (run.ready.contains(uid)) {
          throw const FriendException('준비 취소를 누른 뒤 색을 바꿀 수 있어요');
        }
        if (run.colors.entries.any((e) => e.key != uid && e.value == color)) {
          throw const FriendException('다른 사람이 고른 색이에요');
        }
        runs[key] = _copyRun(run, colors: {...run.colors, uid: color!});
      case 'ready':
        if (!inRun || !run.isOpen) throw const FriendException('모집이 닫혔어요');
        if (uid == run.host) return run.id;
        runs[key] = _copyRun(
          run,
          ready: ready == true
              ? {...run.ready, uid}
              : ({...run.ready}..remove(uid)),
        );
      case 'leave':
        if (!inRun || !run.isOpen) throw const FriendException('모집이 닫혔어요');
        if (run.ready.contains(uid)) {
          throw const FriendException('준비 취소를 누른 뒤 나갈 수 있어요');
        }
        if (uid == run.host) {
          runs[key] = _copyRun(run, status: CrewRunStatus.closed);
          for (final m in run.members) {
            if (runnerLocks[m] == key) runnerLocks.remove(m);
          }
        } else {
          runs[key] = _copyRun(
            run,
            members: [...run.members]..remove(uid),
            colors: {...run.colors}..remove(uid),
          );
          runnerLocks.remove(uid);
        }
      case 'start':
        if (uid != run.host) throw const FriendException('팀장만 러닝을 시작할 수 있어요');
        if (!run.canStart) throw const FriendException('아직 준비하지 않은 사람이 있어요');
        runs[key] = _copyRun(
          run,
          status: CrewRunStatus.started,
          startedAt: clock(),
        );
      case 'finish':
        if (!inRun) throw const FriendException('이 모집에 참여하지 않았어요');
        final next = _copyRun(run, results: {...run.results, uid: result!});
        if (run.isStarted && next.stillRunning.isEmpty) {
          runs[key] = _copyRun(
            next,
            status: CrewRunStatus.ended,
            endedAt: clock(),
            team: _team(next),
          );
          for (final m in run.members) {
            if (runnerLocks[m] == key) runnerLocks.remove(m);
          }
        } else {
          runs[key] = next;
          if (runnerLocks[uid] == key) runnerLocks.remove(uid);
        }
      case 'end':
        if (uid != run.host) throw const FriendException('팀장만 팀을 끝낼 수 있어요');
        if (run.isEnded) return run.id;
        runs[key] = _copyRun(
          run,
          status: CrewRunStatus.ended,
          endedAt: clock(),
          team: _team(run),
        );
        for (final m in run.members) {
          if (runnerLocks[m] == key) runnerLocks.remove(m);
        }
      case 'vote':
        final vote = run.vote;
        if (!inRun) throw const FriendException('이 모집에 참여하지 않았어요');
        if (!run.isStarted || vote == null) return run.id;
        final yes = {...vote.end}..remove(uid);
        final no = {...vote.keep}..remove(uid);
        (voteEnd == true ? yes : no).add(uid);
        final next = _copyRun(
          run,
          vote: CrewRunVote(askedAt: vote.askedAt, end: yes, keep: no),
        );
        if (yes.length >= votesNeeded(run.members.length)) {
          _end(key, next);
        } else {
          runs[key] = next;
        }
      default:
        throw const FriendException('알 수 없는 요청이에요');
    }
    _notify();
    return run.id;
  }

  @override
  Stream<List<LiveRun>> watchRunLive(String crewId, String runId) =>
      _watch(() => [...?liveByRun['$crewId/$runId']?.values]);

  @override
  Future<void> setRunLive(
    String crewId,
    String runId,
    LiveRun run, {
    int sentPoints = 0,
  }) async {
    final r = runs['$crewId/$runId'];
    if (r == null || !r.members.contains(run.uid) || r.isOpen) {
      throw const FriendException('권한이 없어요. 잠시 후 다시 시도해주세요');
    }
    (liveByRun['$crewId/$runId'] ??= {})[run.uid] = LiveRun(
      uid: run.uid,
      distanceKm: run.distanceKm,
      movingSeconds: run.movingSeconds,
      paused: run.paused,
      position: run.position,
      route: run.route,
      updatedAt: clock(),
    );
    _notify();
  }

  @override
  Future<void> deleteRunLive(String crewId, String runId, String uid) async {
    liveByRun['$crewId/$runId']?.remove(uid);
    _notify();
  }

  @override
  Future<List<CrewRun>> endedRuns(String crewId, {int limit = 30}) async => [
    for (final r in runs.values)
      if (r.crewId == crewId && r.isEnded) r,
  ]..sort((a, b) => b.endedAt!.compareTo(a.endedAt!));
}
