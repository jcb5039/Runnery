import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/account/account_store.dart';
import 'package:runnery_new/login/auth_ui/auth_ui.dart';
import 'package:runnery_new/login/sign_up/account.dart';
import 'package:runnery_new/login/sign_up/basic_info.dart';
import 'package:runnery_new/login/sign_up/sign_up_choice.dart';
import 'package:runnery_new/record/data/running_record_store.dart';

import 'support/fake_account_backend.dart';

void main() {
  late Directory directory;
  late FakeAccountBackend backend;
  AccountStore open() => AccountStore(
    directory: () async => directory,
    records: RunningRecordStore(directory: () async => directory),
    backend: backend,
  );

  const profile = RegistrationData(
    name: '김민지',
    email: '',
    id: 'minji_kakao',
    password: '',
    age: 26,
    gender: '여성',
    weight: 58.5,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('runnery_kakao_test_');
    backend = FakeAccountBackend();
  });
  tearDown(() => directory.delete(recursive: true));

  test('카카오 처음 로그인: 가입 단계를 마쳐야 로그인되고, 이메일 인증은 없어요', () async {
    final store = open();
    expect(await store.loginWithKakao(), SocialLoginResult.needsProfile);
    expect(store.isLoggedIn, isFalse);
    expect(store.needsVerification, isFalse);
    expect(store.isSocial, isTrue);

    await store.completeSocialProfile(profile);
    expect(store.isLoggedIn, isTrue);
    expect(store.current?.name, '김민지');
    expect(store.current?.email, '');
    expect(backend.verificationsSent, 0);

    // 앱을 다시 켜도 로그인이 이어져요.
    final reopened = open();
    await reopened.load();
    expect(reopened.isLoggedIn, isTrue);
    expect(reopened.current?.id, 'minji_kakao');
  });

  test('카카오 다시 로그인: 이미 가입했으면 바로 로그인돼요', () async {
    final first = open();
    await first.loginWithKakao();
    await first.completeSocialProfile(profile);
    await first.logout();
    expect(first.isLoggedIn, isFalse);

    final again = open();
    expect(await again.loginWithKakao(), SocialLoginResult.loggedIn);
    expect(again.isLoggedIn, isTrue);
    expect(again.current?.name, '김민지');
  });

  test('카카오 로그인 창을 닫거나 가입 단계를 그만두면 로그인되지 않아요', () async {
    final store = open();
    backend.kakaoId = null;
    expect(await store.loginWithKakao(), SocialLoginResult.cancelled);
    expect(store.isLoggedIn, isFalse);

    backend.kakaoId = '2002';
    expect(await store.loginWithKakao(), SocialLoginResult.needsProfile);
    await store.cancelSocialSignUp();
    expect(store.isSocial, isFalse);
    expect(await backend.restore(), isNull);
  });

  testWidgets('카카오로 시작하기: 이메일·비밀번호 없이 이름과 아이디만 받아요', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await tester.runAsync(() async => open());
    await tester.pumpWidget(MaterialApp(home: SignUpChoicePage(store: store)));
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.byType(BasicInfoPage), findsOneWidget);
    expect(find.text('러너리에서 사용할 이름을 알려주세요'), findsOneWidget);
    expect(find.text('EMAIL'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), '김민지');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountPage), findsOneWidget);
    expect(find.text('앱에서 쓸 아이디를 만들어주세요'), findsOneWidget);
    expect(find.text('PASSWORD'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);

    // 가입 단계에서 뒤로 나가면 로그인을 풀어요.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpChoicePage), findsOneWidget);
    expect(store!.isSocial, isFalse);
  });

  test('구글 처음 로그인: 가입 단계를 마치면 로그인되고, 구글 이메일을 저장해요', () async {
    final store = open();
    expect(await store.loginWithGoogle(), SocialLoginResult.needsProfile);
    expect(store.isLoggedIn, isFalse);
    expect(store.isSocial, isTrue);

    await store.completeSocialProfile(profile);
    expect(store.isLoggedIn, isTrue);
    expect(store.current?.email, 'minji@gmail.com');
    expect(backend.verificationsSent, 0);

    await store.logout();
    expect(await open().loginWithGoogle(), SocialLoginResult.loggedIn);
  });

  test('구글 로그인 창을 닫으면 아무 일도 없어요', () async {
    backend.googleEmail = null;
    final store = open();
    expect(await store.loginWithGoogle(), SocialLoginResult.cancelled);
    expect(store.isLoggedIn, isFalse);
  });

  testWidgets('Google로 시작하기: 처음이면 이메일 없이 이름부터 받아요', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await tester.runAsync(() async => open());
    await tester.pumpWidget(MaterialApp(home: SignUpChoicePage(store: store)));
    await tester.tap(find.text('Google로 시작하기'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(BasicInfoPage), findsOneWidget);
    expect(find.text('EMAIL'), findsNothing);
  });
}
