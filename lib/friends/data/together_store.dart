import 'package:flutter/foundation.dart';

import '../../record/data/running_record_store.dart';
import '../../record/models/running_record.dart';
import 'friend_store.dart';
import 'friend_models.dart';

export 'friend_models.dart'
    show
        Together,
        TogetherResult,
        TogetherStatus,
        agoLabel,
        togetherTimeLabel,
        weekdayLetter;

/// 함께 달리기 약속: 보내기, 받은 요청에 답하기, 대기실에서 함께 시작하기, 각자 결과 올리기.
/// 약속은 서버 `together/{번호}`에 있고 참여자만 봅니다. 폰에는 저장하지 않습니다.
class TogetherStore extends ChangeNotifier {
  TogetherStore({
    FriendBackend? backend,
    PublicProfile? Function()? me,
    Future<List<RunningRecord>> Function()? records,
    DateTime Function()? clock,
  }) : _backend = backend,
       _me = me ?? FriendStore.loggedIn,
       _records = records ?? (() => RunningRecordStore.instance.load()),
       _clock = clock ?? DateTime.now;

  /// 앱 전체가 쓰는 저장소. 테스트에서만 교체합니다.
  static TogetherStore instance = TogetherStore();

  final FriendBackend? _backend;
  final PublicProfile? Function() _me;
  final Future<List<RunningRecord>> Function() _records;
  final DateTime Function() _clock;

  FriendBackend get backend => _backend ?? FriendStore.instance.backend;

  String? _owner;
  List<Together> _items = const [];
  final Map<String, PublicProfile> _people = {};
  bool _loading = false;
  String? _error;

  PublicProfile? get me => _me();
  DateTime get now => _clock();
  bool get loading => _loading;
  String? get error => _error;

  /// 참여자의 공개 정보. 아직 모르면 null.
  PublicProfile? person(String uid) => uid == me?.uid ? me : _people[uid];

  /// 나에게 온, 아직 답하지 않은 약속.
  List<Together> get requests => _where(
    (t, me) => t.statusOf(me) == TogetherStatus.pending && !t.isPast(me, now),
  )..sort((a, b) => b.createdAtOrStart.compareTo(a.createdAtOrStart));

  /// 수락한, 아직 끝나지 않은 약속. 가까운 약속부터.
  List<Together> get active => _where(
    (t, me) => t.statusOf(me) == TogetherStatus.accepted && !t.isPast(me, now),
  )..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  /// 수락했고 끝난 약속. 최근 것부터.
  List<Together> get past => _where(
    (t, me) => t.statusOf(me) == TogetherStatus.accepted && t.isPast(me, now),
  )..sort((a, b) => b.startsAt.compareTo(a.startsAt));

  Together? byId(String id) => _items.where((t) => t.id == id).firstOrNull;

  List<Together> _where(bool Function(Together, String) test) {
    final uid = me?.uid;
    if (uid == null) return [];
    return [
      for (final t in _items)
        if (test(t, uid)) t,
    ];
  }

  PublicProfile _require() {
    final me = _me();
    if (me == null) throw const FriendException('로그인이 필요해요');
    if (me.uid != _owner) {
      _owner = me.uid;
      _items = const [];
      _people.clear();
      _error = null;
    }
    return me;
  }

