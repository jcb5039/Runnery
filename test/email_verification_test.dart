import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/account/account_store.dart';
import 'package:runnery_new/home/home_page.dart';
import 'package:runnery_new/login/auth_ui/auth_ui.dart';
import 'package:runnery_new/login/login.dart';
import 'package:runnery_new/login/sign_up/account.dart';
import 'package:runnery_new/login/sign_up/verify_email.dart';
import 'package:runnery_new/profile/setting/change_password_page.dart';
import 'package:runnery_new/record/data/running_record_store.dart';

import 'support/fake_account_backend.dart';

void main() {
  const registration = RegistrationData(
    name: '김민지',
    email: 'minji@example.com',
    id: 'minji_run',
    password: 'runner123',
    age: 26,
    gender: '여성',
    weight: 58,
  );

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// 가입을 마친 저장소. [loggedOut]이면 로그아웃까지 해 둡니다.
  Future<AccountStore> prepare(
    WidgetTester tester,
    FakeAccountBackend backend, {
    bool loggedOut = false,
  }) async {
    final dir = Directory.systemTemp.createTempSync('runnery_verify_test_');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // 윈도우에서 아직 열려 있는 임시 폴더는 OS가 나중에 정리합니다.
      }
    });
    return (await tester.runAsync(() async {
      final store = AccountStore(
        directory: () async => dir,
        records: RunningRecordStore(directory: () async => dir),
        backend: backend,
      );
      await store.register(registration);
      if (loggedOut) await store.logout();
      return store;
    }))!;
  }

  /// 떠 있는 안내 문구를 치웁니다(다음 안내 문구가 대기하지 않도록).
  Future<void> clearSnackBars(WidgetTester tester) async {
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .clearSnackBars();
    await tester.pumpAndSettle();
  }

  /// 파일 읽기·쓰기는 실제 I/O라서 실제 시간을 흘려보내며 [until]이 나타날 때까지 갱신합니다.
  Future<void> waitFor(WidgetTester tester, Finder until) async {
    for (var i = 0; i < 40 && until.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  testWidgets('unverified login opens verification, then home once verified', (
    tester,
  ) async {
    phoneSize(tester);
    final backend = FakeAccountBackend(autoVerify: false);
    final store = await prepare(tester, backend, loggedOut: true);
    await tester.pumpWidget(MaterialApp(home: LoginPageV2(store: store)));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'minji@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'runner123');
    await tester.ensureVisible(find.text('로그인'));
    await tester.tap(find.text('로그인'));
    await waitFor(tester, find.byType(VerifyEmailPage));
    // 화면 전환이 끝나도록 1초만 흘립니다(pumpAndSettle은 대기 시간 타이머를 끝까지 돌려 버립니다).
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(VerifyEmailPage), findsOneWidget);
    expect(find.text('minji@example.com'), findsOneWidget);
    // 인증 전 계정으로 로그인하면 새 인증 메일을 한 번 더 보내고(가입 때 1번 + 로그인 때 1번), 바로 다시 보내지는 못합니다.
    expect(backend.verificationsSent, 2);
    expect(find.textContaining('메일 다시 보내기 ('), findsOneWidget);

    // 링크를 누르기 전에는 홈으로 가지 않습니다.
    await tester.tap(find.text('인증했어요'));
    await tester.pump();
    await tester.pump();
    expect(find.text('아직 인증되지 않았어요. 메일의 링크를 눌러주세요'), findsOneWidget);
    expect(find.byType(HomePageV2), findsNothing);
    await clearSnackBars(tester);

    backend.verify('minji@example.com');
    await tester.tap(find.text('인증했어요'));
    await waitFor(tester, find.byType(HomePageV2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HomePageV2), findsOneWidget);
    expect(find.byType(VerifyEmailPage), findsNothing);
    expect(store.isLoggedIn, isTrue);
  });

  testWidgets('right after sign-up the resend button is locked for a while', (
    tester,
  ) async {
    phoneSize(tester);
    final backend = FakeAccountBackend(autoVerify: false);
    final store = await prepare(tester, backend);
    expect(backend.verificationsSent, 1);
    await tester.pumpWidget(MaterialApp(home: VerifyEmailPage(store: store)));
    expect(find.textContaining('메일 다시 보내기 ('), findsOneWidget);
    expect(find.textContaining('인증 메일을 보내지 못했어요'), findsNothing);
    // 가입 때 이미 보냈으므로, 눌러도 두 번째 메일을 보내지 않습니다.
    await tester.tap(find.textContaining('메일 다시 보내기 ('));
    await tester.pump();
    expect(backend.verificationsSent, 1);
    // 대기 시간 타이머가 남지 않게 화면을 닫습니다.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed first mail is shown and can be sent again', (
    tester,
  ) async {
    phoneSize(tester);
    final backend = FakeAccountBackend(autoVerify: false)
      ..failSendVerification = true;
    final store = await prepare(tester, backend);
    expect(backend.verificationsSent, 0);
    expect(store.verificationSentAt, isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VerifyEmailPage(store: store)),
      ),
    );
    // 실패를 숨기지 않고 이유를 보여 주며, 바로 다시 보낼 수 있습니다.
    expect(find.textContaining('인증 메일을 보내지 못했어요: 인증 메일을 너무 자주'), findsOneWidget);

    await tester.tap(find.text('메일 다시 보내기'));
    await tester.pump();
    await tester.pump();
    expect(backend.verificationsSent, 0);
    expect(find.textContaining('인증 메일을 보내지 못했어요: 인증 메일을 너무 자주'), findsOneWidget);
    await clearSnackBars(tester);

    backend.failSendVerification = false;
    await tester.tap(find.text('메일 다시 보내기'));
    await tester.pump();
    await tester.pump();
    expect(backend.verificationsSent, 1);
    expect(find.textContaining('인증 메일을 보내지 못했어요'), findsNothing);
    expect(find.textContaining('메일 다시 보내기 ('), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('forgot password sends a reset mail to the typed email', (
    tester,
  ) async {
    phoneSize(tester);
    final backend = FakeAccountBackend();
    final store = await prepare(tester, backend, loggedOut: true);
    await tester.pumpWidget(MaterialApp(home: LoginPageV2(store: store)));
    await tester.ensureVisible(find.text('비밀번호 찾기'));
    await tester.tap(find.text('비밀번호 찾기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'minji@example.com',
    );
    await tester.tap(find.text('메일 보내기'));
    await tester.pumpAndSettle();
    expect(backend.resetsSent, ['minji@example.com']);
    expect(find.textContaining('재설정 메일을 보냈어요'), findsOneWidget);
  });

  testWidgets('sign-up asks the server whether the id is free', (tester) async {
    phoneSize(tester);
    final store = await prepare(tester, FakeAccountBackend(), loggedOut: true);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountPage(name: '박서준', email: 'seojun@example.com', store: store),
      ),
    );
    Future<void> fill(String id) async {
      await tester.enterText(find.byType(TextFormField).at(0), id);
      await tester.enterText(find.byType(TextFormField).at(1), 'runner123');
      await tester.enterText(find.byType(TextFormField).at(2), 'runner123');
      await tester.pump();
    }

    await fill('Ab');
    expect(find.text('영문 소문자, 숫자, _ 로 4~16자를 입력해주세요'), findsOneWidget);

    await fill('minji_run');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('이미 사용 중인 아이디예요'), findsOneWidget);
  });

  testWidgets('changing the password asks for the current one', (tester) async {
    phoneSize(tester);
    final store = await prepare(tester, FakeAccountBackend());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => ChangePasswordPage(store: store),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    Future<void> submit(String current) async {
      await tester.enterText(find.byType(TextFormField).at(0), current);
      await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
      await tester.enterText(find.byType(TextFormField).at(2), 'newpass123');
      await tester.tap(find.text('변경하기'));
      await tester.pump();
      await tester.pump();
    }

    await submit('wrong-password');
    expect(find.text('현재 비밀번호가 맞지 않아요'), findsOneWidget);
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    await clearSnackBars(tester);

    await submit('runner123');
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordPage), findsNothing);
    expect(find.text('비밀번호를 바꿨어요'), findsOneWidget);
  });
}
