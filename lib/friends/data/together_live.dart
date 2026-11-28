import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'friend_store.dart' show FriendException;
import 'together_store.dart';

/// 러닝 화면 카드에 보이는 함께 달리는 친구의 상태.
enum LiveFriendState {
  /// 아직 출발하지 않았어요.
  waiting,
  running,
  paused,

  /// 한동안 소식이 없어요(신호가 끊겼거나 앱이 꺼졌어요).
  lost,

  /// 달리기를 끝내고 결과를 올렸어요.
  finished,
}

/// 함께 달리는 친구 한 명. [run]은 실시간 상태, [result]는 끝낸 뒤 올린 결과입니다.
@immutable
class LiveFriend {
  const LiveFriend({
    required this.uid,
    required this.name,
    required this.state,
    this.run,
    this.result,
    this.color,
  });
  final String uid, name;
  final LiveFriendState state;
  final LiveRun? run;
  final TogetherResult? result;

  /// 크루 모집에서 고른 이름표 색 번호. 친구 약속이면 null(색을 고르지 않음).
  final int? color;
}

/// 함께 달리는 동안 실시간 상태를 주고받는 곳. 친구 약속(`together/{번호}/live`)과
/// 크루 모집(`crews/{크루}/runs/{모집}/live`)이 같은 방식으로 씁니다.
abstract class LiveChannel {
  /// 로그인한 나. 로그아웃 상태면 null.
  String? get myUid;

  /// 함께 달리는 사람의 이름.
  String nameOf(String uid);

  /// 나를 뺀 함께 달리는 사람들과, 이미 끝냈으면 그 결과.
  List<(String, TogetherResult?)> others();

  /// 함께 달리는 사람·결과가 바뀌면 알려 줍니다.
  Stream<void> watchMembers();

  Stream<List<LiveRun>> watchLive();
  Future<void> send(LiveRun run, {required int sentPoints});
  Future<void> delete(String uid);

  /// 고른 이름표 색 번호. 색이 없는 곳(친구 약속)이면 null.
  int? colorOf(String uid);

  /// true면 끝나도 내 지나간 길을 지우지 않습니다(크루: 먼저 끝낸 팀원의 길을 끝난 자리까지 보여 주고,
  /// 팀이 끝나면 서버가 팀 기록에 옮긴 뒤 정리합니다). false면 끝날 때 지웁니다(친구 약속).
  bool get keepAfterFinish;
}

/// 친구 약속의 실시간 상태(`together/{번호}/live/{uid}`).
class _TogetherChannel implements LiveChannel {
  _TogetherChannel(this.togetherId, this.store)
    : _together = store.byId(togetherId);

  final String togetherId;
  final TogetherStore store;
  Together? _together;

  @override
  String? get myUid => store.me?.uid;

  @override
  String nameOf(String uid) => store.person(uid)?.name ?? '친구';

  @override
  List<(String, TogetherResult?)> others() {
    final t = _together, me = myUid;
    if (t == null || me == null) return const [];
    return [
      for (final uid in t.others(me))
        if (t.statusOf(uid) == TogetherStatus.accepted) (uid, t.results[uid]),
    ];
  }

  @override
  Stream<void> watchMembers() =>
      store.watch(togetherId).where((t) => t != null).map((t) {
        _together = t;
      });

  @override
  Stream<List<LiveRun>> watchLive() =>
      store.backend.watchTogetherLive(togetherId);

  @override
  Future<void> send(LiveRun run, {required int sentPoints}) =>
      store.backend.setTogetherLive(togetherId, run, sentPoints: sentPoints);

  @override
  Future<void> delete(String uid) =>
      store.backend.deleteTogetherLive(togetherId, uid);

  @override
  int? colorOf(String uid) => null;

  @override
  bool get keepAfterFinish => false;
}

/// 함께 달리는 동안 내 거리·시간·위치·지나간 길을 함께 달리는 사람들과 주고받습니다.
/// [interval]마다 올리고, 끝나면([close]) 지웁니다. 친구 약속은 [TogetherLive.new],
/// 크루 모집은 [TogetherLive.channel]로 만듭니다.
class TogetherLive extends ChangeNotifier {
  TogetherLive(
    String togetherId, {
    TogetherStore? store,
    DateTime Function()? clock,
  }) : _channel = _TogetherChannel(togetherId, store ?? TogetherStore.instance),
       _clock = clock ?? DateTime.now;

  /// 크루 모집처럼 다른 곳의 실시간 상태를 주고받을 때.
  TogetherLive.channel(LiveChannel channel, {DateTime Function()? clock})
    : _channel = channel,
      _clock = clock ?? DateTime.now;

  /// 올리는 간격.
  static const interval = Duration(seconds: 5);

  /// 멈춰 있어서 바뀐 게 없어도 이 간격마다 올려, 친구 폰이 '신호 없음'으로 보지 않게 합니다.
  static const heartbeat = Duration(seconds: 15);

  /// 친구 소식이 이보다 오래 없으면 '신호 없음'.
  static const lostAfter = Duration(seconds: 30);

  /// 지나간 길은 이만큼 움직일 때마다 점을 하나 더합니다.
  static const routeStepMeters = 15.0;

  final LiveChannel _channel;
  final DateTime Function() _clock;

  StreamSubscription<List<LiveRun>>? _liveSub;
  StreamSubscription<void>? _membersSub;
  Timer? _timer;
  bool _started = false, _closed = false, _sending = false;

