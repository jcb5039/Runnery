import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/account/account_store.dart';
import 'package:runnery_new/main.dart';
import 'package:runnery_new/app_start.dart';
import 'package:runnery_new/design_system/app_motion.dart';
import 'package:runnery_new/login/login.dart';
import 'package:runnery_new/login/sign_up/basic_info.dart';
import 'package:runnery_new/login/sign_up/account.dart';
import 'package:runnery_new/login/sign_up/running_info.dart';

import 'support/fake_account_backend.dart';

void main() {
  testWidgets('Startup opens login and replaces the splash route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // 계정 파일 읽기는 실제 비동기 I/O라서 runAsync에서 먼저 끝냅니다.
    final dir = Directory.systemTemp.createTempSync('runnery_start_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    AccountStore.instance = AccountStore(
      directory: () async => dir,
      backend: FakeAccountBackend(),
    );
    await tester.runAsync(AccountStore.instance.load);
    await tester.pumpWidget(const MyApp());
    expect(find.byType(AppStartPage), findsOneWidget);
    await tester.pump(AppMotion.splashDelay);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPageV2), findsOneWidget);
    expect(find.byType(AppStartPage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    expect(find.byType(BasicInfoPage), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '김민지');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'minji@example.com',
    );
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountPage), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'minji_run');
    await tester.enterText(find.byType(TextFormField).at(1), 'runner123');
    await tester.enterText(find.byType(TextFormField).at(2), 'runner123');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.byType(RunningInfoPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Disposing splash cancels delayed navigation', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(AppMotion.splashDelay);
    expect(tester.takeException(), isNull);
  });
}
