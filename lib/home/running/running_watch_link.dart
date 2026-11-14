import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 애플워치에 러닝 상태를 보내고, 워치 버튼(일시정지·다시 시작·종료·음성 안내)을 받습니다.
/// iOS에서만 동작하고, 워치가 없거나 워치 앱이 없으면 조용히 아무것도 하지 않습니다.
class RunningWatchLink {
  RunningWatchLink({
    this.onControl,
    @visibleForTesting MethodChannel? channel,
    @visibleForTesting DateTime Function()? now,
    @visibleForTesting bool? supported,
  }) : _channel = channel ?? const MethodChannel('runnery/watch'),
       _now = now ?? DateTime.now,
       _supported =
           supported ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  /// 'pause', 'resume', 'end', 'voice'.
  final void Function(String action)? onControl;
  final MethodChannel _channel;
  final DateTime Function() _now;
  final bool _supported;

  /// '지금 페이스'를 잴 때 돌아보는 운동 시간.
  static const paceWindow = Duration(seconds: 30);

  /// 지금 페이스를 내기 위한 최소 거리(m). 이보다 적게 움직였으면 페이스를 비워 둡니다.
  static const paceMinMeters = 20.0;

  /// 한 번에 보내는 경로 점 수. 워치 메시지 크기 한도(약 65KB) 안에 들어가게 합니다.
  static const maxRoutePerMessage = 400;

  /// 1km마다 걸린 시간(초).
  final List<int> splits = [];
  Duration _lastSplitAt = Duration.zero;

  /// (운동 시간, 거리) 최근 기록. 지금 페이스 계산용.
  final List<(Duration, double)> _samples = [];

  /// 워치가 이미 받은 경로 점 수.
  int _routeSent = 0;
  bool _sending = false;
  DateTime? _lastSentAt;

  void start() {
    if (!_supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'control' && call.arguments is String) {
        onControl?.call(call.arguments as String);
      }
    });
    // 워치 앱을 깨워 손목에 바로 러닝 화면이 뜨게 해요.
    _channel.invokeMethod<void>('launch').catchError((_) {});
  }

  /// 러닝 화면이 바뀔 때마다 부릅니다. 보내기는 1초에 한 번만 합니다([force]면 바로).
  void update({
    required bool paused,
    required bool autoPaused,
    required bool ending,
    required Duration elapsed,
    required double meters,
    required double? averagePace,
    required bool voice,
    required int routeCount,
    required List<(double, double)> Function(int from, int count) routeSlice,
    bool force = false,
  }) {
    _record(elapsed, meters);
    if (!_supported || _sending) return;
    final now = _now();
    if (!force &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastSentAt = now;
    final from = _routeSent > routeCount ? 0 : _routeSent;
    final count = (routeCount - from).clamp(0, maxRoutePerMessage);
    final message = buildMessage(
      paused: paused,
      autoPaused: autoPaused,
      ending: ending,
      elapsed: elapsed,
      meters: meters,
      averagePace: averagePace,
      voice: voice,
      routeFrom: from,
      route: routeSlice(from, count),
      now: now,
    );
    _sending = true;
    _channel
        .invokeMethod<int>('send', message)
        .then((received) => _routeSent = received ?? 0)
        .catchError((_) => _routeSent = 0)
        .whenComplete(() {
          _sending = false;
        });
  }

  /// 1km 구간과 지금 페이스용 기록을 쌓습니다.
  void _record(Duration elapsed, double meters) {
    while (meters >= (splits.length + 1) * 1000) {
      splits.add((elapsed - _lastSplitAt).inSeconds);
      _lastSplitAt = elapsed;
    }
    if (_samples.isEmpty || _samples.last.$1 != elapsed) {
      _samples.add((elapsed, meters));
    }
    // 창보다 오래된 기록은 하나만 남기고 버립니다(창 시작점 기준으로 씀).
    while (_samples.length > 2 && elapsed - _samples[1].$1 >= paceWindow) {
      _samples.removeAt(0);
    }
  }

  /// 최근 [paceWindow] 동안의 페이스(초/km). 거의 안 움직였으면 null.
  double? get currentPace {
    if (_samples.length < 2) return null;
    final first = _samples.first, last = _samples.last;
    final meters = last.$2 - first.$2;
    final seconds = (last.$1 - first.$1).inMilliseconds / 1000;
    if (meters < paceMinMeters || seconds <= 0) return null;
    return seconds / (meters / 1000);
  }

  @visibleForTesting
  Map<String, Object?> buildMessage({
    required bool paused,
    required bool autoPaused,
    required bool ending,
    required Duration elapsed,
    required double meters,
    required double? averagePace,
    required bool voice,
    required int routeFrom,
    required List<(double, double)> route,
    required DateTime now,
  }) {
    final pace = currentPace;
    return {
      'state': paused ? 'paused' : 'running',
      'autoPaused': autoPaused,
      'ending': ending,
      'elapsed': elapsed.inMilliseconds / 1000,
      'sentAt': now.millisecondsSinceEpoch / 1000,
      'distance': meters,
      'pace': pace ?? -1,
      'avgPace': averagePace ?? -1,
      'speed': pace == null ? 0 : 3600 / pace,
      'splits': List<int>.of(splits),
      'voice': voice,
      'routeFrom': routeFrom,
      'route': [for (final p in route) ...[p.$1, p.$2]],
    };
  }

  /// 러닝이 끝나면 워치를 기본 화면으로 돌립니다.
  Future<void> end() async {
    if (!_supported) return;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod<int>('send', {'state': 'ended'});
    } catch (_) {}
  }
}