  // 내 상태.
  LiveRun? _mine;
  List<(double, double)> _route = const [];
  int _sentPoints = 0;
  LiveRun? _sent;
  DateTime? _sentAt;

  // 친구들.
  Map<String, LiveRun> _runs = const {};
  final Map<String, DateTime> _heardAt = {};

  /// 친구 소식을 받고 올리기를 시작합니다.
  void start() {
    if (_started || _closed) return;
    _started = true;
    _membersSub = _channel.watchMembers().listen((_) {
      if (!_closed) notifyListeners();
    }, onError: (Object _) {});
    _liveSub = _channel.watchLive().listen(_onLive, onError: (Object _) {});
    _timer = Timer.periodic(interval, (_) => _publish());
  }

  /// 러닝 화면이 상태가 바뀔 때마다 부릅니다. 올리는 건 [interval]마다 한 번입니다.
  /// [routePoint]는 거리 계산에 쓴 마지막 좌표(흔들림을 걸러 낸 점)입니다.
  void update({
    required double meters,
    required Duration moving,
    required bool paused,
    (double, double)? position,
    (double, double)? routePoint,
  }) {
    final me = _channel.myUid;
    if (_closed || me == null) return;
    // 0.5초마다 불리므로 점이 늘 때만 새 목록을 만듭니다.
    if (routePoint != null &&
        (_route.isEmpty ||
            _meters(_route.last, routePoint) >= routeStepMeters)) {
      _route = List.unmodifiable([..._route, routePoint]);
    }
    _mine = LiveRun(
      uid: me,
      distanceKm: meters / 1000,
      movingSeconds: moving.inSeconds,
      paused: paused,
      position: position,
      route: _route,
    );
  }

  /// [force]면 바뀐 게 없어도 올립니다(크루에서 끝낼 때 마지막 위치를 남기려고).
  Future<void> _publish({bool force = false}) async {
    final mine = _mine;
    if (_closed || _sending || mine == null) return;
    final now = _clock();
    final sentAt = _sentAt;
    final changed = !_same(mine, _sent) || mine.route.length > _sentPoints;
    if (!force &&
        !changed &&
        sentAt != null &&
        now.difference(sentAt) < heartbeat) {
      return;
    }
    if (force && !changed) return;
    _sending = true;
    try {
      await _channel.send(mine, sentPoints: _sentPoints);
      _sent = mine;
      _sentAt = now;
      _sentPoints = mine.route.length;
    } on FriendException {
      // 인터넷이 잠깐 끊겼으면 다음 차례에 다시 올립니다.
    } finally {
      _sending = false;
    }
  }

  static bool _same(LiveRun a, LiveRun? b) =>
      b != null &&
      a.distanceKm == b.distanceKm &&
      a.movingSeconds == b.movingSeconds &&
      a.paused == b.paused &&
      a.position == b.position;

  void _onLive(List<LiveRun> runs) {
    if (_closed) return;
    final now = _clock();
    final next = {for (final r in runs) r.uid: r};
    // 친구가 올릴 때마다 서버 시각(updatedAt)이 바뀝니다. 멈춰 있어도 [heartbeat]마다 새 소식이 옵니다.
    for (final r in runs) {
      final before = _runs[r.uid];
      if (before == null || r.updatedAt != before.updatedAt) {
        _heardAt[r.uid] = now;
      }
    }
    _runs = next;
    notifyListeners();
  }

  /// 나를 뺀, 함께 달리는 사람들(친구 약속은 수락한 친구, 크루는 같은 모집 사람).
  List<LiveFriend> get friends {
    final now = _clock();
    return [
      for (final (uid, result) in _channel.others())
        () {
          final run = _runs[uid];
          final heard = _heardAt[uid];
          final state = result != null
              ? LiveFriendState.finished
              : run == null
              ? LiveFriendState.waiting
              : heard == null || now.difference(heard) > lostAfter
              ? LiveFriendState.lost
              : run.paused
              ? LiveFriendState.paused
              : LiveFriendState.running;
          return LiveFriend(
            uid: uid,
            name: _channel.nameOf(uid),
            state: state,
            run: run,
            result: result,
            color: _channel.colorOf(uid),
          );
        }(),
    ];
  }

  /// 달리기를 끝내거나 화면을 닫을 때 부릅니다. 서버의 내 위치·지나간 길을 지웁니다. 여러 번 불러도 됩니다.
  /// 크루([LiveChannel.keepAfterFinish])는 지우지 않고, 끝난 자리까지 남도록 마지막 상태를 한 번 더 올립니다.
  Future<void> close() async {
    if (_closed) return;
    final me = _channel.myUid;
    if (_channel.keepAfterFinish) {
      _timer?.cancel();
      if (_started && me != null) await _publish(force: true);
    }
    _closed = true;
    _timer?.cancel();
    unawaited(_liveSub?.cancel());
    unawaited(_membersSub?.cancel());
    if (!_started || me == null || _channel.keepAfterFinish) return;
    try {
      await _channel.delete(me);
    } on FriendException {
      // 결과를 올릴 때 한 번 더 지웁니다(TogetherStore).
    }
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }

  /// 두 좌표 사이 거리(m).
  static double _meters((double, double) a, (double, double) b) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.$1 - a.$1), dLng = rad(b.$2 - a.$2);
    final x =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.$1)) *
            math.cos(rad(b.$1)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(x));
  }
}
