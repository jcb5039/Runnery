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
  });
  final String uid, name;
  final LiveFriendState state;
  final LiveRun? run;
  final TogetherResult? result;
}

/// 함께 달리는 동안 내 거리·시간·위치·지나간 길을 친구들과 주고받습니다.
/// 서버 `together/{번호}/live/{uid}`에 [interval]마다 올리고, 끝나면([close]) 지웁니다.
class TogetherLive extends ChangeNotifier {
  TogetherLive(
    this.togetherId, {
    TogetherStore? store,
    DateTime Function()? clock,
  }) : _store = store ?? TogetherStore.instance,
       _clock = clock ?? DateTime.now;

  /// 올리는 간격.
  static const interval = Duration(seconds: 5);

  /// 멈춰 있어서 바뀐 게 없어도 이 간격마다 올려, 친구 폰이 '신호 없음'으로 보지 않게 합니다.
  static const heartbeat = Duration(seconds: 15);

  /// 친구 소식이 이보다 오래 없으면 '신호 없음'.
  static const lostAfter = Duration(seconds: 30);

  /// 지나간 길은 이만큼 움직일 때마다 점을 하나 더합니다.
  static const routeStepMeters = 15.0;

  final String togetherId;
  final TogetherStore _store;
  final DateTime Function() _clock;

  StreamSubscription<List<LiveRun>>? _liveSub;
  StreamSubscription<Together?>? _togetherSub;
  Timer? _timer;
  bool _started = false, _closed = false, _sending = false;

  // 내 상태.
  LiveRun? _mine;
  List<(double, double)> _route = const [];
  int _sentPoints = 0;
  LiveRun? _sent;
  DateTime? _sentAt;

  // 친구들.
  Together? _together;
  Map<String, LiveRun> _runs = const {};
  final Map<String, DateTime> _heardAt = {};

  /// 친구 소식을 받고 올리기를 시작합니다.
  void start() {
    if (_started || _closed) return;
    _started = true;
    _together = _store.byId(togetherId);
    _togetherSub = _store
        .watch(togetherId)
        .listen(_onTogether, onError: (Object _) {});
    _liveSub = _store.backend
        .watchTogetherLive(togetherId)
        .listen(_onLive, onError: (Object _) {});
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
    final me = _store.me;
    if (_closed || me == null) return;
    // 0.5초마다 불리므로 점이 늘 때만 새 목록을 만듭니다.
    if (routePoint != null &&
        (_route.isEmpty ||
            _meters(_route.last, routePoint) >= routeStepMeters)) {
      _route = List.unmodifiable([..._route, routePoint]);
    }
    _mine = LiveRun(
      uid: me.uid,
      distanceKm: meters / 1000,
      movingSeconds: moving.inSeconds,
      paused: paused,
      position: position,
      route: _route,
    );
  }

  Future<void> _publish() async {
    final mine = _mine;
    if (_closed || _sending || mine == null) return;
    final now = _clock();
    final sentAt = _sentAt;
    final changed = !_same(mine, _sent) || mine.route.length > _sentPoints;
    if (!changed && sentAt != null && now.difference(sentAt) < heartbeat) {
      return;
    }
    _sending = true;
    try {
      await _store.backend.setTogetherLive(
        togetherId,
        mine,
        sentPoints: _sentPoints,
      );
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

  void _onTogether(Together? t) {
    if (t == null || _closed) return;
    _together = t;
    notifyListeners();
  }

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

  /// 나를 뺀, 약속을 수락한 친구들.
  List<LiveFriend> get friends {
    final t = _together;
    final me = _store.me?.uid;
    if (t == null || me == null) return const [];
    final now = _clock();
    return [
      for (final uid in t.others(me))
        if (t.statusOf(uid) == TogetherStatus.accepted)
          () {
            final run = _runs[uid], result = t.results[uid];
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
              name: _store.person(uid)?.name ?? '친구',
              state: state,
              run: run,
              result: result,
            );
          }(),
    ];
  }

  /// 달리기를 끝내거나 화면을 닫을 때 부릅니다. 서버의 내 위치·지나간 길을 지웁니다. 여러 번 불러도 됩니다.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    unawaited(_liveSub?.cancel());
    unawaited(_togetherSub?.cancel());
    final me = _store.me;
    if (!_started || me == null) return;
    try {
      await _store.backend.deleteTogetherLive(togetherId, me.uid);
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
