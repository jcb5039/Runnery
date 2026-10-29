import 'dart:async';

import 'package:runnery_new/friends/data/friend_models.dart';
import 'package:runnery_new/friends/data/friend_store.dart';

/// 테스트용 가짜 친구 서버. 메모리에만 있고, 같은 인스턴스를 여러 FriendStore가 나눠 쓰면
/// 서로 다른 폰의 두 사람처럼 동작합니다.
class FakeFriendBackend implements FriendBackend {
  /// true면 모든 작업이 인터넷이 없는 것처럼 실패합니다.
  bool offline = false;

  final Map<String, PublicProfile> profilesByUid = {};

  /// '보낸 uid_받는 uid' 묶음.
  final Set<(String, String)> requests = {};
  final Map<String, Set<String>> friends = {};
  final Map<String, ShareSettings> shareSettings = {};
  final Map<String, WeeklyGoal> goals = {};
  final Map<String, RunStats> statsByUid = {};
  final Map<String, Together> togetherById = {};
  final Map<String, StreamController<Together?>> _watchers = {};
  int _togetherSeq = 0;

  /// 서버 시각. 대기실 표시와 시작 시각에 씁니다.
  DateTime Function() clock = DateTime.now;

  /// 올린 사람 uid → 기록 번호 → 공유한 기록.
  final Map<String, Map<String, FeedPost>> postsByOwner = {};

  /// '올린 사람 uid/기록 번호' → 응원한 사람 uid → 보낸 응원.
  final Map<String, Map<String, Set<CheerType>>> cheersByPost = {};

  void _check() {
    if (offline) throw const FriendException('인터넷 연결을 확인해주세요');
  }

  @override
  Future<void> publishProfile(PublicProfile me) async {
    _check();
    profilesByUid[me.uid] = me;
  }

  @override
  Future<List<PublicProfile>> search(String query) async {
    _check();
    return [
      for (final p in profilesByUid.values)
        if (searchKeywords(p.name, p.id).contains(query)) p,
    ];
  }

  @override
  Future<Map<String, PublicProfile>> profiles(List<String> uids) async {
    _check();
    return {for (final uid in uids) uid: ?profilesByUid[uid]};
  }

  @override
  Future<List<String>> friendIds(String uid) async {
    _check();
    return [...?friends[uid]];
  }

  @override
  Future<List<String>> incoming(String uid) async {
    _check();
    return [
      for (final (from, to) in requests)
        if (to == uid) from,
    ];
  }

  @override
  Future<List<String>> outgoing(String uid) async {
    _check();
    return [
      for (final (from, to) in requests)
        if (from == uid) to,
    ];
  }

  @override
  Future<void> sendRequest(String from, String to) async {
    _check();
    // 서버 규칙처럼 이미 친구이거나 찾을 수 없는 사람에게는 보낼 수 없습니다.
    if (from == to ||
        !profilesByUid.containsKey(to) ||
        (friends[from]?.contains(to) ?? false)) {
      throw const FriendException('권한이 없어요. 잠시 후 다시 시도해주세요');
    }
    requests.add((from, to));
  }

  @override
  Future<void> cancelRequest(String from, String to) async {
    _check();
    requests.remove((from, to));
  }

  @override
  Future<void> accept(String me, String from, {bool alsoMine = false}) async {
    _check();
    if (!requests.contains((from, me))) {
      throw const FriendException('권한이 없어요. 잠시 후 다시 시도해주세요');
    }
    (friends[me] ??= {}).add(from);
    (friends[from] ??= {}).add(me);
    requests.remove((from, me));
    if (alsoMine) requests.remove((me, from));
  }

  @override
  Future<void> decline(String me, String from) async {
    _check();
    requests.remove((from, me));
  }

  @override
  Future<void> removeFriend(String me, String friend) async {
    _check();
    friends[me]?.remove(friend);
    friends[friend]?.remove(me);
  }

  @override
  Future<ShareSettings> readShareSettings(String uid) async {
    _check();
    return shareSettings[uid] ?? const ShareSettings();
  }

  @override
  Future<void> writeShareSettings(String uid, ShareSettings settings) async {
    _check();
    shareSettings[uid] = settings;
  }

  @override
  Future<void> publishPost(FeedPost post) async {
    _check();
    (postsByOwner[post.ownerUid] ??= {})[post.recordId] = post;
  }

  @override
  Future<void> deletePost(String uid, String recordId) async {
    _check();
    postsByOwner[uid]?.remove(recordId);
    cheersByPost.remove('$uid/$recordId');
  }

  @override
  Future<Set<String>> sharedIds(String uid, DateTime since) async {
    _check();
    return {
      for (final p in postsByOwner[uid]?.values ?? const <FeedPost>[])
        if (!p.startedAt.isBefore(since)) p.recordId,
    };
  }

