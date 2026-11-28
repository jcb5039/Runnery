import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import 'crew_backend.dart';
import 'crew_models.dart';
import 'friend_store.dart';
import 'friend_models.dart' show LiveRun, TogetherResult;
import 'together_live.dart' show LiveChannel;

export 'crew_backend.dart' show CrewBackend;
export 'crew_models.dart';

/// 크루 탭이 보여 주는 내 크루, 받은 크루 초대, 안 읽은 메시지 수. 서버가 원본이고 폰에는 저장하지 않습니다.
class CrewStore extends ChangeNotifier {
  CrewStore({
    CrewBackend? backend,
    PublicProfile? Function()? me,
    DateTime Function()? clock,
  }) : _backend = backend,
       _me = me ?? FriendStore.loggedIn,
       _clock = clock ?? DateTime.now;

  /// 앱 전체가 쓰는 저장소. 테스트에서만 교체합니다.
  static CrewStore instance = CrewStore();

  CrewBackend? _backend;
  final PublicProfile? Function() _me;
  final DateTime Function() _clock;

  CrewBackend get backend => _backend ??= FirebaseCrewBackend();

  String? _owner;
  List<Crew> _crews = const [];
  List<CrewInvite> _invites = const [];
  final Map<String, PublicProfile> _people = {};
  final Map<String, int> _unread = {};
  final Map<String, bool> _muted = {};

  /// 크루 번호 → 내가 들어온 시각. 들어오기 전의 채팅·미리보기는 보여 주지 않습니다.
  final Map<String, DateTime> _joined = {};
  StreamSubscription<List<Crew>>? _crewSub;
  StreamSubscription<List<CrewInvite>>? _inviteSub;
  bool _loaded = false;
  String? _error;

  /// 지금 열려 있는 채팅방(크루 번호). 나중에 연 방이 뒤쪽입니다.
  final List<String> _viewing = [];

  /// 내가 직접 나간(나가는 중인) 크루. 채팅방이 '내보내졌어요' 안내를 띄우지 않게 합니다.
  final Set<String> _left = {};

  PublicProfile? get me => _me();
  DateTime get now => _clock();

  /// 내 크루. 최근에 이야기한 크루부터.
  List<Crew> get crews => _crews;

  /// 나에게 온 크루 초대.
  List<CrewInvite> get invites => _invites;

  /// 처음 목록을 받기 전이면 false.
  bool get loaded => _loaded;
  String? get error => _error;

  Crew? byId(String id) => _crews.where((c) => c.id == id).firstOrNull;

  /// 멤버의 공개 정보. 아직 모르면 null.
  PublicProfile? person(String uid) => uid == me?.uid ? me : _people[uid];

  String nameOf(String uid) => person(uid)?.name ?? '멤버';

  int unread(String crewId) => _unread[crewId] ?? 0;

  /// 안 읽은 채팅이 있는 크루가 하나라도 있으면 true(알림을 꺼 둔 크루도 셉니다).
  bool get hasUnread => _crews.any((c) => unread(c.id) > 0);

  /// 이 크루의 채팅방을 보고 있으면 true(가장 나중에 연 채팅방만 셉니다). 채팅 알림 띠를 띄울지 정할 때 씁니다.
  bool viewing(String crewId) => _viewing.isNotEmpty && _viewing.last == crewId;

  /// 채팅방이 열릴 때·닫힐 때 부릅니다.
  void openedRoom(String crewId) => _viewing.add(crewId);
  void closedRoom(String crewId) => _viewing.remove(crewId);

  /// 내가 직접 나갔거나 나가는 중인 크루면 true. 다시 초대를 받아 들어오면 false가 됩니다.
  bool leftByMe(String crewId) => _left.contains(crewId);
  bool muted(String crewId) => _muted[crewId] ?? false;

  PublicProfile _require() {
    final me = _me();
    if (me == null) {
      _stop();
      throw const FriendException('로그인이 필요해요');
    }
    if (me.uid != _owner) {
      _stop();
      _owner = me.uid;
    }
    return me;
  }

