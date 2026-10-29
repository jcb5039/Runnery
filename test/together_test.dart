import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/together_store.dart';
import 'package:runnery_new/friends/friends_page.dart';
import 'package:runnery_new/friends/together/together_done_page.dart';
import 'package:runnery_new/friends/together/together_invite.dart';
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

  test('quick run has no goal and fresh invites arrive live', () async {
    final a = storeFor(minji), b = storeFor(haeun);
    final seen = <List<String>>[];
    final sub = b.invites().listen(
      (invites) => seen.add([for (final t in invites) t.id]),
    );
    await pumpEventQueue();
    final id = await a.startNow([haeun]);
    await pumpEventQueue();
    final t = server.togetherById[id]!;
    expect(t.goalKm, 0);
    expect(t.goalLabel, '목표 없이 자유롭게');
    expect(t.startsAt, now);
    expect(seen.last, [id]);
    // 함께 달리기 탭의 받은 요청도 바로 바뀝니다.
    expect(b.requests.single.id, id);

    // 날짜를 정한 약속도 알려 주지만, 10분 넘은 '바로' 초대와 지난 약속은 빼요.
    final scheduled = await a.create([haeun], at, 5);
    Together invite(String id, DateTime startsAt, int goalKm) => Together(
      id: id,
      host: minji.uid,
      members: [minji.uid, haeun.uid],
      statuses: {
        minji.uid: TogetherStatus.accepted,
        haeun.uid: TogetherStatus.pending,
      },
      startsAt: startsAt,
      goalKm: goalKm,
      createdAt: startsAt,
    );
    server
      ..putTogether(invite('old', now.subtract(const Duration(minutes: 11)), 0))
      ..putTogether(invite('past', now.subtract(const Duration(hours: 4)), 5));
    await pumpEventQueue();
    expect(seen.last, [id, scheduled]);

    await b.answer(b.byId(id)!, TogetherStatus.accepted);
    await pumpEventQueue();
    expect(seen.last, [scheduled]);
    // 내가 보낸 약속은 알려 주지 않습니다.
    await b.create([minji], at, 3);
    await pumpEventQueue();
    expect(seen.last, [scheduled]);
    await sub.cancel();
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
      // 혼자 달릴 때와 같은 3·2·1 화면이고, 눌러도 먼저 출발하지 않습니다.
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.text('함께 출발해요'));
      await tester.pump(const Duration(seconds: 1));
      expect(started, isEmpty);
      expect(find.text('2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2100));
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
      await tester.pump(const Duration(milliseconds: 3100));
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

  /// 테스트에는 GPS가 없어서 대기실의 위치 확인이 '위치 서비스 꺼짐'으로 끝나게 합니다.
  void noLocation(WidgetTester tester) {
    const channel = MethodChannel('flutter.baseflow.com/geolocator');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  testWidgets('quick run picks friends and goes straight to the lobby', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    noLocation(tester);
    final a = storeFor(minji);
    final friends = FriendStore(
      backend: server,
      me: () => minji,
      records: () async => const [],
      clock: () => now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsPage(store: friends, together: a),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('함께 달리기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('지금 바로 같이 뛰기'));
    await tester.pumpAndSettle();
    // 날짜·시간·목표 거리 없이 친구만 고릅니다.
    expect(find.text('날짜'), findsNothing);
    expect(find.text('목표 거리'), findsNothing);
    await tester.tap(find.text('박하은'));
    await tester.pump();
    await tester.tap(find.text('같이 뛰자고 보내기'));
    await tester.pumpAndSettle();

    expect(server.togetherById['t1']!.goalKm, 0);
    expect(find.byType(TogetherLobbyPage), findsOneWidget);
    expect(find.text('지금 바로 같이 뛰기'), findsOneWidget);
    expect(
      find.text('목표 없이 자유롭게 · 시작을 누르면 대기실에 있는 모두가 함께 출발해요'),
      findsOneWidget,
    );
  });

  testWidgets('a quick invite pops up and joining opens the lobby', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    noLocation(tester);
    final b = storeFor(haeun);
    await tester.pumpWidget(
      MaterialApp(
        home: TogetherInviteListener(store: b, child: const Scaffold()),
      ),
    );
    await tester.pump();

    await storeFor(minji).startNow([haeun]);
    await tester.pumpAndSettle();
    expect(find.text('김민지 님이 지금 같이 뛰자고 해요'), findsOneWidget);
    await tester.tap(find.text('참여하기'));
    await tester.pumpAndSettle();

    expect(
      server.togetherById['t1']!.statusOf(haeun.uid),
      TogetherStatus.accepted,
    );
    expect(find.byType(TogetherLobbyPage), findsOneWidget);
    expect(find.text('지금 바로 같이 뛰기'), findsOneWidget);
  });

  testWidgets('a scheduled invite pops up once and can be accepted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final b = storeFor(haeun);
    await tester.pumpWidget(
      MaterialApp(
        home: TogetherInviteListener(store: b, child: const Scaffold()),
      ),
    );
    await tester.pump();

    await storeFor(minji).create([haeun], at, 5);
    await tester.pumpAndSettle();
    expect(find.text('김민지 님이 함께 달리자고 해요'), findsOneWidget);
    expect(find.text('10월 30일 (금) 오후 8:00 · 목표 5 km.'), findsOneWidget);
    await tester.tap(find.text('수락하기'));
    await tester.pumpAndSettle();

    expect(
      server.togetherById['t1']!.statusOf(haeun.uid),
      TogetherStatus.accepted,
    );
    expect(find.text('김민지 님과의 약속을 수락했어요'), findsOneWidget);
    expect(find.byType(TogetherLobbyPage), findsNothing);

    // '나중에'를 누른 약속은 앱을 켜 둔 동안 다시 띄우지 않습니다.
    await storeFor(minji).create([haeun], at, 7);
    await tester.pumpAndSettle();
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    await server.setTogetherReady('t2', minji.uid, ready: true);
    await tester.pumpAndSettle();
    expect(find.text('나중에'), findsNothing);
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
