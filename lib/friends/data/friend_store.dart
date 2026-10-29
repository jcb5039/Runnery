import 'package:flutter/foundation.dart';

import '../../account/account_store.dart';
import '../../record/data/running_record_store.dart';
import '../../record/models/running_record.dart';
import 'friend_backend.dart';
import 'friend_models.dart';

export 'friend_backend.dart' show FriendBackend, FriendException;
export 'friend_models.dart'
    show
        CheerType,
        FeedItem,
        FeedPost,
        FriendRelation,
        PublicProfile,
        RunStats,
        WeeklyGoal;

/// 친구 탭이 보여 주는 친구 목록과 친구 요청. 서버가 원본이고, 이 기기에는 저장하지 않습니다.
class FriendStore extends ChangeNotifier {
  FriendStore({
    FriendBackend? backend,
    PublicProfile? Function()? me,
    Future<List<RunningRecord>> Function()? records,
    DateTime Function()? clock,
  }) : _backend = backend,
       _me = me ?? loggedIn,
       _records = records ?? (() => RunningRecordStore.instance.load()),
       _clock = clock ?? DateTime.now;

  /// 앱 전체가 쓰는 저장소. 테스트에서만 교체합니다.
  static FriendStore instance = FriendStore();

  FriendBackend? _backend;
  final PublicProfile? Function() _me;

  /// 랭킹·목표 합계를 내는 데 쓰는 폰의 러닝 기록.
  final Future<List<RunningRecord>> Function() _records;
  final DateTime Function() _clock;

  /// 처음 쓸 때 실제 서버 연결을 만듭니다(테스트는 가짜를 넣어 두므로 만들지 않습니다).
  FriendBackend get backend => _backend ??= FirebaseFriendBackend();

  /// 로그인한 계정의 공개 정보. 로그아웃 상태면 null.
  static PublicProfile? loggedIn() {
    final account = AccountStore.instance;
    final uid = account.uid, current = account.current;
    if (uid == null || current == null) return null;
    return PublicProfile(uid: uid, name: current.name, id: current.id);
  }

  String? _owner;
  PublicProfile? _published;
  List<PublicProfile> _friends = const [];
  List<PublicProfile> _incoming = const [];
  Set<String> _outgoing = const {};
  List<FeedItem> _feed = const [];
  bool _loading = false;
  String? _error, _feedError, _statsError;
  WeeklyGoal? _goal;
  bool _goalLoaded = false;
  RunStats? _myStats, _publishedStats;
  Map<String, RunStats> _friendStats = const {};

  /// 이름순 친구 목록.
  List<PublicProfile> get friends => _friends;

  /// 나에게 친구 요청을 보낸 사람들.
  List<PublicProfile> get incoming => _incoming;

  bool get loading => _loading;

  /// 마지막으로 불러오기에 실패했다면 그 이유.
  String? get error => _error;

  /// 친구들이 공유한 최근 러닝. 최근에 달린 순서입니다.
  List<FeedItem> get feed => _feed;

  /// 피드를 불러오지 못했다면 그 이유(친구 목록은 따로 불러옵니다).
  String? get feedError => _feedError;

  /// 로그인한 계정의 공개 정보. 로그아웃 상태면 null.
  PublicProfile? get me => _me();

  /// 지금 시각. 랭킹·목표의 주·달을 정합니다.
  DateTime get now => _clock();

  /// 내 주간 목표. 정한 적이 없으면 null.
  WeeklyGoal? get goal => _goal;

  /// 폰의 기록으로 낸 내 합계(서버에 올리는 것과 같습니다).
  RunStats get myStats => _myStats ?? RunStats.from(const [], now);

  /// 친구가 올린 합계. 올린 적이 없으면 null.
  RunStats? statsOf(String uid) => _friendStats[uid];

  /// 친구 → 합계. 랭킹·목표 비교에 씁니다.
  Map<PublicProfile, RunStats?> get friendStats => {
    for (final f in _friends) f: _friendStats[f.uid],
  };

  /// 랭킹 정보를 불러오지 못했다면 그 이유.
  String? get statsError => _statsError;

  FriendRelation relation(String uid) {
    if (uid == _owner) return FriendRelation.me;
    if (_friends.any((f) => f.uid == uid)) return FriendRelation.friend;
    if (_outgoing.contains(uid)) return FriendRelation.requested;
    if (_incoming.any((f) => f.uid == uid)) return FriendRelation.incoming;
    return FriendRelation.none;
  }