  void _stop() {
    _crewSub?.cancel();
    _inviteSub?.cancel();
    _crewSub = null;
    _inviteSub = null;
    _owner = null;
    _crews = const [];
    _invites = const [];
    _unread.clear();
    _muted.clear();
    _joined.clear();
    _left.clear();
    _loaded = false;
    _error = null;
  }

  /// 내 크루와 받은 초대를 실시간으로 받기 시작합니다. 이미 받고 있으면 아무것도 하지 않습니다.
  void start() {
    final PublicProfile me;
    try {
      me = _require();
    } on FriendException {
      // 로그아웃 상태면 불러올 것이 없으니 빈 목록을 보여 줍니다.
      _loaded = true;
      notifyListeners();
      return;
    }
    _crewSub ??= backend
        .watchMyCrews(me.uid)
        .listen(
          (crews) {
            if (me.uid != _owner) return;
            _crews = [...crews]
              ..sort((a, b) => b.activeAt.compareTo(a.activeAt));
            _loaded = true;
            _error = null;
            notifyListeners();
            unawaited(
              _loadPeople({for (final c in crews) ...c.members.take(4)}),
            );
            unawaited(_refreshUnread(me));
          },
          onError: (Object e) {
            _loaded = true;
            _error = e is FriendException ? e.message : '크루를 불러오지 못했어요';
            notifyListeners();
          },
        );
    _inviteSub ??= backend.watchInvites(me.uid).listen((invites) {
      if (me.uid != _owner) return;
      _invites = invites;
      notifyListeners();
      unawaited(_loadPeople({for (final i in invites) i.from}));
    }, onError: (Object _) {});
  }

  /// 앱을 켜 둔 동안 받은 크루 초대를 실시간으로 받습니다(알림 띠용). 로그아웃 상태면 아무것도 오지 않습니다.
  Stream<List<CrewInvite>> watchInvites() {
    final PublicProfile me;
    try {
      me = _require();
    } on FriendException {
      return const Stream.empty();
    }
    return backend.watchInvites(me.uid);
  }

  /// 처음 쓸 때 [start]를 부르고, 안 읽은 수를 다시 셉니다.
  Future<void> refresh() async {
    await Future<void>.value();
    start();
    final me = _me();
    if (me != null && me.uid == _owner) await _refreshUnread(me);
  }

  Future<void> _refreshUnread(PublicProfile me) async {
    for (final crew in _crews) {
      try {
        final member = await backend.member(crew.id, me.uid);
        if (me.uid != _owner) return;
        _muted[crew.id] = member?.muted ?? false;
        if (member != null) _joined[crew.id] = member.joinedAt;
        final last = crew.lastMessage;
        final read = member?.lastReadAt;
        // 내 메시지가 마지막이거나 읽은 뒤에 온 메시지가 없으면 세지 않습니다.
        _unread[crew.id] =
            last == null ||
                last.uid == me.uid ||
                (read != null && !last.at.isAfter(read))
            ? 0
            : await backend.countSince(
                crew.id,
                read ?? DateTime.fromMillisecondsSinceEpoch(0),
              );
      } on FriendException {
        // 다음에 다시 셉니다.
      }
    }
    notifyListeners();
  }

  /// 아직 모르는 사람들의 공개 정보를 불러옵니다.
  Future<void> _loadPeople(Set<String> uids) async {
    final unknown = [
      for (final uid in uids)
        if (uid != me?.uid && !_people.containsKey(uid)) uid,
    ];
    if (unknown.isEmpty) return;
    try {
      _people.addAll(await backend.profiles(unknown));
      notifyListeners();
    } on FriendException {
      // 이름을 못 가져오면 '멤버'로 보입니다.
    }
  }

  /// 채팅방·서랍이 멤버 이름을 보여 주기 전에 부릅니다.
  Future<void> loadPeople(Iterable<String> uids) => _loadPeople(uids.toSet());

