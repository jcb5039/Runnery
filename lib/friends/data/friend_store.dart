import 'package:flutter/foundation.dart';

import '../../account/account_store.dart';
import 'friend_backend.dart';
import 'friend_models.dart';

export 'friend_backend.dart' show FriendBackend, FriendException;
export 'friend_models.dart'
    show
        CheerType,
        FeedItem,
        FeedPost,
        FriendRelation,
        FriendReport,
        PublicProfile,
        ReportReason;

/// 친구 탭이 보여 주는 친구 목록과 친구 요청. 서버가 원본이고, 이 기기에는 저장하지 않습니다.
class FriendStore extends ChangeNotifier {
  FriendStore({
    FriendBackend? backend,
    PublicProfile? Function()? me,
    DateTime Function()? clock,
  }) : _backend = backend,
       _me = me ?? loggedIn,
       _clock = clock ?? DateTime.now;

  /// 앱 전체가 쓰는 저장소. 테스트에서만 교체합니다.
  static FriendStore instance = FriendStore();

  FriendBackend? _backend;
  final PublicProfile? Function() _me;
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
  List<FeedItem> _myFeed = const [];
  List<PublicProfile> _blocked = const [];

  /// 차단하기를 눌렀지만 '되돌리기'를 기다리는 동안 피드에서 감춰 둔 사람.
  Set<String> _hiding = const {};
  bool _loading = false;
  String? _error, _feedError;

  /// 이름순 친구 목록.
  List<PublicProfile> get friends => _friends;

  /// 나에게 친구 요청을 보낸 사람들.
  List<PublicProfile> get incoming => _incoming;

  bool get loading => _loading;

  /// 마지막으로 불러오기에 실패했다면 그 이유.
  String? get error => _error;

  /// 친구들이 공유한 최근 러닝. 최근에 달린 순서입니다.
  List<FeedItem> get feed => [
    for (final item in _feed)
      if (!_hiding.contains(item.post.ownerUid)) item,
  ];

  /// 내가 차단한 사람들(이름순).
  List<PublicProfile> get blocked => _blocked;

  /// 내가 공유한 기록과 친구들에게 받은 응원.
  List<FeedItem> get myFeed => _myFeed;

  /// 피드를 불러오지 못했다면 그 이유(친구 목록은 따로 불러옵니다).
  String? get feedError => _feedError;

  /// 로그인한 계정의 공개 정보. 로그아웃 상태면 null.
  PublicProfile? get me => _me();

  /// 지금 시각. 함께 달리기 약속 시간을 정할 때 씁니다.
  DateTime get now => _clock();

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
    _myFeed = const [];
    _blocked = const [];
    _hiding = const {};
    _error = null;
    _feedError = null;
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
        backend.blockedIds(me.uid),
      ]);
      final [friendIds, incomingIds, outgoing, blockedIds] = lists;
      final people = await backend.profiles(
        {...friendIds, ...incomingIds, ...blockedIds}.toList(),
      );
      if (me.uid != _owner) throw const FriendException('계정이 바뀌었어요');
      _friends = _sorted([for (final id in friendIds) ?people[id]]);
      // 차단한 사람의 요청은 보여 주지 않습니다(예전에 받아 둔 요청이 남아 있을 때).
      _incoming = [
        for (final id in incomingIds)
          if (!friendIds.contains(id) && !blockedIds.contains(id)) ?people[id],
      ];
      _outgoing = outgoing.toSet();
      _blocked = _sorted([for (final id in blockedIds) ?people[id]]);
      _error = null;
    } on FriendException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return;
    }
    await _refreshFeed(me);
    _loading = false;
    notifyListeners();
  }

  Future<void> _refreshFeed(PublicProfile me) async {
    try {
      final (feed, mine) = await (
        _loadFeed(me.uid, _friends),
        _loadFeed(me.uid, [me], perPerson: feedSize),
      ).wait;
      if (me.uid != _owner) return;
      _feed = feed;
      _myFeed = mine;
      _feedError = null;
    } on FriendException catch (e) {
      _feedError = e.message;
    }
  }

  /// [friends]마다 최근 공유 기록을 읽어 합친 뒤, 카드마다 응원을 읽습니다.
  /// 내 피드는 [friends]에 나만 넣어 부릅니다.
  Future<List<FeedItem>> _loadFeed(
    String me,
    List<PublicProfile> friends, {
    int perPerson = feedPerFriend,
  }) async {
    final perFriend = await Future.wait(
      friends.map((f) => backend.posts(f.uid, limit: perPerson)),
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
          cheeredBy: [
            for (final MapEntry(key: uid, value: types) in cheers[i].entries)
              if (types.isNotEmpty && uid != me)
                _friends.where((f) => f.uid == uid).firstOrNull?.name ?? '친구',
          ],
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
    // 차단한 사람은 찾아도 나오지 않습니다(차단 풀기는 내 친구 화면에서).
    final blocked = {for (final p in _blocked) p.uid};
    return _sorted([
      for (final p in found)
        if (!blocked.contains(p.uid)) p,
    ]);
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

  /// 친구 달력: [uid]가 [month]에 공유한 기록. 최근에 달린 순서입니다.
  Future<List<FeedPost>> monthPosts(String uid, DateTime month) {
    _require();
    final from = DateTime(month.year, month.month);
    return backend.postsBetween(uid, from, DateTime(from.year, from.month + 1));
  }

  /// '되돌리기'를 기다리는 동안 [uid]의 카드를 피드에서 감추거나([hide]) 다시 보입니다.
  void hideFromFeed(String uid, {required bool hide}) {
    _hiding = hide ? {..._hiding, uid} : ({..._hiding}..remove(uid));
    notifyListeners();
  }

  /// [person]을 차단합니다. 친구에서 지우고, 주고받은 친구 요청도 지웁니다.
  Future<void> block(PublicProfile person) async {
    final me = _require();
    await backend.block(
      me.uid,
      person.uid,
      incoming: _incoming.any((p) => p.uid == person.uid),
      outgoing: _outgoing.contains(person.uid),
    );
    _friends = [..._friends]..removeWhere((f) => f.uid == person.uid);
    _incoming = [..._incoming]..removeWhere((p) => p.uid == person.uid);
    _outgoing = {..._outgoing}..remove(person.uid);
    _feed = [..._feed]..removeWhere((f) => f.post.ownerUid == person.uid);
    _hiding = {..._hiding}..remove(person.uid);
    if (!_blocked.any((p) => p.uid == person.uid)) {
      _blocked = _sorted([..._blocked, person]);
    }
    notifyListeners();
  }

  /// 차단을 풉니다. 다시 친구가 되려면 친구 요청을 새로 보내야 합니다.
  Future<void> unblock(String uid) async {
    final me = _require();
    await backend.unblock(me.uid, uid);
    _blocked = [..._blocked]..removeWhere((p) => p.uid == uid);
    notifyListeners();
  }

  /// [person]을 신고합니다. 상대에게는 알려지지 않습니다.
  Future<void> report(
    PublicProfile person,
    ReportReason reason, {
    String detail = '',
    String? recordId,
  }) async {
    final me = _require();
    final text = detail.trim();
    await backend.report(
      FriendReport(
        reporter: me.uid,
        target: person.uid,
        reason: reason,
        detail: text.length > FriendReport.maxDetail
            ? text.substring(0, FriendReport.maxDetail)
            : text,
        recordId: recordId,
      ),
    );
  }
}