  @override
  Future<List<FeedPost>> posts(String ownerUid, {int limit = 10}) async {
    _check();
    final all = [...?postsByOwner[ownerUid]?.values]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return all.take(limit).toList();
  }

  @override
  Future<Map<String, Set<CheerType>>> cheers(
    String ownerUid,
    String recordId,
  ) async {
    _check();
    return {...?cheersByPost['$ownerUid/$recordId']};
  }

  @override
  Future<void> setCheer(
    String ownerUid,
    String recordId,
    String me,
    Set<CheerType> types,
  ) async {
    _check();
    // 서버 규칙처럼 그 사람의 친구만 응원할 수 있습니다.
    if (!(friends[ownerUid]?.contains(me) ?? false)) {
      throw const FriendException('권한이 없어요. 잠시 후 다시 시도해주세요');
    }
    final post = cheersByPost['$ownerUid/$recordId'] ??= {};
    types.isEmpty ? post.remove(me) : post[me] = {...types};
  }

  @override
  Future<WeeklyGoal?> readGoal(String uid) async {
    _check();
    return goals[uid];
  }

  @override
  Future<void> writeGoal(String uid, WeeklyGoal goal) async {
    _check();
    goals[uid] = goal;
  }

  @override
  Future<void> publishStats(String uid, RunStats stats) async {
    _check();
    statsByUid[uid] = stats;
  }

  @override
  Future<Map<String, RunStats>> stats(List<String> uids) async {
    _check();
    return {for (final uid in uids) uid: ?statsByUid[uid]};
  }

  /// 약속을 바꾸고, 지켜보는 대기실에 알립니다(다른 폰에서 바꾼 것처럼 테스트에서도 씁니다).
  void putTogether(Together t) {
    togetherById[t.id] = t;
    _watchers[t.id]?.add(t);
  }

  Together _copy(
    Together t, {
    Map<String, TogetherStatus>? statuses,
    Map<String, DateTime>? ready,
    DateTime? startedAt,
    Map<String, TogetherResult>? results,
  }) => Together(
    id: t.id,
    host: t.host,
    members: t.members,
    statuses: statuses ?? t.statuses,
    startsAt: t.startsAt,
    goalKm: t.goalKm,
    createdAt: t.createdAt,
    ready: ready ?? t.ready,
    startedAt: startedAt ?? t.startedAt,
    results: results ?? t.results,
  );

  Together _get(String id) {
    final t = togetherById[id];
    if (t == null) throw const FriendException('약속을 찾지 못했어요');
    return t;
  }

  @override
  Future<List<Together>> togethers(String uid) async {
    _check();
    return [
      for (final t in togetherById.values)
        if (t.members.contains(uid)) t,
    ];
  }

  @override
  Future<String> createTogether({
    required String host,
    required List<String> members,
    required DateTime startsAt,
    required int goalKm,
  }) async {
    _check();
    final id = 't${++_togetherSeq}';
    putTogether(
      Together(
        id: id,
        host: host,
        members: members,
        statuses: {
          for (final m in members)
            m: m == host ? TogetherStatus.accepted : TogetherStatus.pending,
        },
        startsAt: startsAt,
        goalKm: goalKm,
        createdAt: clock(),
      ),
    );
    return id;
  }

  @override
  Stream<Together?> watchTogether(String id) {
    final controller = _watchers[id] ??= StreamController.broadcast();
    return Stream.multi((listener) {
      listener.add(togetherById[id]);
      final sub = controller.stream.listen(listener.add);
      listener.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> setTogetherStatus(
    String id,
    String uid,
    TogetherStatus status,
  ) async {
    _check();
    final t = _get(id);
    putTogether(_copy(t, statuses: {...t.statuses, uid: status}));
  }

  @override
  Future<void> setTogetherReady(
    String id,
    String uid, {
    required bool ready,
  }) async {
    _check();
    final t = _get(id);
    putTogether(
      _copy(
        t,
        ready: ready ? {...t.ready, uid: clock()} : ({...t.ready}..remove(uid)),
      ),
    );
  }

  @override
  Future<void> startTogether(String id) async {
    _check();
    final t = _get(id);
    if (t.startedAt == null) putTogether(_copy(t, startedAt: clock()));
  }

  @override
  Future<void> submitTogetherResult(
    String id,
    String uid,
    TogetherResult r,
  ) async {
    _check();
    final t = _get(id);
    putTogether(_copy(t, results: {...t.results, uid: r}));
  }

  @override
  Future<void> deleteTogether(String id) async {
    _check();
    togetherById.remove(id);
    _watchers[id]?.add(null);
  }
}