  /// 크루를 만들고 초대 코드를 붙인 뒤, 고른 친구들에게 초대를 보냅니다. 만든 크루 번호를 돌려줍니다.
  Future<String> create(String name, List<PublicProfile> invitees) async {
    final me = _require();
    final text = name.trim();
    if (text.isEmpty) throw const FriendException('크루 이름을 정해 주세요');
    if (text.length > Crew.maxName) {
      throw const FriendException('크루 이름은 20자까지예요');
    }
    final id = await backend.createCrew(me.uid, text);
    final crew = Crew(id: id, name: text, owner: me.uid, members: [me.uid]);
    if (byId(id) == null) {
      _crews = [crew, ..._crews];
      notifyListeners();
    }
    try {
      await backend.issueCode(id);
    } on FriendException {
      // 코드를 못 만들었으면 크루장이 서랍을 열 때 다시 만듭니다.
    }
    for (final person in invitees) {
      try {
        await backend.invite(crew, me.uid, person.uid);
      } on FriendException {
        // 크루는 만들어졌으니, 못 보낸 초대는 서랍에서 다시 보낼 수 있습니다.
      }
    }
    start();
    return id;
  }

  Stream<Crew?> watch(String id) => backend.watchCrew(id);

  /// 채팅방 메시지. 내가 들어온 뒤의 것만 옵니다(나갔다 다시 들어오면 다시 들어온 때부터).
  /// 들어온 시각 기록이 없는 예전 멤버는 모두 봅니다.
  Stream<List<CrewMessage>> messages(String id, {int limit = 50}) async* {
    final since = await _joinedAt(id);
    yield* backend.watchMessages(id, limit: limit, since: since);
  }

  Future<DateTime> _joinedAt(String crewId) async {
    final known = _joined[crewId];
    if (known != null) return known;
    final me = _require();
    final member = await backend.member(crewId, me.uid);
    final at = member?.joinedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (member != null) _joined[crewId] = at;
    return at;
  }

  /// 목록에 보여 줄 마지막 메시지. 내가 들어오기 전의 메시지면 null입니다.
  CrewLastMessage? lastMessageOf(Crew crew) {
    final last = crew.lastMessage, joined = _joined[crew.id];
    if (last == null || (joined != null && last.at.isBefore(joined))) {
      return null;
    }
    return last;
  }

  Future<void> send(String crewId, String text) async {
    final me = _require();
    final body = text.trim();
    if (body.isEmpty) return;
    await backend.sendMessage(
      crewId,
      me.uid,
      body.length > CrewMessage.maxText
          ? body.substring(0, CrewMessage.maxText)
          : body,
    );
  }

  /// 채팅방을 보고 있을 때 부릅니다. 안 읽은 수를 0으로 합니다.
  Future<void> markRead(String crewId) async {
    // 화면을 만드는 도중(initState)에 불려도 괜찮도록 한 박자 뒤에 시작합니다.
    await Future<void>.value();
    final me = _require();
    _unread[crewId] = 0;
    notifyListeners();
    try {
      await backend.markRead(crewId, me.uid);
    } on FriendException {
      // 다음에 열 때 다시 표시합니다.
    }
  }

  Future<void> setMuted(String crewId, {required bool muted}) async {
    final me = _require();
    await backend.setMuted(crewId, me.uid, muted: muted);
    _muted[crewId] = muted;
    notifyListeners();
  }

  /// 멤버 목록(들어온 순서). 이름도 함께 불러옵니다.
  Future<List<CrewMember>> members(String crewId) async {
    final list = await backend.members(crewId);
    await _loadPeople({for (final m in list) m.uid});
    return list;
  }

  Future<void> setNotice(Crew crew, String text) async {
    final me = _require();
    if (!crew.isOwner(me.uid)) {
      throw const FriendException('공지는 크루장만 쓸 수 있어요');
    }
    final body = text.trim();
    await backend.setNotice(
      crew.id,
      me.uid,
      body.length > CrewNotice.maxText
          ? body.substring(0, CrewNotice.maxText)
          : body,
    );
  }

  Future<void> kick(Crew crew, String target) async {
    final me = _require();
    if (!crew.isOwner(me.uid) || target == me.uid) {
      throw const FriendException('크루장만 멤버를 내보낼 수 있어요');
    }
    await backend.kick(crew.id, me.uid, target);
  }

