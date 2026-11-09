import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 앱 밖(다이내믹 아일랜드·잠금 화면)에 러닝 진행 상황을 띄웁니다. iOS 16.2 이상에서만 동작합니다.
/// 시간은 iOS가 저절로 흐르게 하므로, 거리·페이스·일시정지가 바뀔 때만 보냅니다.
class RunningLiveActivity {
  RunningLiveActivity({this.onControl});

  static const _channel = MethodChannel('runnery/live_activity');

  /// 잠금 화면·다이내믹 아일랜드 버튼을 눌렀을 때: 'pause' 또는 'resume'.
  final void Function(String action)? onControl;

  bool _active = false;
  Map<String, Object?>? _last;

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> start(Map<String, Object?> state) async {
    if (!_supported) return;
    _last = state;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'control' && call.arguments is String) {
        onControl?.call(call.arguments as String);
      }
    });
    try {
      _active = await _channel.invokeMethod<bool>('start', state) ?? false;
    } catch (_) {
      // 기기가 지원하지 않거나 사용자가 꺼 두면 앱 안 기록에는 영향이 없습니다.
      _active = false;
    }
  }

  /// [state]의 elapsedSeconds는 시간 기준점용이라, 그것만 바뀐 경우는 보내지 않습니다.
  void update(Map<String, Object?> state) {
    if (!_active || mapEquals(_withoutTime(_last), _withoutTime(state))) return;
    _last = state;
    _channel.invokeMethod<void>('update', state).catchError((_) {});
  }

  static Map<String, Object?>? _withoutTime(Map<String, Object?>? state) =>
      state == null ? null : ({...state}..remove('elapsedSeconds'));

  Future<void> end() async {
    if (!_supported) return;
    _active = false;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod<void>('end');
    } catch (_) {}
  }
}
