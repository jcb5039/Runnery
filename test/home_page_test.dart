import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/home/home_page.dart';
import 'package:runnery_new/home/running/calorie_quest.dart';
import 'package:runnery_new/profile/setting/profile_setting.dart';
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

  testWidgets(
    'HomeV2 shows first quest stage and empty route without records',
    (tester) async {
      await pumpV2(tester, const []);
      expect(find.text('다음 퀘스트까지'), findsOneWidget);
      expect(find.textContaining('50', findRichText: true), findsOneWidget);
      expect(
        find.textContaining('kcal 남았어요', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('1단계 · 박카스 F 1병'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('아직 러닝 기록이 없어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('HomeV2 quest sums only today and shows latest route', (
    tester,
  ) async {
    await pumpV2(tester, [
      run('a', DateTime(2026, 9, 28, 7), 2, 700, 120),
      run('b', DateTime(2026, 9, 28, 18), 3.24, 1235, 100),
      run('c', DateTime(2026, 9, 27, 18), 9, 3000, 500),
    ]);
    // 오늘 220 kcal: 바나나맛우유(208)까지 달성, 빼빼로(270)까지 50 남음, (220-208)/(270-208)=19%.
    expect(find.textContaining('50', findRichText: true), findsOneWidget);
    expect(find.text('5단계 · 빼빼로 1갑'), findsOneWidget);
    expect(find.text('19%'), findsOneWidget);
    expect(find.text('최근 러닝 경로'), findsOneWidget);
    expect(find.byType(RecordRouteMap), findsOneWidget);
    expect(find.text('아직 러닝 기록이 없어요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeV2 quest follows weekly setting', (tester) async {
    final settings = ProfileSettings(
      directory: () async => Directory.systemTemp,
    )..calorieQuestPeriod = CalorieQuestPeriod.weekly;
    final wednesday = DateTime(2026, 9, 30, 20);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePageV2(
          records: [
            run('a', DateTime(2026, 9, 28, 7), 2, 700, 300),
            run('b', DateTime(2026, 9, 30, 7), 1, 300, 100),
            run('c', DateTime(2026, 9, 27, 18), 9, 3000, 500),
          ],
          settings: settings,
          now: () => wednesday,
        ),
      ),
    );
    await tester.pump();
    // 이번 주(월요일부터) 400 kcal: 햇반(315)까지 달성, 불고기버거(476)까지 76 남음.
    expect(find.textContaining('76', findRichText: true), findsOneWidget);
    expect(find.text('7단계 · 불고기버거 1개'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeV2 shows all stages done', (tester) async {
    await pumpV2(tester, [run('a', DateTime(2026, 9, 28, 7), 20, 7000, 1800)]);
    expect(find.text('오늘 퀘스트를 모두 달성했어요'), findsOneWidget);
    expect(
      find.textContaining('kcal 태웠어요', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('100%'), findsOneWidget);
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
