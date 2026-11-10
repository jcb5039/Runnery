import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/record/data/route_thumbnails.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 예전에는 다 만든 뒤 정리 단계가 자기 자신을 기다려, 사진이 있어도 화면에 넘어가지 않았습니다.
  test('map photo for an unsaved run is handed over once made', () async {
    final tmp = Directory.systemTemp.createTempSync();
    addTearDown(() => tmp.deleteSync(recursive: true));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger
      ..setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => tmp.path,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('runnery/route_snapshot'),
        (call) async {
          File((call.arguments as Map)['output'] as String)
              .writeAsBytesSync([1]);
          return true;
        },
      );
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final photo = await RouteThumbnails()
          .forSession('run_3', [
            [(37.5, 127.0), (37.501, 127.0), (37.502, 127.0)],
          ])
          .timeout(const Duration(seconds: 5));
      expect(photo, isNotNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
