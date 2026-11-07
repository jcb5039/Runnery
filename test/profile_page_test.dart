import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/design_system/app_theme.dart';
import 'package:runnery_new/home/home_page.dart';
import 'package:runnery_new/profile/profile_mail_page.dart';
import 'package:runnery_new/profile/setting/profile_setting.dart';

void main() {
  testWidgets('홈에서 프로필과 설정으로 이동하고 설정 상태를 유지한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const HomePageV2(records: []),
      ),
    );
    await tester.tap(find.text('내 정보'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileMailPage), findsOneWidget);
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSettingPage), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, false);
    await tester.tap(find.text('카운트다운'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5초'));
    await tester.pumpAndSettle();
    expect(find.text('5초'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, false);
    expect(find.text('5초'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('작은 화면에서 프로필과 설정을 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const ProfileMailPage()),
    );
    expect(tester.takeException(), null);
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('로그아웃'), 250);
    expect(find.text('로그아웃'), findsOneWidget);
    expect(tester.takeException(), null);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
