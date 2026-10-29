import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/together_store.dart';
import 'package:runnery_new/friends/friends_page.dart';
import 'package:runnery_new/friends/together/together_done_page.dart';
import 'package:runnery_new/friends/together/together_lobby_page.dart';
import 'package:runnery_new/record/models/running_record.dart';

import 'support/fake_friend_backend.dart';

void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');

  // 2026년 10월 29일 목요일 정오.
  final now = DateTime(2026, 10, 29, 12);
  final at = DateTime(2026, 10, 30, 20);

  late FakeFriendBackend server;
  setUp(() {
    server = FakeFriendBackend()
      ..clock = (() => now)
        ..friends[minji.uid] = {haeun.uid}
        ..friends[haeun.uid] = {minji.uid}
        ..profilesByUid[minji.uid] = minji
        ..profilesByUid[haeun.uid] = haeun;
  });

  TogetherStore storeFor(
    PublicProfile me, {
    List<RunningRecord> records = const [],
  }) => TogetherStore(
    backend: server,
    me: () => me,
    records: () async => records,
    clock: () => now,
  );

  RunningRecord run(String id, DateTime startedAt, double km) => RunningRecord(
    id: id,
    startedAt: startedAt,
    distanceKm: km,
    movingSeconds: 1900,
    calories: 310,
    caloriesKcal: 310,
    route: const [],
  );

  test('request, accept, decline and undo', () async {
    final a = storeFor(minji), b = storeFor(haeun);
    await a.create([haeun], at, 5);
    expect(a.active, hasLength(1));
    expect(a.active.single.allAccepted(minji.uid), isFalse);

    await b.refresh();
    expect(b.requests, hasLength(1));
    expect(b.person(minji.uid), minji);

    await b.answer(b.requests.single, TogetherStatus.declined);
    expect(b.requests, isEmpty);
    expect(b.active, isEmpty);

    await b.answer(b.byId('t1')!, TogetherStatus.pending);
    expect(b.requests, hasLength(1));

    await b.answer(b.requests.single, TogetherStatus.accepted);
    expect(b.active, hasLength(1));
    await a.refresh();
    expect(a.active.single.allAccepted(minji.uid), isTrue);
  });

  test('results go to the appointment and it becomes past', () async {
    final a = storeFor(minji), b = storeFor(haeun);
    await a.create([haeun], at, 5);
    await b.refresh();
    await b.answer(b.requests.single, TogetherStatus.accepted);
    await server.startTogether('t1');

    await a.refresh();
    await a.runFinished('t1', run('r1', now, 5.12));
    expect(a.past, hasLength(1));
    expect(server.togetherById['t1']!.results[minji.uid]!.distanceKm, 5.12);

    // 하은은 결과를 못 올렸지만, 시작 시각 근처에 달린 기록을 찾아 이어 줍니다.
    final late = storeFor(
      haeun,
      records: [
        run('old', now.subtract(const Duration(hours: 2)), 3),
        run('r2', now.add(const Duration(minutes: 2)), 5.3),
      ],
    );
    await late.refresh();
    final t = server.togetherById['t1']!;
    expect(t.results[haeun.uid]!.recordId, 'r2');
    expect(t.totalKm, closeTo(10.42, 1e-9));
  });

  test('host can cancel; old appointments expire', () async {
    final a = storeFor(minji);
    await a.create([haeun], at, 5);
    await a.cancel(a.active.single);
    expect(server.togetherById, isEmpty);

    await a.create([haeun], now.subtract(const Duration(hours: 4)), 5);
    expect(a.active, isEmpty);
    expect(a.past, hasLength(1));
  });

  group('lobby', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<List<String>> openLobby(
      WidgetTester tester,
      TogetherStore store,
    ) async {
      final started = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: TogetherLobbyPage(
            id: 't1',
            store: store,
            checkLocation: () async => true,
            startRun: (_, t) async => started.add(t.id),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return started;
    }

    testWidgets('pressing start counts down and starts everyone', (
      tester,
    ) async {
      phone(tester);
      final a = storeFor(minji);
      await a.create([haeun], at, 5);
      await server.setTogetherStatus('t1', haeun.uid, TogetherStatus.accepted);
      final started = await openLobby(tester, a);

      // 친구가 아직 대기실에 없으면 시작할 수 없습니다.
      expect(find.text('친구가 대기실에 들어오면 시작할 수 있어요'), findsOneWidget);
      expect(server.togetherById['t1']!.ready.keys, [minji.uid]);

      await server.setTogetherReady('t1', haeun.uid, ready: true);
      await tester.pump();
      await tester.pump();
      expect(find.text('준비됐어요'), findsNWidgets(2));

      await tester.tap(find.text('함께 시작'));
      await tester.pump();
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(started, ['t1']);
    });

    testWidgets('a friend pressing start starts my run too', (tester) async {
      phone(tester);
      final b = storeFor(haeun);
      await storeFor(minji).create([haeun], at, 7);
      await server.setTogetherStatus('t1', haeun.uid, TogetherStatus.accepted);
      final started = await openLobby(tester, b);

      await server.setTogetherReady('t1', minji.uid, ready: true);
      await server.startTogether('t1');
      await tester.pump();
      expect(find.text('함께 출발해요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(started, ['t1']);
    });

    testWidgets('joining after start offers join now', (tester) async {
      phone(tester);
      final b = storeFor(haeun);
      await storeFor(minji).create([haeun], at, 5);
      await server.setTogetherStatus('t1', haeun.uid, TogetherStatus.accepted);
      await server.startTogether('t1');
      final started = await openLobby(tester, b);

      expect(find.text('함께 달리기가 이미 시작됐어요'), findsOneWidget);
      await tester.tap(find.text('지금 합류'));
      await tester.pump();
      expect(started, ['t1']);
    });
  });

  testWidgets('together tab accepts a request and shows records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await storeFor(minji).create([haeun], at, 5);
    final b = storeFor(haeun);
    final friends = FriendStore(
      backend: server,
      me: () => haeun,
      records: () async => const [],
      clock: () => now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsPage(store: friends, together: b),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('함께 달리기'));
    await tester.pumpAndSettle();

    expect(find.text('김민지 님이 함께 달리자고 해요'), findsOneWidget);
    expect(find.text('10월 30일 (금) 오후 8:00'), findsOneWidget);
    await tester.tap(find.text('수락'));
    await tester.pumpAndSettle();
    expect(find.text('김민지 님과의 약속을 수락했어요'), findsOneWidget);
    expect(find.text('내일 오후 8:00'), findsOneWidget);
    expect(find.text('모두 수락'), findsOneWidget);

    // 둘 다 달리고 나면 지난 약속과 함께 달린 기록에 보입니다.
    final t = server.togetherById['t1']!;
    server.putTogether(
      Together(
        id: t.id,
        host: t.host,
        members: t.members,
        statuses: t.statuses,
        startsAt: t.startsAt,
        goalKm: 5,
        startedAt: now,
        results: {
          minji.uid: TogetherResult(
            recordId: 'r1',
            distanceKm: 5.12,
            movingSeconds: 1900,
            kcal: 308,
            finishedAt: DateTime(2026, 10, 30, 20, 32),
          ),
          haeun.uid: TogetherResult(
            recordId: 'r2',
            distanceKm: 5.3,
            movingSeconds: 1985,
            kcal: 319,
            finishedAt: DateTime(2026, 10, 30, 20, 34),
          ),
        },
      ),
    );
    await b.refresh();
    await tester.pumpAndSettle();
    expect(find.text('지난 약속'), findsOneWidget);
    expect(find.text('둘 다 완주'), findsOneWidget);
    expect(find.text('목표 5 km · 함께 10.42 km'), findsOneWidget);

    await tester.tap(find.text('둘 다 완주'));
    await tester.pumpAndSettle();
    expect(find.byType(TogetherDonePage), findsOneWidget);
    expect(find.text('김민지 님과 함께\n5 km를 달렸어요'), findsOneWidget);
    expect(find.text('둘 다 목표 달성'), findsOneWidget);
    expect(find.text('10.42'), findsOneWidget);
    expect(find.text('627'), findsOneWidget);
    expect(find.text('오후 8:32 도착'), findsOneWidget);
  });
}