  /// 크루를 나갑니다. 방장이면 가장 오래된 멤버에게 방장을 넘기고, 혼자였으면 크루를 지웁니다.
  Future<void> leave(Crew crew) async {
    final me = _require();
    String? newOwner = '';
    if (crew.isOwner(me.uid)) {
      final others = [
        for (final m in await backend.members(crew.id))
          if (m.uid != me.uid) m,
      ];
      // 멤버 문서가 없는 멤버(예전 데이터)는 목록 순서대로 이어받습니다.
      newOwner = others.isNotEmpty
          ? others.first.uid
          : crew.members.where((m) => m != me.uid).firstOrNull;
    }
    // 나가기가 끝났다고 알기 전에 서버 소식이 먼저 올 수 있어서, 보내기 전에 적어 둡니다.
    _left.add(crew.id);
    try {
      await backend.leave(crew.id, me.uid, newOwner: newOwner);
    } catch (_) {
      _left.remove(crew.id);
      rethrow;
    }
    _crews = [..._crews]..removeWhere((c) => c.id == crew.id);
    _unread.remove(crew.id);
    // 다시 들어오면 그때부터 보이도록 들어온 시각을 잊습니다.
    _joined.remove(crew.id);
    notifyListeners();
  }

  /// 친구를 크루에 초대합니다.
  Future<void> invite(Crew crew, PublicProfile friend) async {
    final me = _require();
    if (crew.members.contains(friend.uid)) return;
    if (crew.members.length >= Crew.maxMembers) {
      throw const FriendException('크루는 200명까지예요');
    }
    await backend.invite(crew, me.uid, friend.uid);
  }

  /// 크루장이 초대 코드를 새로 만듭니다(예전 코드로는 더 못 들어옵니다). 코드가 없던 예전 크루에도 씁니다.
  Future<String> issueCode(Crew crew) async {
    final me = _require();
    if (!crew.isOwner(me.uid)) {
      throw const FriendException('크루장만 코드를 바꿀 수 있어요');
    }
    return backend.issueCode(crew.id);
  }

  /// 초대 코드로 크루에 들어갑니다(친구가 아니어도 됩니다). 들어간 크루 번호를 돌려줍니다.
  Future<String> joinByCode(String text) async {
    _require();
    final code = Crew.normalizeCode(text);
    if (code == null) throw const FriendException('코드 6자리를 확인해 주세요');
    final id = await backend.joinByCode(code);
    _left.remove(id);
    _joined.remove(id);
    start();
    return id;
  }

  /// 내가 이 크루에 초대해 두고 아직 답을 받지 못한 사람들.
  Future<Set<String>> invited(String crewId) async {
    final me = _require();
    return (await backend.invitedBy(crewId, me.uid)).toSet();
  }

  Future<void> accept(CrewInvite invite) async {
    _require();
    await backend.acceptInvite(invite);
    _left.remove(invite.crewId);
    _joined.remove(invite.crewId);
    _invites = [..._invites]..removeWhere((i) => i.id == invite.id);
    notifyListeners();
  }

  Future<void> decline(CrewInvite invite) async {
    _require();
    await backend.declineInvite(invite);
    _invites = [..._invites]..removeWhere((i) => i.id == invite.id);
    notifyListeners();
  }

  // ── 함께 달리기 모집(대기실). 규칙은 서버 함수가 지키고, 여기서는 부르기만 합니다. ──

  Stream<CrewRun?> watchRun(String crewId, String runId) =>
      backend.watchRun(crewId, runId);

  /// 모집을 열고 모집 번호를 돌려줍니다. 연 사람이 팀장입니다.
  Future<String> openRun(String crewId, String title) {
    _require();
    final text = title.trim();
    if (text.isEmpty) throw const FriendException('제목을 정해 주세요');
    if (text.characters.length > CrewRun.maxTitle) {
      throw const FriendException('제목은 20자까지예요');
    }
    return backend.runAction(crewId, 'create', title: text);
  }