  /// 서버에서 약속을 다시 읽고, 못 올린 내 결과가 있으면 올립니다.
  Future<void> refresh() async {
    // 화면을 만드는 도중(initState)에 불려도 괜찮도록 한 박자 뒤에 시작합니다.
    await Future<void>.value();
    final PublicProfile me;
    try {
      me = _require();
    } on FriendException {
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      final items = await backend.togethers(me.uid);
      final unknown = {
        for (final t in items)
          for (final m in t.members)
            if (m != me.uid && !_people.containsKey(m)) m,
      };
      if (unknown.isNotEmpty) {
        _people.addAll(await backend.profiles(unknown.toList()));
      }
      if (me.uid != _owner) return;
      _items = items;
      _error = null;
      await _linkMissing(me);
    } on FriendException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 함께 시작했는데 결과를 못 올린 약속(인터넷이 끊겼을 때 등)에, 시작 시각 근처에 시작한
  /// 내 러닝을 찾아 올립니다.
  Future<void> _linkMissing(PublicProfile me) async {
    final missing = [
      for (final t in _items)
        if (t.startedAt != null &&
            t.statusOf(me.uid) == TogetherStatus.accepted &&
            !t.results.containsKey(me.uid))
          t,
    ];
    if (missing.isEmpty) return;
    List<RunningRecord> records;
    try {
      records = await _records();
    } catch (_) {
      return;
    }
    for (final t in missing) {
      final start = t.startedAt!;
      final match = records
          .where(
            (r) =>
                !r.startedAt.isBefore(start.subtract(_linkBefore)) &&
                r.startedAt.isBefore(start.add(_linkAfter)),
          )
          .firstOrNull;
      if (match != null) await _submit(me, t, match);
    }
  }

  /// 함께 시작한 시각 기준으로 내 러닝을 찾는 범위. 늦게 합류한 경우까지 봅니다.
  static const _linkBefore = Duration(minutes: 1),
      _linkAfter = Duration(minutes: 30);

  Future<void> _submit(PublicProfile me, Together t, RunningRecord r) async {
    final result = TogetherResult(
      recordId: r.id,
      distanceKm: (r.distanceKm * 100).round() / 100,
      movingSeconds: r.movingSeconds,
      kcal: r.energyKcal.round(),
      finishedAt: r.endedAt,
    );
    await backend.submitTogetherResult(t.id, me.uid, result);
    replace(_copy(t, results: {...t.results, me.uid: result}));
  }

  /// 함께 달리기로 시작한 러닝을 저장한 뒤 부릅니다. 실패하면 친구 탭을 열 때 다시 올립니다.
  Future<void> runFinished(String togetherId, RunningRecord record) async {
    final me = _me();
    if (me == null) return;
    try {
      _require();
      final t =
          byId(togetherId) ?? await backend.watchTogether(togetherId).first;
      if (t == null) return;
      await _submit(me, t, record);
    } on FriendException {
      // 다음에 친구 탭을 열면 다시 올립니다.
    }
  }

  /// 약속을 보냅니다. [at]은 약속한 날짜·시간입니다.
  Future<void> create(
    List<PublicProfile> friends,
    DateTime at,
    int goalKm,
  ) async {
    final me = _require();
    if (friends.isEmpty) throw const FriendException('함께 달릴 친구를 골라 주세요');
    final members = [me.uid, for (final f in friends) f.uid];
    final id = await backend.createTogether(
      host: me.uid,
      members: members,
      startsAt: at,
      goalKm: goalKm,
    );
    for (final f in friends) {
      _people[f.uid] = f;
    }
    _items = [
      ..._items,
      Together(
        id: id,
        host: me.uid,
        members: members,
        statuses: {
          for (final m in members)
            m: m == me.uid ? TogetherStatus.accepted : TogetherStatus.pending,
        },
        startsAt: at,
        goalKm: goalKm,
        createdAt: now,
      ),
    ];
    notifyListeners();
  }

  /// 받은 요청에 수락·거절로 답하거나, 거절을 되돌립니다(pending).
  Future<void> answer(Together t, TogetherStatus status) async {
    final me = _require();
    await backend.setTogetherStatus(t.id, me.uid, status);
    replace(_copy(t, statuses: {...t.statuses, me.uid: status}));
  }

  /// 보낸 사람이 약속을 취소합니다.
  Future<void> cancel(Together t) async {
    _require();
    await backend.deleteTogether(t.id);
    _items = [..._items]..removeWhere((x) => x.id == t.id);
    notifyListeners();
  }

  Stream<Together?> watch(String id) => backend.watchTogether(id);

  Future<void> setReady(String id, {required bool ready}) async {
    final me = _require();
    await backend.setTogetherReady(id, me.uid, ready: ready);
  }

  Future<void> start(String id) async {
    _require();
    await backend.startTogether(id);
  }

  /// 대기실에서 받은 최신 약속으로 바꿔 둡니다.
  void replace(Together t) {
    _items = [
      for (final x in _items)
        if (x.id != t.id) x,
      t,
    ];
    notifyListeners();
  }

  /// 약속에서 한 사람이 남은 사람들에게 보이는 이름 목록. 예: 박하은, 최유나
  String names(Together t, {String? except}) => [
    for (final m in t.members)
      if (m != (except ?? me?.uid)) person(m)?.name ?? '친구',
  ].join(', ');

  static Together _copy(
    Together t, {
    Map<String, TogetherStatus>? statuses,
    Map<String, TogetherResult>? results,
  }) => Together(
    id: t.id,
    host: t.host,
    members: t.members,
    statuses: statuses ?? t.statuses,
    startsAt: t.startsAt,
    goalKm: t.goalKm,
    createdAt: t.createdAt,
    ready: t.ready,
    startedAt: t.startedAt,
    results: results ?? t.results,
  );
}

extension on Together {
  DateTime get createdAtOrStart => createdAt ?? startsAt;
}
