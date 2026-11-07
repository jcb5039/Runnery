import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/design_system/app_colors.dart';
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

  test('화면 모드: 처음은 라이트, 고른 모드가 저장되고 시스템 설정은 아이폰을 따라요', () async {
    final dir = await Directory.systemTemp.createTemp('runnery_theme_');
    addTearDown(() => dir.delete(recursive: true));
    final first = ProfileSettings(directory: () async => dir);
    await first.load();
    expect(first.themeMode, '라이트');
    expect(first.paletteFor(Brightness.dark), same(AppColors.light));

    first.update(() => first.themeMode = '다크');
    expect(first.paletteFor(Brightness.light), same(AppColors.dark));
    final file = File('${dir.path}/settings.json');
    for (var i = 0; i < 50 && !file.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final reopened = ProfileSettings(directory: () async => dir);
    await reopened.load();
    expect(reopened.themeMode, '다크');

    reopened.themeMode = '시스템 설정';
    expect(reopened.paletteFor(Brightness.dark), same(AppColors.dark));
    expect(reopened.paletteFor(Brightness.light), same(AppColors.light));
  });

  test('라이트 색: 흰 바탕·검정 글자, 흰 바탕 위 주황 글자는 진한 주황', () {
    final before = AppColors.current;
    addTearDown(() => AppColors.current = before);
    AppColors.current = AppColors.light;
    expect(AppColors.background, const Color(0xFFFFFFFF));
    expect(AppColors.textPrimary, const Color(0xFF0B0B0B));
    expect(AppColors.primaryText, const Color(0xFFB94B00));
    expect(AppColors.primary, const Color(0xFFFF7A00));
    AppColors.current = AppColors.dark;
    // 다크는 예전 색 그대로입니다.
    expect(AppColors.background, const Color(0xFF0B0B0B));
    expect(AppColors.textPrimary, const Color(0xFFFFFFFF));
    expect(AppColors.primaryText, const Color(0xFFFF7A00));
  });
}