  Future<void> joinRun(CrewRun run) async {
    _require();
    await backend.runAction(run.crewId, 'join', runId: run.id);
  }

  Future<void> setRunColor(CrewRun run, int color) async {
    _require();
    await backend.runAction(run.crewId, 'color', runId: run.id, color: color);
  }

  Future<void> setRunReady(CrewRun run, {required bool ready}) async {
    _require();
    await backend.runAction(run.crewId, 'ready', runId: run.id, ready: ready);
  }

  /// 대기실을 나갑니다. 팀장이면 모집이 없어집니다.
  Future<void> leaveRun(CrewRun run) async {
    _require();
    await backend.runAction(run.crewId, 'leave', runId: run.id);
  }

  /// 팀장이 러닝 시작을 누릅니다. 모두 준비돼 있어야 합니다.
  Future<void> startRun(CrewRun run) async {
    _require();
    await backend.runAction(run.crewId, 'start', runId: run.id);
  }

  /// 내 러닝을 끝내고 저장한 뒤 부릅니다. 모두 끝내면 팀 기록도 저절로 끝납니다.
  /// 서버의 내 실시간 상태도 지웁니다.
  Future<void> finishRun(
    String crewId,
    String runId, {
    required String recordId,
    required double distanceKm,
    required int movingSeconds,
    required int kcal,
  }) async {
    final me = _require();
    await backend.runAction(
      crewId,
      'finish',
      runId: runId,
      result: TogetherResult(
        recordId: recordId,
        distanceKm: distanceKm,
        movingSeconds: movingSeconds,
        kcal: kcal,
        finishedAt: now,
      ),
    );
    try {
      await backend.deleteRunLive(crewId, runId, me.uid);
    } on FriendException {
      // 다음에 끝낼 때 다시 지웁니다.
    }
  }

  /// 팀장이 팀을 끝냅니다. 아직 달리는 사람은 그때의 기록으로 팀 기록에 남고, 각자 계속 달릴 수 있습니다.
  Future<void> endTeam(String crewId, String runId) async {
    _require();
    await backend.runAction(crewId, 'end', runId: runId);
  }

  /// 종료 투표에 답합니다. [end]면 '종료', 아니면 '끝내지 않기'.
  Future<void> voteRun(String crewId, String runId, {required bool end}) async {
    _require();
    await backend.runAction(crewId, 'vote', runId: runId, voteEnd: end);
  }

  /// 서랍의 '함께 달린 기록'.
  Future<List<CrewRun>> endedRuns(String crewId) => backend.endedRuns(crewId);

  /// 러닝 화면이 같은 모집 사람들과 실시간 상태를 주고받을 곳.
  LiveChannel liveChannel(String crewId, String runId) =>
      _CrewRunChannel(this, crewId, runId);

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}

/// 크루 모집의 실시간 상태(`crews/{크루}/runs/{모집}/live/{uid}`). 같은 모집 사람만 보입니다.
class _CrewRunChannel implements LiveChannel {
  _CrewRunChannel(this.store, this.crewId, this.runId);

  final CrewStore store;
  final String crewId, runId;
  CrewRun? _run;

  @override
  String? get myUid => store.me?.uid;

  @override
  String nameOf(String uid) => store.nameOf(uid);

  @override
  List<(String, TogetherResult?)> others() {
    final run = _run, me = myUid;
    if (run == null || me == null) return const [];
    return [
      for (final uid in run.members)
        if (uid != me) (uid, run.results[uid]),
    ];
  }

  @override
  Stream<void> watchMembers() =>
      store.watchRun(crewId, runId).where((r) => r != null).map((r) {
        _run = r;
        unawaited(store.loadPeople(r!.members));
      });

  @override
  Stream<List<LiveRun>> watchLive() =>
      store.backend.watchRunLive(crewId, runId);

  @override
  Future<void> send(LiveRun run, {required int sentPoints}) =>
      store.backend.setRunLive(crewId, runId, run, sentPoints: sentPoints);

  @override
  Future<void> delete(String uid) =>
      store.backend.deleteRunLive(crewId, runId, uid);
}
