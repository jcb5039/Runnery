import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/account/account_store.dart';
import 'package:runnery_new/design_system/app_theme.dart';
import 'package:runnery_new/login/auth_ui/auth_ui.dart';
import 'package:runnery_new/login/login.dart';
import 'package:runnery_new/profile/setting/delete_account_page.dart';
import 'package:runnery_new/record/data/running_record_store.dart';
import 'package:runnery_new/record/models/running_record.dart';

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

RunningRecord _run(String id) => RunningRecord(
  id: id,
  startedAt: DateTime(2026, 11, 20),
  distanceKm: 3,
  movingSeconds: 1200,
  calories: 200,
  route: const [
    RecordCoordinate(37.0, 127.0),
    RecordCoordinate(37.001, 127.001),
  ],
);

/// 임시 폴더에 계정·기록 저장소를 만들고, 이메일 계정으로 가입해 기록 하나와 프로필 사진을 둡니다.
Future<
  ({
    Directory dir,
    FakeAccountBackend server,
    AccountStore account,
    RunningRecordStore records,
  })
>
_emailAccount() async {
  final dir = Directory.systemTemp.createTempSync('runnery_delete_test_');
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // 윈도우에서 아직 열려 있는 임시 폴더는 OS가 나중에 정리합니다.
    }
  });
  final server = FakeAccountBackend();
  final records = RunningRecordStore(directory: () async => dir);
  final account = AccountStore(
    directory: () async => dir,
    records: records,
    backend: server,
  );
  await account.register(_minji);
  await records.save(_run('a'));
  final photo = File('${dir.path}/picked.jpg')..writeAsBytesSync([1, 2, 3]);
  await account.updateProfile(
    name: '김민지',
    id: 'minji_run',
    age: 31,
    gender: '여성',
    weightKg: 58.5,
    newPhoto: photo,
  );
  return (dir: dir, server: server, account: account, records: records);
}

void main() {
  test(
    'email account: correct password deletes server and phone data',
    () async {
      final s = await _emailAccount();
      final uid = s.account.uid!;
      final photo = s.account.photoFile!;
      expect(photo.existsSync(), isTrue);
      expect(s.account.loginMethod, LoginMethod.email);

      expect(await s.account.deleteAccount(password: 'runner123'), isTrue);

      expect(s.account.isLoggedIn, isFalse);
      expect(s.server.deletedAccounts, [uid]);
      expect(s.server.hasProfile(uid), isFalse);
      expect(await s.records.load(), isEmpty);
      expect(photo.existsSync(), isFalse);
      final local = File('${s.dir.path}/account_local.json').readAsStringSync();
      expect(local, isNot(contains('minji_run')));

      // 같은 이메일로 다시 로그인할 수 없습니다.
      await expectLater(
        s.account.login('minji@example.com', 'runner123'),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test('email account: wrong password deletes nothing', () async {
    final s = await _emailAccount();
    await expectLater(
      s.account.deleteAccount(password: 'wrong999'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          '비밀번호가 맞지 않아요',
        ),
      ),
    );
    expect(s.account.isLoggedIn, isTrue);
    expect(s.server.deletedAccounts, isEmpty);
    expect(await s.records.load(), hasLength(1));
    expect(s.account.photoFile!.existsSync(), isTrue);
  });

  test('server failure keeps the account and phone data', () async {
    final s = await _emailAccount();
    s.server.failDeleteAccount = true;
    await expectLater(
      s.account.deleteAccount(password: 'runner123'),
      throwsA(isA<AuthException>()),
    );
    expect(s.account.isLoggedIn, isTrue);
    expect(await s.records.load(), hasLength(1));
  });

  test(
    'social account: closing the login or another account deletes nothing',
    () async {
      final dir = Directory.systemTemp.createTempSync('runnery_delete_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final server = FakeAccountBackend();
      final account = AccountStore(
        directory: () async => dir,
        records: RunningRecordStore(directory: () async => dir),
        backend: server,
      );
      expect(await account.loginWithKakao(), SocialLoginResult.needsProfile);
      await account.completeSocialProfile(_minji);
      expect(account.loginMethod, LoginMethod.kakao);

      server.cancelReauth = true;
      expect(await account.deleteAccount(), isFalse);
      expect(account.isLoggedIn, isTrue);

      server
        ..cancelReauth = false
        ..reauthOtherAccount = true;
      await expectLater(account.deleteAccount(), throwsA(isA<AuthException>()));
      expect(account.isLoggedIn, isTrue);
      expect(server.deletedAccounts, isEmpty);

      server.reauthOtherAccount = false;
      expect(await account.deleteAccount(), isTrue);
      expect(account.isLoggedIn, isFalse);
      expect(server.deletedAccounts, ['kakao:1001']);
    },
  );

  testWidgets('delete page: password check, then back to login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late final ({
      Directory dir,
      FakeAccountBackend server,
      AccountStore account,
      RunningRecordStore records,
    })
    s;
    // 저장소의 Future는 가짜 시간 영역 밖(runAsync)에서 만들어야 실제 파일 I/O가 끝납니다.
    await tester.runAsync(() async => s = await _emailAccount());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: DeleteAccountPage(store: s.account),
      ),
    );

    expect(find.text('정말 탈퇴할까요?'), findsOneWidget);
    // 비밀번호 없이 누르면 지우지 않습니다.
    await tester.tap(find.text('탈퇴하기'));
    await tester.pump();
    expect(find.text('비밀번호를 입력해주세요'), findsOneWidget);
    expect(s.server.deletedAccounts, isEmpty);

    await tester.enterText(find.byType(TextFormField), 'runner123');
    await tester.runAsync(() async {
      await tester.tap(find.text('탈퇴하기'));
      for (var i = 0; i < 50 && s.server.deletedAccounts.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      // 폰 데이터 정리(파일 I/O)가 끝날 때까지 기다립니다.
      for (var i = 0; i < 100 && s.account.photoFile != null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(s.server.deletedAccounts, hasLength(1));
    expect(find.byType(LoginPageV2), findsOneWidget);
    // 로그인 화면으로 돌아가는 것으로 끝나고, 아래 알림은 띄우지 않아요.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('delete page: social account explains the extra login', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('runnery_delete_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    late final AccountStore account;
    await tester.runAsync(() async {
      account = AccountStore(
        directory: () async => dir,
        records: RunningRecordStore(directory: () async => dir),
        backend: FakeAccountBackend(),
      );
      await account.loginWithNaver();
      await account.completeSocialProfile(_minji);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: DeleteAccountPage(store: account),
      ),
    );
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('네이버 로그인 화면이 한 번 더 열려요'), findsOneWidget);
  });
}
