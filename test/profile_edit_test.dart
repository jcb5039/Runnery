import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/account/account_store.dart';
import 'package:runnery_new/login/auth_ui/auth_ui.dart';
import 'package:runnery_new/profile/edit/profile_edit_page.dart';
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
    weight: 60,
  );

  late Directory directory;
  late FakeAccountBackend backend;
  AccountStore open() => AccountStore(
    directory: () async => directory,
    records: RunningRecordStore(directory: () async => directory),
    backend: backend,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('runnery_profile_test_');
    backend = FakeAccountBackend();
  });
  tearDown(() => directory.delete(recursive: true));

  test('updateProfile saves new info and photo on the device', () async {
    final store = open();
    await store.register(registration);
    final picked = File('${directory.path}/picked.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    await store.updateProfile(
      name: '김민지',
      id: 'minji_runs',
      age: 27,
      gender: '여성',
      weightKg: 58.5,
      newPhoto: picked,
    );
    final first = store.photoFile!;
    expect(first.readAsBytesSync(), [1, 2, 3]);

    final reopened = open();
    await reopened.load();
    expect(reopened.current?.id, 'minji_runs');
    expect(reopened.current?.weightKg, 58.5);
    expect(reopened.photoFile?.path, first.path);
    await reopened.logout();
    await reopened.login('minji@example.com', 'runner123');
    // 서버에는 바뀐 아이디가 저장돼 있고, 옛 아이디는 다시 쓸 수 있습니다.
    expect(reopened.current?.id, 'minji_runs');
    expect(await reopened.isIdAvailable('minji_run'), isTrue);
    expect(await reopened.isIdAvailable('minji_runs'), isFalse);

    // 사진을 지우면 계정에서 빠지고 이전 파일도 정리됩니다.
    await reopened.updateProfile(
      name: '김민지',
      id: 'minji_runs',
      age: 27,
      gender: '여성',
      weightKg: 58.5,
      removePhoto: true,
    );
    expect(reopened.photoFile, isNull);
    expect(first.existsSync(), isFalse);
  });

  test('a taken id is refused and the new photo is not kept', () async {
    final other = open();
    await other.register(registration);
    await other.logout();
    final store = open();
    await store.register(
      const RegistrationData(
        name: '박서준',
        email: 'seojun@example.com',
        id: 'seojun_run',
        password: 'runner123',
        age: 30,
        gender: '남성',
        weight: 70,
      ),
    );
    final picked = File('${directory.path}/picked.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    await expectLater(
      store.updateProfile(
        name: '박서준',
        id: 'minji_run',
        age: 30,
        gender: '남성',
        weightKg: 70,
        newPhoto: picked,
      ),
      throwsA(isA<AuthException>()),
    );
    expect(store.current?.id, 'seojun_run');
    expect(store.photoFile, isNull);
    final copies = directory
        .listSync()
        .where((e) => e.uri.pathSegments.last.startsWith('profile_'))
        .toList();
    expect(copies, isEmpty);
  });

  Future<AccountStore> pumpEdit(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = (await tester.runAsync(() async {
      final store = open();
      await store.register(registration);
      return store;
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => ProfileEditPage(store: store)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return store;
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, '저장'));

  testWidgets('save turns on only for valid changes', (tester) async {
    await pumpEdit(tester);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'minji_run'),
      'minji_runs',
    );
    await tester.pump();
    expect(find.text('사용할 수 있는 형식이에요'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);

    // 저장을 누르면 바로 저장하지 않고 바뀐 내용을 확인하는 창을 띄웁니다.
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(find.text('바뀐 내용을 저장할까요?'), findsOneWidget);
    await tester.tap(find.text('계속 수정하기'));
    await tester.pumpAndSettle();
    expect(find.text('바뀐 내용을 저장할까요?'), findsNothing);

    // 규칙에 맞지 않는 아이디는 저장할 수 없습니다.
    await tester.enterText(find.widgetWithText(TextField, 'minji_runs'), 'Ab');
    await tester.pump();
    expect(find.text('영문 소문자, 숫자, _ 로 4~16자를 입력해 주세요'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('the email is shown but cannot be edited', (tester) async {
    await pumpEdit(tester);
    final email = tester.widget<TextField>(
      find.widgetWithText(TextField, 'minji@example.com'),
    );
    expect(email.enabled, isFalse);
    expect(find.text('로그인에 쓰는 이메일은 바꿀 수 없어요'), findsOneWidget);
  });

  testWidgets('leaving with changes asks, and save-and-leave stores them', (
    tester,
  ) async {
    final store = await pumpEdit(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'minji_run'),
      'minji_runs',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('바뀐 내용을 저장할까요?'), findsOneWidget);
    expect(find.text('@minji_runs'), findsOneWidget);

    await tester.tap(find.text('저장하고 나가기'));
    // 파일 저장은 실제 I/O라서 가짜 시간 밖에서 끝날 때까지 기다립니다.
    for (
      var i = 0;
      i < 20 && find.byType(ProfileEditPage).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditPage), findsNothing);
    expect(store.current?.id, 'minji_runs');
  });
}
