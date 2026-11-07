import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/home/home_page.dart';
import 'package:runnery_new/record/list/detail/record_detail_page.dart';
import 'package:runnery_new/account/account_store.dart';
import 'package:runnery_new/login/auth_ui/auth_ui.dart';
import 'package:runnery_new/login/login.dart';
import 'package:runnery_new/record/data/running_record_store.dart';

import 'support/fake_account_backend.dart';

void main() {
  final now = DateTime(2026, 9, 28, 20);
  Future<void> pumpV2(
    WidgetTester tester,
    List<RunningRecord> records, {
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePageV2(records: records, now: () => now),
      ),
    );
    await tester.pump();
  }

  RunningRecord run(String id, DateTime at, double km, int sec, int kcal) =>
      RunningRecord(
        id: id,
        startedAt: at,
        distanceKm: km,
        movingSeconds: sec,
        calories: kcal,
        route: [
          RecordCoordinate(37.0, 127.0),
          RecordCoordinate(37.001, 127.002),
        ],
      );

  testWidgets('HomeV2 shows zeros and empty route without records', (
    tester,
  ) async {
    await pumpV2(tester, const []);
    expect(find.textContaining('0.00 km', findRichText: true), findsOneWidget);
    expect(find.textContaining('0분 00초', findRichText: true), findsOneWidget);
    expect(find.textContaining('0 kcal', findRichText: true), findsOneWidget);
    expect(find.text('아직 러닝 기록이 없어요'), findsOneWidget);
    expect(find.text('9월 28일 월요일'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeV2 sums only today and shows latest route', (tester) async {
    await pumpV2(tester, [
      run('a', DateTime(2026, 9, 28, 7), 2, 700, 120),
      run('b', DateTime(2026, 9, 28, 18), 3.24, 1235, 195),
      run('c', DateTime(2026, 9, 27, 18), 9, 3000, 500),
    ]);
    expect(find.textContaining('5.24 km', findRichText: true), findsOneWidget);
    expect(find.textContaining('32분 15초', findRichText: true), findsOneWidget);
    expect(find.textContaining('315 kcal', findRichText: true), findsOneWidget);
    expect(find.byType(RecordRouteMap), findsOneWidget);
    expect(find.text('아직 러닝 기록이 없어요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('Home fits width $width with enlarged text', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var started = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 844),
              textScaler: TextScaler.linear(1.3),
            ),
            child: HomePageV2(
              records: const [],
              onStartRun: () => started = true,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('러닝 시작'));
      await tester.tap(find.text('러닝 시작'));
      expect(started, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  Future<AccountStore> openStore(
    WidgetTester tester, {
    bool withAccount = false,
  }) async {
    final dir = Directory.systemTemp.createTempSync('runnery_login_test_');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // 윈도우에서 아직 열려 있는 임시 폴더는 OS가 나중에 정리합니다.
      }
    });
    // 저장소의 Future는 가짜 시간 영역 밖(runAsync)에서 만들어야 실제 파일 I/O가 끝납니다.
    return (await tester.runAsync(() async {
      final store = AccountStore(
        directory: () async => dir,
        records: RunningRecordStore(directory: () async => dir),
        backend: FakeAccountBackend(),
      );
      if (withAccount) {
        await store.register(
          const RegistrationData(
            name: '김민지',
            email: 'minji@example.com',
            id: 'minji_run',
            password: 'runner123',
            age: 26,
            gender: '여성',
            weight: 58,
          ),
        );
        await store.logout();
      }
      return store;
    }))!;
  }

  Future<void> submitLogin(
    WidgetTester tester,
    String email,
    String password,
    Finder until,
  ) async {
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.ensureVisible(find.text('로그인'));
    await tester.tap(find.text('로그인'));
    // 계정 파일 읽기·쓰기는 실제 I/O라서 실제 시간을 흘려보내며 화면을 갱신합니다.
    for (var i = 0; i < 40 && until.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  testWidgets('Successful login replaces login with home', (tester) async {
    final store = await openStore(tester, withAccount: true);
    await tester.pumpWidget(MaterialApp(home: LoginPageV2(store: store)));
    await submitLogin(
      tester,
      'minji@example.com',
      'runner123',
      find.byType(HomePageV2),
    );
    // 화면 전환 애니메이션이 끝나면 로그인 화면이 사라집니다.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HomePageV2), findsOneWidget);
    expect(find.byType(LoginPageV2), findsNothing);
    expect(store.isLoggedIn, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Wrong password stays on login', (tester) async {
    final store = await openStore(tester, withAccount: true);
    await tester.pumpWidget(MaterialApp(home: LoginPageV2(store: store)));
    await submitLogin(
      tester,
      'minji@example.com',
      'wrong-password',
      find.text('이메일 또는 비밀번호가 맞지 않아요'),
    );
    expect(find.text('이메일 또는 비밀번호가 맞지 않아요'), findsOneWidget);
    expect(find.byType(HomePageV2), findsNothing);
    expect(find.byType(LoginPageV2), findsOneWidget);
    expect(store.isLoggedIn, isFalse);
  });
}
