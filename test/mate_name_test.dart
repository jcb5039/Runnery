import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/account/account_store.dart';
import 'package:runnery_new/hamster/hamster_room_page.dart';
import 'package:runnery_new/login/auth_ui/auth_ui.dart';
import 'package:runnery_new/record/data/running_record_store.dart';

import 'support/fake_account_backend.dart';

const _minji = RegistrationData(
  name: '김민지',
  email: 'minji@example.com',
  id: 'minji_run',
  password: 'runner123',
  age: 31,
  gender: '여성',
  weight: 58.5,
);

Directory _tempDir() {
  final dir = Directory.systemTemp.createTempSync('runnery_mate_test_');
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // 윈도우에서 아직 열려 있는 임시 폴더는 OS가 나중에 정리합니다.
    }
  });
  return dir;
}

void main() {
  test('처음 이름은 룸메이트이고, 바꾸면 서버와 폰에 저장돼요', () async {
    final dir = _tempDir();
    final server = FakeAccountBackend();
    AccountStore open() => AccountStore(
      directory: () async => dir,
      records: RunningRecordStore(directory: () async => dir),
      backend: server,
    );
    final account = open();
    await account.register(_minji);
    expect(account.current!.mateNameOrDefault, '룸메이트');

    await account.updateMateName('  뛰뛰  ');
    expect(account.current!.mateName, '뛰뛰');
    expect(server.mateNameOf(account.uid!), '뛰뛰');

    // 앱을 다시 켜도 그대로입니다.
    final reopened = open();
    await reopened.load();
    expect(reopened.current!.mateName, '뛰뛰');

    // 인터넷이 없을 때는 폰 복사본의 이름을 씁니다.
    server.offline = true;
    final offline = open();
    await offline.load();
    expect(offline.current!.mateName, '뛰뛰');
    server.offline = false;

    // 프로필을 고쳐도 이름은 그대로입니다.
    await account.updateProfile(
      name: '김민지',
      id: 'minji_run',
      age: 32,
      gender: '여성',
      weightKg: 58,
    );
    expect(account.current!.mateName, '뛰뛰');
  });

  test('빈 이름과 5글자가 넘는 이름은 저장하지 않아요', () async {
    final dir = _tempDir();
    final server = FakeAccountBackend();
    final account = AccountStore(
      directory: () async => dir,
      records: RunningRecordStore(directory: () async => dir),
      backend: server,
    );
    await account.register(_minji);
    await expectLater(
      account.updateMateName('   '),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      account.updateMateName('가나다라마바'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      account.updateMateName('뛰뛰😀'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      account.updateMateName('하트❤️'),
      throwsA(isA<AuthException>()),
    );
    // 서버 저장에 실패하면 이름은 그대로이고, 한 번 바꿀 기회도 남습니다.
    server.failMateName = true;
    await expectLater(
      account.updateMateName('다른이름'),
      throwsA(isA<AuthException>()),
    );
    expect(account.current!.mateName, isNull);
    server.failMateName = false;

    // 숫자와 영어는 쓸 수 있습니다.
    await account.updateMateName('Run12');
    expect(account.current!.mateName, 'Run12');

    // 한 번 바꾸면 더 바꿀 수 없습니다.
    await expectLater(
      account.updateMateName('가나다라마'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          '닉네임은 한 번만 바꿀 수 있어요',
        ),
      ),
    );
    expect(account.current!.mateName, 'Run12');
  });

  testWidgets('연필을 누르면 이름 창이 뜨고, 5글자가 넘으면 더 입력되지 않아요', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = _tempDir();
    late final AccountStore account;
    late final RunningRecordStore records;
    // 저장소의 Future는 가짜 시간 영역 밖(runAsync)에서 만들어야 실제 파일 I/O가 끝납니다.
    await tester.runAsync(() async {
      records = RunningRecordStore(directory: () async => dir);
      account = AccountStore(
        directory: () async => dir,
        records: records,
        backend: FakeAccountBackend(),
      );
      await account.register(_minji);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HamsterRoomPage(records: records, account: account),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('룸메이트'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/hamster/pencil.png')),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('룸메이트 이름 바꾸기'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('닉네임 변경'), findsOneWidget);

    // 5글자가 차면 더 입력되지 않습니다.
    await tester.enterText(find.byType(TextField), '가나다라마바사');
    await tester.pump();
    expect(find.widgetWithText(TextField, '가나다라마'), findsOneWidget);

    // 이모지는 입력되지 않습니다.
    await tester.enterText(find.byType(TextField), '뛰😀뛰🇰🇷👍🏻');
    await tester.pump();
    expect(find.widgetWithText(TextField, '뛰뛰'), findsOneWidget);

    // 빈 이름이면 변경하기 버튼이 꺼집니다.
    await tester.enterText(find.byType(TextField), '  ');
    await tester.pump();
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '변경하기'),
    );
    expect(save.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '뛰뛰');
    await tester.pump();
    await tester.tap(find.text('변경하기'));
    // 저장 뒤 폰 복사본을 파일에 쓰고 나서 화면에 알립니다. 실제 파일 쓰기가 끝날 시간을 주고,
    // 그 뒤에 이어지는 일을 흘려보냅니다.
    for (
      var i = 0;
      i < 20 &&
          find
              .image(const AssetImage('assets/hamster/pencil.png'))
              .evaluate()
              .isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(account.current!.mateName, '뛰뛰');
    expect(find.text('뛰뛰'), findsOneWidget);

    // 한 번 바꾸면 연필 버튼이 사라지고, 이름을 눌러도 창이 뜨지 않습니다.
    expect(
      find.image(const AssetImage('assets/hamster/pencil.png')),
      findsNothing,
    );
    expect(find.bySemanticsLabel('룸메이트 이름 바꾸기'), findsNothing);
    await tester.tap(find.text('뛰뛰'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('닉네임 변경'), findsNothing);
  });
}
