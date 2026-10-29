import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/profile/setting/profile_setting.dart';

void main() {
  test('settings survive a restart and map countdown to seconds', () async {
    final dir = await Directory.systemTemp.createTemp('runnery_settings_');
    addTearDown(() => dir.delete(recursive: true));
    final first = ProfileSettings(directory: () async => dir);
    await first.load();
    expect(first.voice, isTrue);
    expect(first.countdownSeconds, 3);
    expect(first.calorieQuest, isTrue);
    first.update(() {
      first.voice = false;
      first.autoPause = false;
      first.calorieQuest = false;
      first.countdown = '없음';
    });
    // 저장은 뒤에서 하므로 파일이 생길 때까지 기다립니다.
    final file = File('${dir.path}/settings.json');
    for (var i = 0; i < 50 && !file.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final reopened = ProfileSettings(directory: () async => dir);
    await reopened.load();
    expect(reopened.voice, isFalse);
    expect(reopened.autoPause, isFalse);
    expect(reopened.calorieQuest, isFalse);
    expect(reopened.countdownSeconds, 0);
  });
}