  /// 로그인한 계정. 계정이 바뀌었으면 이전 계정의 친구 정보를 비웁니다.
  PublicProfile _require() {
    final me = _me();
    if (me == null) {
      _reset(null);
      throw const FriendException('로그인이 필요해요');
    }
    if (me.uid != _owner) _reset(me.uid);
    return me;
  }

  void _reset(String? owner) {
    _owner = owner;
    _published = null;
    _friends = const [];
    _incoming = const [];
    _outgoing = const {};
    _feed = const [];
    _error = null;
    _feedError = null;
    _statsError = null;
    _goal = null;
    _goalLoaded = false;
    _myStats = null;
    _publishedStats = null;
    _friendStats = const {};
  }

  /// 서버에서 친구 목록과 요청을 새로 읽어 옵니다. 실패하면 [error]에 이유를 남깁니다.
  Future<void> refresh() async {
    // 화면을 만드는 도중(initState)에 불려도 괜찮도록 한 박자 뒤에 시작합니다.
    await Future<void>.value();
    final PublicProfile me;
    try {
      me = _require();
    } on FriendException {
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      // 다른 사람이 나를 찾을 수 있게 내 공개 정보부터 올립니다(이름·아이디가 바뀌었을 때만).
      if (_published != me) {
        await backend.publishProfile(me);
        _published = me;
      }
      final lists = await Future.wait([
        backend.friendIds(me.uid),
        backend.incoming(me.uid),
        backend.outgoing(me.uid),
      ]);
      final [friendIds, incomingIds, outgoing] = lists;
      final people = await backend.profiles(
        {...friendIds, ...incomingIds}.toList(),
      );
      if (me.uid != _owner) throw const FriendException('계정이 바뀌었어요');
      _friends = _sorted([for (final id in friendIds) ?people[id]]);
      _incoming = [
        for (final id in incomingIds)
          if (!friendIds.contains(id)) ?people[id],
      ];
      _outgoing = outgoing.toSet();
      _error = null;
    } on FriendException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return;
    }
    // 피드와 랭킹은 따로 불러와, 한쪽이 실패해도 다른 쪽은 보이게 합니다.
    await Future.wait([_refreshFeed(me), _refreshStats(me)]);
    _loading = false;
    notifyListeners();
  }

  Future<void> _refreshFeed(PublicProfile me) async {
    try {
      final feed = await _loadFeed(me.uid, _friends);
      if (me.uid != _owner) return;
      _feed = feed;
      _feedError = null;
    } on FriendException catch (e) {
      _feedError = e.message;
    }
  }

  Future<void> _refreshStats(PublicProfile me) async {
    try {
      await _publishMyStats(me);
      final stats = await backend.stats([for (final f in _friends) f.uid]);
      if (me.uid != _owner) return;
      _friendStats = stats;
      _statsError = null;
    } on FriendException catch (e) {
      _statsError = e.message;
    }
  }

  /// 폰의 기록으로 내 합계를 다시 내고, 바뀌었으면 서버에 올립니다.
  Future<void> _publishMyStats(PublicProfile me) async {
    if (!_goalLoaded) {
      _goal = await backend.readGoal(me.uid);
      _goalLoaded = true;
    }
    List<RunningRecord> records;
    try {
      records = await _records();
    } catch (_) {
      // 기록을 못 읽으면 합계를 올리지 않습니다(0으로 덮어쓰지 않게).
      return;
    }
    final goal = _goal;
    final stats = RunStats.from(
      [for (final r in records) (r.startedAt, r.distanceKm)],
      now,
      goalKm: goal != null && goal.public ? goal.km : null,
    );
    _myStats = stats;
    if (stats == _publishedStats) return;
    await backend.publishStats(me.uid, stats);
    _publishedStats = stats;
  }

  /// 러닝 기록을 저장하거나 지운 뒤 부릅니다. 친구 랭킹에 바로 반영되게 합계를 올립니다.
  /// 로그아웃 상태거나 인터넷이 없으면 조용히 넘어갑니다(친구 탭을 열 때 다시 올립니다).
  Future<void> recordsChanged() async {
    final me = _me();
    if (me == null) return;
    try {
      _require();
      await _publishMyStats(me);
    } on FriendException {
      // 다음에 다시 올립니다.
    }
    notifyListeners();
  }

  /// 주간 목표를 저장하고, 공개 여부에 맞춰 내 합계도 다시 올립니다.
  Future<void> saveGoal(WeeklyGoal goal) async {
    final me = _require();
    await backend.writeGoal(me.uid, goal);
    _goal = goal;
    _goalLoaded = true;
    try {
      await _publishMyStats(me);
    } on FriendException {
      // 목표는 저장됐습니다. 합계는 다음에 다시 올립니다.
    }
    notifyListeners();
  }

  /// 친구마다 최근 공유 기록을 읽어 합친 뒤, 카드마다 응원을 읽습니다.
  Future<List<FeedItem>> _loadFeed(
    String me,
    List<PublicProfile> friends,
  ) async {
    final perFriend = await Future.wait(
      friends.map((f) => backend.posts(f.uid, limit: feedPerFriend)),
    );
    final byUid = {for (final f in friends) f.uid: f};
    final posts = [for (final list in perFriend) ...list]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final recent = posts.take(feedSize).toList();
    final cheers = await Future.wait(
      recent.map((p) => backend.cheers(p.ownerUid, p.recordId)),
    );
    return [
      for (final (i, post) in recent.indexed)
        FeedItem(
          friend: byUid[post.ownerUid]!,
          post: post,
          counts: {
            for (final type in CheerType.values)
              type: cheers[i].values.where((s) => s.contains(type)).length,
          },
          mine: cheers[i][me] ?? const {},
        ),
    ];
  }

  /// 피드에 친구 한 명당 가져오는 기록 수와 전체 카드 수.
  static const feedPerFriend = 10, feedSize = 30;

  /// 응원 하나를 켜거나 끕니다. 화면에는 바로 반영하고, 서버에 못 보내면 되돌립니다.
  Future<void> toggleCheer(FeedItem item, CheerType type) async {
    final me = _require();
    final next = item.toggled(type);
    void replace(FeedItem from, FeedItem to) {
      _feed = [for (final f in _feed) f.key == from.key ? to : f];
      notifyListeners();
    }

    replace(item, next);
    try {
      await backend.setCheer(
        item.post.ownerUid,
        item.post.recordId,
        me.uid,
        next.mine,
      );
    } on FriendException {
      replace(next, item);
      rethrow;
    }
  }

  static List<PublicProfile> _sorted(List<PublicProfile> people) =>
      people..sort((a, b) => a.name.compareTo(b.name));

  /// 이름 일부나 아이디로 찾습니다. 나 자신도 결과에 들어갈 수 있습니다([relation]이 me).
  Future<List<PublicProfile>> search(String query) async {
    final text = query.trim().toLowerCase().replaceAll(RegExp(r'\s'), '');
    if (text.isEmpty) return const [];
    _require();
    final found = await backend.search(
      text.startsWith('@') ? text.substring(1) : text,
    );
    return _sorted([...found]);
  }

  /// 친구 요청을 보냅니다. 상대가 이미 나에게 요청했다면 바로 수락합니다.
  Future<void> sendRequest(PublicProfile person) async {
    final me = _require();
    if (relation(person.uid) == FriendRelation.incoming) return accept(person);
    await backend.sendRequest(me.uid, person.uid);
    _outgoing = {..._outgoing, person.uid};
    notifyListeners();
  }

  Future<void> cancelRequest(String uid) async {
    final me = _require();
    await backend.cancelRequest(me.uid, uid);
    _outgoing = {..._outgoing}..remove(uid);
    notifyListeners();
  }

  Future<void> accept(PublicProfile person) async {
    final me = _require();
    await backend.accept(
      me.uid,
      person.uid,
      alsoMine: _outgoing.contains(person.uid),
    );
    _incoming = [..._incoming]..removeWhere((p) => p.uid == person.uid);
    _outgoing = {..._outgoing}..remove(person.uid);
    if (!_friends.any((f) => f.uid == person.uid)) {
      _friends = _sorted([..._friends, person]);
    }
    notifyListeners();
  }

  Future<void> decline(PublicProfile person) async {
    final me = _require();
    await backend.decline(me.uid, person.uid);
    _incoming = [..._incoming]..removeWhere((p) => p.uid == person.uid);
    notifyListeners();
  }

  Future<void> remove(String uid) async {
    final me = _require();
    await backend.removeFriend(me.uid, uid);
    _friends = [..._friends]..removeWhere((f) => f.uid == uid);
    _feed = [..._feed]..removeWhere((f) => f.post.ownerUid == uid);
    notifyListeners();
  }
}
