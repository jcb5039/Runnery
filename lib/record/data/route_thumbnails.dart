import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../design_system/app_colors.dart';
import '../../home/running/running_home_page.dart' show runneryThumbnailStyle;
import '../models/running_record.dart';
import 'route_smoothing.dart';
import 'running_record_store.dart';

/// 기록 목록 썸네일 지도 사진. 기록마다 한 번 iOS 지도 엔진으로 사진을 만들어 저장하고 다시 씁니다.
/// 실제 지도를 화면에 띄우지 않으므로 기록이 많아도 지도 잔상이 생기지 않습니다.
class RouteThumbnails {
  RouteThumbnails({RunningRecordStore? store})
    : _store = store ?? RunningRecordStore.instance;

  static final instance = RouteThumbnails();
  static const _channel = MethodChannel('runnery/route_snapshot');

  /// 썸네일 칸 크기(pt). 화면 배율은 iOS가 맞춥니다.
  static const size = 88.0;

  final RunningRecordStore _store;

  /// 지도 사진은 한 장씩 만듭니다. 여러 장을 한꺼번에 만들면 지도 엔진이 무거워집니다.
  Future<void> _queue = Future.value();

  /// 지도 사진을 만들지 못한 기록과 그 시각(인터넷 없음 등). 잠시 뒤 목록을 다시 열면 다시 시도합니다.
  final _failedAt = <String, DateTime>{};
  static const _retryAfter = Duration(seconds: 30);
  final _making = <String, Future<File?>>{};

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// 저장된 사진이 있으면 바로, 없으면 만들어서 돌려줍니다. 만들 수 없으면 null.
  Future<File?> get(RunningRecord record) async {
    // 위치가 하나라도 있으면 그 주변 지도를 보여 줍니다(위치가 없는 기록은 경로 그림 칸).
    if (!_supported || record.route.isEmpty) return null;
    final file = await _store.thumbnailFile(
      record.id,
      light: !AppColors.isDark,
    );
    if (await file.exists()) return file;
    final failedAt = _failedAt[record.id];
    if (failedAt != null && DateTime.now().difference(failedAt) < _retryAfter) {
      return null;
    }
    // 다크·라이트 사진은 따로 만듭니다.
    final key = '${record.id}:${file.path}';
    // 일시정지로 끊긴 구간마다 따로 다듬습니다.
    final segments = <List<(double, double)>>[];
    for (final (i, p) in record.route.indexed) {
      if (i == 0 || p.startsSegment) segments.add([]);
      segments.last.add((p.latitude, p.longitude));
    }
    return _making[key] ??= _make(record.id, file, [
      for (final segment in segments)
        for (final (i, (lat, lng)) in smoothRoute(segment).indexed)
          (lat, lng, i == 0),
    ]).whenComplete(() => _making.remove(key));
  }

  /// 친구 피드 카드의 지도 사진. 폰의 임시 폴더에 두므로 저장 공간이 부족하면 iOS가 지울 수 있고,
  /// 그때는 다시 만듭니다. [key]는 기록마다 다른 이름(친구 uid와 기록 번호)입니다.
  Future<File?> forRoute(String key, List<(double, double)> route) async {
    if (!_supported || route.length < 2) return null;
    final folder = await Directory(
      '${(await getTemporaryDirectory()).path}/friend_maps',
    ).create(recursive: true);
    final file = File(
      '${folder.path}/$key.map${AppColors.isDark ? '' : '.light'}.png',
    );
    if (await file.exists()) return file;
    final failedAt = _failedAt[key];
    if (failedAt != null && DateTime.now().difference(failedAt) < _retryAfter) {
      return null;
    }
    return _making[file.path] ??= _make(key, file, [
      for (final (i, (lat, lng)) in smoothRoute(route).indexed)
        (lat, lng, i == 0),
    ]).whenComplete(() => _making.remove(file.path));
  }

  /// [points]는 (위도, 경도, 새 구간 시작 여부)입니다.
  Future<File?> _make(
    String id,
    File file,
    List<(double, double, bool)> points,
  ) {
    final made = _queue.then((_) async {
      try {
        final ok = await _channel.invokeMethod<bool>('snapshot', {
          'style': runneryThumbnailStyle(),
          'light': !AppColors.isDark,
          'lat': [for (final p in points) p.$1],
          'lng': [for (final p in points) p.$2],
          'starts': [for (final p in points) p.$3],
          'size': size,
          'output': file.path,
        });
        if (ok == true && await file.exists()) return file;
      } catch (_) {
        // 지도 엔진 오류는 경로 그림으로 대신 보여 줍니다.
      }
      _failedAt[id] = DateTime.now();
      return null;
    });
    _queue = made.then<void>((_) {});
    return made;
  }
}
