import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/account/account_store.dart';
import 'package:runnery_new/login/auth_ui/auth_ui.dart';
import 'package:runnery_new/record/data/record_backend.dart';
import 'package:runnery_new/record/data/record_sync.dart';
import 'package:runnery_new/record/data/running_record_store.dart';
import 'package:runnery_new/record/models/running_record.dart';

import 'support/fake_account_backend.dart';
import 'support/fake_record_backend.dart';

void main() {
  const uid = 'uid-1';
  late FakeRecordBackend server;
  late Directory dirA, dirB;

  /// 폰 한 대: 폴더 하나와 동기화가 붙은 기록 저장소.
  RunningRecordStore phone(Directory dir, {bool sync = true}) =>
      RunningRecordStore(
        directory: () async => dir,
        sync: sync
            ? RecordSync(backend: server, directory: () async => dir)
            : null,
      );

  RunningRecord run(String id, {String memo = '', int points = 3}) =>
      RunningRecord(
        id: id,
        startedAt: DateTime(2026, 10, 6, 7),
        distanceKm: 3,
        movingSeconds: 900,
        calories: 200,
        memo: memo,
        route: [
          for (var i = 0; i < points; i++)
            RecordCoordinate(
              37.5 + i * 0.0001,
              127.0 + i * 0.0001,
              timestamp: DateTime(2026, 10, 6, 7, 0, i),
              startsSegment: i == 0,
            ),
        ],
      );

  Future<List<String>> ids(RunningRecordStore store) async => [
    for (final r in await store.load()) r.id,
  ]..sort();

  setUp(() async {
    server = FakeRecordBackend();
    dirA = await Directory.systemTemp.createTemp('runnery_sync_a_');
    dirB = await Directory.systemTemp.createTemp('runnery_sync_b_');
  });
  tearDown(() async {
    for (final dir in [dirA, dirB]) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // 뒤에서 도는 동기화가 아직 파일을 쓰고 있으면 OS가 나중에 정리합니다.
      }
    }
  });

  test('a saved record goes to the server', () async {
    final a = phone(dirA);
    await a.startSync(uid);
    await a.save(run('run-1'));
    await a.syncNow();
    expect(server.recordsOf(uid).keys, ['run-1']);
    expect(await a.flushSync(), 0);
  });

  test('a new phone gets the records after logging in', () async {
    final a = phone(dirA);
    await a.startSync(uid);
    await a.save(run('run-1', points: 50));
    await a.save(run('run-2'));
    await a.syncNow();

    final b = phone(dirB);
    expect(await ids(b), isEmpty);
    await b.startSync(uid);
    expect(await ids(b), ['run-1', 'run-2']);
    final copy = (await b.load()).firstWhere((r) => r.id == 'run-1');
    expect(copy.route, hasLength(50));
    expect(copy.route.first.startsSegment, isTrue);
  });

  test('a memo edited on one phone reaches the other', () async {
    final a = phone(dirA), b = phone(dirB);
    await a.startSync(uid);
    await a.save(run('run-1'));
    await a.syncNow();
    await b.startSync(uid);

    await a.update('run-1', (r) => r.withMemo('한강 러닝'));
    await a.syncNow();
    await b.syncNow();
    expect((await b.load()).single.memo, '한강 러닝');
  });

  test('a record deleted on one phone disappears from the other', () async {
    final a = phone(dirA), b = phone(dirB);
    await a.startSync(uid);
    await a.save(run('run-1'));
    await a.save(run('run-2'));
    await a.syncNow();
    await b.startSync(uid);
    expect(await ids(b), ['run-1', 'run-2']);

    await a.delete('run-1');
    await a.syncNow();
    expect(server.deletedOf(uid), {'run-1'});
    await b.syncNow();
    expect(await ids(b), ['run-2']);
  });

  test('records saved without internet go up later, even after a restart', () async {
    final a = phone(dirA);
    await a.startSync(uid);
    server.offline = true;
    await a.save(run('run-1'));
    await a.syncNow();
    expect(server.recordsOf(uid), isEmpty);
    expect(await a.flushSync(), 1);

    // 앱을 껐다 켠 것처럼 새 저장소로 같은 폴더를 엽니다. 올릴 일이 남아 있어야 합니다.
    server.offline = false;
    final restarted = phone(dirA);
    await restarted.startSync(uid);
    expect(server.recordsOf(uid).keys, ['run-1']);
    expect(await restarted.flushSync(), 0);
  });

  test('records from before sync existed are uploaded at the first sync', () async {
    final plain = phone(dirA, sync: false);
    await plain.save(run('old-1'));
    await plain.save(run('old-2'));

    final a = phone(dirA);
    await a.startSync(uid);
    await a.syncNow();
    expect(server.recordsOf(uid).keys.toSet(), {'old-1', 'old-2'});
    expect(await a.flushSync(), 0);
  });

  test('before the first sync every local record counts as not uploaded', () async {
    final plain = phone(dirA, sync: false);
    await plain.save(run('old-1'));
    await plain.save(run('old-2'));
    server.offline = true;
    final a = phone(dirA);
    await a.startSync(uid);
    expect(await a.flushSync(), 2);
    server.offline = false;
    expect(await a.flushSync(), 0);
  });

  test('the local change wins while it is not uploaded yet', () async {
    final a = phone(dirA), b = phone(dirB);
    await a.startSync(uid);
    await a.save(run('run-1'));
    await a.syncNow();
    await b.startSync(uid);

    // b가 인터넷 없이 메모를 고치는 사이(올리지 못함) a가 먼저 서버의 메모를 바꿉니다.
    server.offline = true;
    await b.update('run-1', (r) => r.withMemo('b의 메모'));
    // 저장하면 뒤에서 올리기를 시도합니다. 인터넷이 없는 동안 그 시도가 끝나길 기다립니다.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await b.syncNow();
    expect(server.recordsOf(uid)['run-1']!.memo, '');
    server.offline = false;
    await a.update('run-1', (r) => r.withMemo('a의 메모'));
    await a.syncNow();
    // 이제 b가 맞추면: 아직 못 올린 b의 변경이 서버 것으로 덮이지 않고 올라갑니다.
    await b.syncNow();
    expect((await b.load()).single.memo, 'b의 메모');
    expect(server.recordsOf(uid)['run-1']!.memo, 'b의 메모');
  });

  test('another account on the same phone starts from a clean state', () async {
    server.offline = true;
    final first = phone(dirA);
    await first.startSync('uid-1');
    await first.save(run('run-1'));
    expect(await first.flushSync(), 1);
    await first.stopSync();

    // 같은 폴더를 다른 계정이 열면 앞 계정의 '올릴 일'을 이어받지 않습니다.
    server.offline = false;
    final other = phone(dirB);
    await other.startSync('uid-2');
    expect(server.recordsOf('uid-2'), isEmpty);
    final again = phone(dirA);
    await again.startSync('uid-2');
    expect(server.recordsOf('uid-1'), isEmpty);
  });

  test('a long run stays far below the server document limit', () async {
    final long = run('run-long', points: 20000);
    final bytes = encodeRecordPayload(long);
    expect(bytes.length, lessThan(950000));
    final back = decodeRecordPayload(bytes);
    expect(back.route, hasLength(20000));
    expect(back.route[19999].latitude, long.route[19999].latitude);
    expect(back.route[0].startsSegment, isTrue);
  });

  group('with the account', () {
    late FakeAccountBackend accounts;
    late RunningRecordStore records;
    late AccountStore account;

    AccountStore openAccount() =>
        AccountStore(
          directory: () async => dirA,
          records: records,
          backend: accounts,
        );

    const data = RegistrationData(
      name: '김민지',
      email: 'minji@example.com',
      id: 'minji_run',
      password: 'runner123',
      age: 26,
      gender: '여성',
      weight: 58,
    );

    /// 뒤에서 시작하는 동기화가 끝나길 기다립니다.
    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    setUp(() {
      accounts = FakeAccountBackend();
      records = phone(dirA);
      account = openAccount();
    });

    test('logging out clears this phone, logging in brings the records back', () async {
      await account.register(data);
      await until(() => records.syncActive);
      await records.save(run('run-1'));
      expect(await account.unsyncedRecordCount(), 0);

      await account.logout();
      expect(records.syncActive, isFalse);
      expect(await ids(records), isEmpty);
      expect(server.recordsOf(uid).keys, ['run-1']);

      await account.login('minji@example.com', 'runner123');
      await until(() => records.syncActive);
      await records.syncNow();
      expect(await ids(records), ['run-1']);
    });

    test('records not uploaded yet are reported before logging out', () async {
      await account.register(data);
      await until(() => records.syncActive);
      server.offline = true;
      await records.save(run('run-1'));
      expect(await account.unsyncedRecordCount(), 1);
    });

    test('logging out of an unverified account keeps the local records', () async {
      accounts = FakeAccountBackend(autoVerify: false);
      account = openAccount();
      final plain = phone(dirA, sync: false);
      await account.register(data);
      await plain.save(run('local-1'));
      expect(records.syncActive, isFalse);
      await account.logout();
      expect(await ids(plain), ['local-1']);
    });
  });
}
