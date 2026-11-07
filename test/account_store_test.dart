import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/account/account_store.dart';
import 'package:runnery_new/login/auth_ui/auth_ui.dart';
import 'package:runnery_new/record/data/running_record_store.dart';
import 'package:runnery_new/record/models/running_record.dart';

import 'support/fake_account_backend.dart';

void main() {
  late Directory directory;
  late RunningRecordStore records;
  late FakeAccountBackend backend;
  AccountStore open() => AccountStore(
    directory: () async => directory,
    records: records,
    backend: backend,
  );

  RegistrationData data({
    String email = 'minji@example.com',
    String id = 'minji_run',
    String password = 'runner123',
  }) => RegistrationData(
    name: '김민지',
    email: email,
    id: id,
    password: password,
    age: 26,
    gender: '여성',
    weight: 58.5,
  );

  RunningRecord run() => RunningRecord(
    id: 'run-1',
    startedAt: DateTime(2026, 10, 6),
    distanceKm: 3,
    movingSeconds: 900,
    calories: 200,
    route: const [],
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('runnery_account_test_');
    records = RunningRecordStore(directory: () async => directory);
    backend = FakeAccountBackend();
  });
  tearDown(() => directory.delete(recursive: true));

  test('register logs in and the next start keeps the login', () async {
    final store = open();
    await store.register(data());
    expect(store.isLoggedIn, isTrue);
    expect(store.current?.name, '김민지');
    expect(store.current?.initial, '김');
    expect(store.current?.weightKg, 58.5);
    expect(backend.verificationsSent, 1);

    final reopened = open();
    await reopened.load();
    expect(reopened.isLoggedIn, isTrue);
    expect(reopened.current?.id, 'minji_run');
    expect(reopened.current?.email, 'minji@example.com');
  });

  test('the sign-up mail is recorded, and a failed one is reported', () async {
    final store = open();
    await store.register(data());
    expect(store.verificationSentAt, isNotNull);
    expect(store.verificationError, isNull);

    backend = FakeAccountBackend(autoVerify: false)
      ..failSendVerification = true;
    final failed = open();
    await failed.register(data());
    // 메일이 안 가도 가입은 끝나고, 실패 이유를 숨기지 않고 남깁니다.
    expect(failed.needsVerification, isTrue);
    expect(failed.verificationSentAt, isNull);
    expect(failed.verificationError, contains('너무 자주'));

    backend.failSendVerification = false;
    await failed.resendVerification();
    expect(failed.verificationSentAt, isNotNull);
    expect(failed.verificationError, isNull);
  });

  test('logging in sends a new mail only for an unverified account', () async {
    backend = FakeAccountBackend(autoVerify: false);
    final store = open();
    await store.register(data());
    await store.logout();
    expect(backend.verificationsSent, 1);
    await store.login('minji@example.com', 'runner123');
    expect(store.needsVerification, isTrue);
    expect(backend.verificationsSent, 2);

    // 인증을 마친 계정은 로그인해도 메일을 보내지 않습니다.
    backend.verify('minji@example.com');
    await store.logout();
    await store.login('minji@example.com', 'runner123');
    expect(store.isLoggedIn, isTrue);
    expect(backend.verificationsSent, 2);
  });

  test('the password is never stored on this device', () async {
    await open().register(data());
    final raw = await File(
      '${directory.path}/account_local.json',
    ).readAsString();
    expect(raw.contains('runner123'), isFalse);
  });

  test('an unverified account must verify before it is logged in', () async {
    backend = FakeAccountBackend(autoVerify: false);
    final store = open();
    await store.register(data());
    expect(store.isLoggedIn, isFalse);
    expect(store.needsVerification, isTrue);
    expect(store.pendingEmail, 'minji@example.com');
    expect(await store.refreshVerification(), isFalse);

    backend.verify('minji@example.com');
    expect(await store.refreshVerification(), isTrue);
    expect(store.isLoggedIn, isTrue);
    expect(store.current?.id, 'minji_run');
  });

  test('logout keeps records; login checks email and password', () async {
    final store = open();
    await store.register(data());
    await records.save(run());
    await store.logout();
    expect(store.isLoggedIn, isFalse);
    expect(await records.load(), hasLength(1));

    final reopened = open();
    await reopened.load();
    expect(reopened.isLoggedIn, isFalse);
    await expectLater(
      reopened.login('minji@example.com', 'wrong'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      reopened.login('other@example.com', 'runner123'),
      throwsA(isA<AuthException>()),
    );
    await reopened.login('minji@example.com', 'runner123');
    expect(reopened.isLoggedIn, isTrue);
    expect(reopened.current?.name, '김민지');
  });

  test('registering clears the old records on this device', () async {
    await records.save(run());
    expect(await records.load(), hasLength(1));
    await open().register(data());
    expect(await records.load(), isEmpty);
  });

  test('a taken email or id fails and keeps the old records', () async {
    final first = open();
    await first.register(data());
    await records.save(run());
    await first.logout();

    final store = open();
    await expectLater(
      store.register(data(id: 'other_id')),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      store.register(data(email: 'other@example.com')),
      throwsA(isA<AuthException>()),
    );
    expect(store.isLoggedIn, isFalse);
    expect(await records.load(), hasLength(1));
    // 아이디가 겹쳐 실패한 가입은 서버에 계정이 남지 않아 같은 이메일로 다시 가입할 수 있습니다.
    await store.register(data(email: 'other@example.com', id: 'other_id'));
    expect(store.current?.id, 'other_id');
  });

  test('id availability is asked of the server', () async {
    final store = open();
    expect(await store.isIdAvailable(' minji_run '), isTrue);
    await store.register(data());
    expect(await store.isIdAvailable('minji_run'), isFalse);
  });

  test('starting without internet uses the profile saved on the device', () async {
    await open().register(data());
    backend.offline = true;
    final reopened = open();
    await reopened.load();
    expect(reopened.isLoggedIn, isTrue);
    expect(reopened.current?.name, '김민지');
  });

  test('starting without internet and without a saved copy stays logged out', () async {
    await open().register(data());
    await File('${directory.path}/account_local.json').delete();
    backend.offline = true;
    final reopened = open();
    await reopened.load();
    expect(reopened.isLoggedIn, isFalse);
  });

  test('changing the password needs the current password', () async {
    final store = open();
    await store.register(data());
    await expectLater(
      store.changePassword('wrong', 'newpass123'),
      throwsA(isA<AuthException>()),
    );
    await store.changePassword('runner123', 'newpass123');
    await store.logout();
    await expectLater(
      store.login('minji@example.com', 'runner123'),
      throwsA(isA<AuthException>()),
    );
    await store.login('minji@example.com', 'newpass123');
    expect(store.isLoggedIn, isTrue);
  });

  test('the old account file from before the server is removed', () async {
    final legacy = File('${directory.path}/account.json')
      ..writeAsStringSync('{"id":"old","salt":"x","hash":"y"}');
    final store = open();
    await store.load();
    expect(legacy.existsSync(), isFalse);
    expect(store.isLoggedIn, isFalse);
  });

  test('a broken local file means no saved copy, not a crash', () async {
    await File('${directory.path}/account_local.json').writeAsString('{broken');
    final store = open();
    await store.load();
    expect(store.isLoggedIn, isFalse);
  });
}
