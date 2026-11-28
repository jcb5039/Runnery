import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/crew/crew_room_page.dart';
import 'package:runnery_new/friends/crew/crew_run_pages.dart';
import 'package:runnery_new/friends/data/crew_store.dart';
import 'package:runnery_new/friends/data/friend_models.dart' show LiveRun;
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/together_live.dart';

import 'support/fake_crew_backend.dart';
import 'support/fake_friend_backend.dart';

/// 크루 3-2: 모집 열기·참여·대기실(색, 준비, 나가기 막기, 팀장이 나가면 닫힘).
void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');
  const seojun = PublicProfile(uid: 'u3', name: '이서준', id: 'seojun_k');

  late FakeFriendBackend server;
  late FakeCrewBackend crews;
  late String crewId;
  var tick = DateTime(2026, 10, 24, 19);
  DateTime now() => tick = tick.add(const Duration(minutes: 1));

  CrewStore storeFor(PublicProfile me) =>
      CrewStore(backend: crews, me: () => me, clock: () => tick);

  /// 가짜 서버 함수는 누가 불렀는지 알아야 해서, 부르기 전에 정합니다.
  Future<T> as<T>(PublicProfile who, Future<T> Function() task) {
    crews.actor = who.uid;
    return task();
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> setUpCrew() async {
    server = FakeFriendBackend()
      ..profilesByUid[minji.uid] = minji
      ..profilesByUid[haeun.uid] = haeun
      ..profilesByUid[seojun.uid] = seojun
      ..friends[minji.uid] = {haeun.uid, seojun.uid}
      ..friends[haeun.uid] = {minji.uid}
      ..friends[seojun.uid] = {minji.uid};
    crews = FakeCrewBackend(server)..clock = now;
    final a = storeFor(minji);
    crewId = await a.create('반포 저녁런', [haeun, seojun]);
    for (final p in [haeun, seojun]) {
      final s = storeFor(p)..start();
      await settle();
      await s.accept(s.invites.single);
    }
  }

  group('저장소', () {
    setUp(setUpCrew);

    test('모집을 열면 채팅방에 카드가 올라가고, 한 사람은 하나만 열어요', () async {
      final a = storeFor(minji);
      final id = await as(minji, () => a.openRun(crewId, '반포대교 한 바퀴'));
      final card = crews.messagesById[crewId]!.last;
      expect(card.kind, CrewMessageKind.run);
      expect(card.runId, id);
      expect(card.text, '반포대교 한 바퀴');
      expect(
        () => as(minji, () => a.openRun(crewId, '또 열기')),
        throwsA(isA<FriendException>()),
      );
      expect(
        () => as(minji, () => a.openRun(crewId, '가' * 21)),
        throwsA(isA<FriendException>()),
      );
    });

    test('참여하면 다른 색을 받고, 다른 모집에는 동시에 못 들어가요', () async {
      final a = storeFor(minji), b = storeFor(haeun), c = storeFor(seojun);
      final first = await as(minji, () => a.openRun(crewId, '첫 모집'));
      final second = await as(seojun, () => c.openRun(crewId, '두 번째 모집'));
      final run1 = crews.runs['$crewId/$first']!;
      await as(haeun, () => b.joinRun(run1));
      final joined = crews.runs['$crewId/$first']!;
      expect(joined.members, [minji.uid, haeun.uid]);
      expect(joined.colorOf(haeun.uid), isNot(joined.colorOf(minji.uid)));
      expect(
        () => as(haeun, () => b.joinRun(crews.runs['$crewId/$second']!)),
        throwsA(isA<FriendException>()),
      );
    });

    test('차단한 사람이 연 모집에는 참여할 수 없어요', () async {
      final a = storeFor(minji), b = storeFor(haeun);
      final id = await as(minji, () => a.openRun(crewId, '모집'));
      server.blocks[haeun.uid] = {minji.uid};
      expect(
        () => as(haeun, () => b.joinRun(crews.runs['$crewId/$id']!)),
        throwsA(isA<FriendException>()),
      );
    });

    test('준비 완료면 못 나가고, 팀장이 나가면 모집이 닫히며 모두 풀려나요', () async {
      final a = storeFor(minji), b = storeFor(haeun);
      final id = await as(minji, () => a.openRun(crewId, '모집'));
      String key() => '$crewId/$id';
      await as(haeun, () => b.joinRun(crews.runs[key()]!));
      await as(haeun, () => b.setRunReady(crews.runs[key()]!, ready: true));
      expect(crews.runs[key()]!.canStart, isTrue);
      expect(
        () => as(haeun, () => b.leaveRun(crews.runs[key()]!)),
        throwsA(isA<FriendException>()),
      );
      await as(minji, () => a.leaveRun(crews.runs[key()]!));
      // 닫힌 모집은 서버에서 지워져요.
      expect(crews.runs[key()], isNull);
      expect(crews.runnerLocks, isEmpty);
      // 닫히면 둘 다 새 모집을 열 수 있어요.
      await as(haeun, () => b.openRun(crewId, '새 모집'));
    });

    testWidgets('팀원은 고른 색으로 보이고, 먼저 끝내도 지나간 길이 끝난 자리까지 남아요', (tester) async {
      final a = storeFor(minji), b = storeFor(haeun);
      late String key, runId;
      await tester.runAsync(() async {
        runId = await as(minji, () => a.openRun(crewId, '반포대교'));
        key = '$crewId/$runId';
        await as(haeun, () => b.joinRun(crews.runs[key]!));
        await as(haeun, () => b.setRunColor(crews.runs[key]!, 6));
        await as(haeun, () => b.setRunReady(crews.runs[key]!, ready: true));
        await as(minji, () => a.startRun(crews.runs[key]!));
      });
      final runner = TogetherLive.channel(b.liveChannel(crewId, runId))
        ..start();
      final watcher = TogetherLive.channel(a.liveChannel(crewId, runId))
        ..start();
      runner.update(
        meters: 800,
        moving: const Duration(minutes: 4),
        paused: false,
        position: (37.5, 127.0),
        routePoint: (37.5, 127.0),
      );
      await tester.pump(TogetherLive.interval);
      runner.update(
        meters: 1000,
        moving: const Duration(minutes: 5),
        paused: false,
        position: (37.5003, 127.0),
        routePoint: (37.5003, 127.0),
      );
      // 끝내면 마지막 자리까지 한 번 더 올리고, 지우지 않아요.
      await runner.close();
      await tester.runAsync(
        () => as(
          haeun,
          () => b.finishRun(
            crewId,
            runId,
            recordId: 'r1',
            distanceKm: 1,
            movingSeconds: 300,
            kcal: 60,
          ),
        ),
      );
      await tester.pump();
      final live = crews.liveByRun[key]![haeun.uid]!;
      expect(live.route, [(37.5, 127.0), (37.5003, 127.0)]);
      final friend = watcher.friends.single;
      expect(friend.state, LiveFriendState.finished);
      expect(friend.color, 6);
      expect(friend.run!.route, hasLength(2));
      watcher.dispose();
    });

    test('팀이 끝나면 각자의 길이 출발·도착 200m를 잘라 팀 기록에 남고, 고른 색도 함께 남아요', () async {
      final a = storeFor(minji), b = storeFor(haeun);
      final runId = await as(minji, () => a.openRun(crewId, '반포대교'));
      final key = '$crewId/$runId';
      await as(haeun, () => b.joinRun(crews.runs[key]!));
      await as(haeun, () => b.setRunColor(crews.runs[key]!, 6));
      await as(haeun, () => b.setRunReady(crews.runs[key]!, ready: true));
      await as(minji, () => a.startRun(crews.runs[key]!));
      expect(await a.runRoutes(crewId, runId), isEmpty);

      // 박하은이 북쪽으로 1km(50m마다 점) 달리는 중이에요.
      final route = [
        for (var i = 0; i <= 20; i++) (37.5 + 50 / 111000 * i, 127.0),
      ];
      await crews.setRunLive(
        crewId,
        runId,
        LiveRun(uid: haeun.uid, distanceKm: 1, route: route),
      );
      await as(minji, () => a.endTeam(crewId, runId));

      final routes = await a.runRoutes(crewId, runId);
      final hers = routes[haeun.uid]!;
      expect(hers.color, 6);
      expect(hers.points.first, isNot(route.first));
      expect(hers.points.last, isNot(route.last));
      expect(hers.points, hasLength(13));
    });
  });

  group('화면', () {
    late FriendStore friends;
    late CrewStore store;

    setUp(() => CrewLobbyPage.defaultCheckLocation = () async => true);

    Future<void> open(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
    }

    testWidgets('함께 시작 → 제목 → 대기실(팀장)', (tester) async {
      await tester.runAsync(setUpCrew);
      friends = FriendStore(backend: server, me: () => minji);
      store = storeFor(minji);
      crews.actor = minji.uid;
      await open(
        tester,
        CrewRoomPage(id: crewId, friends: friends, store: store),
      );

      await tester.tap(find.byTooltip('함께 시작'));
      await tester.pumpAndSettle();
      expect(find.text('최대 10명까지 함께 달릴 수 있어요'), findsOneWidget);
      expect(find.text('제목을 입력해 주세요'), findsOneWidget);
      // 제목 창은 채팅방 위로 올라와요(뒤의 채팅 입력 칸 말고 창의 입력 칸).
      await tester.enterText(find.byType(TextField).last, '물빛광장 5 km 같이 뛰어요');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '만들기'));
      await tester.pumpAndSettle();

      // 팀을 만들자마자 색 고르는 화면이 떠요(팀장은 '확인').
      expect(find.text('내 색상'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('모래'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '확인'));
      await tester.pumpAndSettle();
      expect(crews.runs.values.single.colorOf(minji.uid), 4);

      expect(find.byType(CrewLobbyPage), findsOneWidget);
      expect(find.text('물빛광장 5 km 같이 뛰어요'), findsOneWidget);
      expect(find.text('내가 열었어요 · 1/10명'), findsOneWidget);
      // 내 이름표에는 시안처럼 '나 · 팀장'이 붙어요.
      expect(find.text('나 · 팀장'), findsOneWidget);
      // 혼자면 시작할 수 없어요.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '러닝 시작'))
            .onPressed,
        isNull,
      );

      // 팀장이 나가려고 하면 확인을 받아요.
      await tester.tap(find.byTooltip('대기실 나가기'));
      await tester.pumpAndSettle();
      expect(find.text('대기실을 나갈까요?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '나가기'));
      await tester.pumpAndSettle();
      // 닫힌 모집은 서버에서 지워지고, 채팅방의 카드도 사라져요.
      expect(crews.runs, isEmpty);
      expect(find.text('물빛광장 5 km 같이 뛰어요'), findsNothing);
      expect(find.text('모집이 닫혔어요'), findsNothing);
    });

    testWidgets('이미 들어가 있던 대기실을 다시 열 때는 색 고르는 화면이 뜨지 않아요', (tester) async {
      await tester.runAsync(() async {
        await setUpCrew();
        crews.actor = minji.uid;
        final runId = await storeFor(minji).openRun(crewId, '반포대교 한 바퀴 뛰어요');
        // 박하은은 이미 참여해 있어요.
        crews.actor = haeun.uid;
        await storeFor(haeun).joinRun(crews.runs['$crewId/$runId']!);
      });
      friends = FriendStore(backend: server, me: () => haeun);
      store = storeFor(haeun);
      await open(
        tester,
        CrewRoomPage(id: crewId, friends: friends, store: store),
      );
      await tester.tap(find.widgetWithText(FilledButton, '대기실로 가기'));
      await tester.pumpAndSettle();
      expect(find.byType(CrewLobbyPage), findsOneWidget);
      expect(find.text('내 색상'), findsNothing);
    });

    testWidgets('참여하자마자 뜬 색 화면을 그냥 닫아도 대기실에 그대로 있어요', (tester) async {
      await tester.runAsync(() async {
        await setUpCrew();
        crews.actor = minji.uid;
        await storeFor(minji).openRun(crewId, '반포대교 한 바퀴 뛰어요');
      });
      friends = FriendStore(backend: server, me: () => haeun);
      store = storeFor(haeun);
      crews.actor = haeun.uid;
      await open(
        tester,
        CrewRoomPage(id: crewId, friends: friends, store: store),
      );
      await tester.tap(find.widgetWithText(FilledButton, '참여'));
      await tester.pumpAndSettle();
      expect(find.text('내 색상'), findsOneWidget);
      Navigator.of(tester.element(find.text('내 색상'))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CrewLobbyPage), findsOneWidget);
      expect(find.text('내 색상'), findsNothing);
      expect(crews.runs.values.single.ready, isEmpty);
    });

    testWidgets('위치 권한이 없으면 들어가자마자 색 고르는 화면을 띄우지 않아요', (tester) async {
      CrewLobbyPage.defaultCheckLocation = () async => false;
      await tester.runAsync(() async {
        await setUpCrew();
        crews.actor = minji.uid;
        await storeFor(minji).openRun(crewId, '반포대교 한 바퀴 뛰어요');
      });
      friends = FriendStore(backend: server, me: () => haeun);
      store = storeFor(haeun);
      crews.actor = haeun.uid;
      await open(
        tester,
        CrewRoomPage(id: crewId, friends: friends, store: store),
      );
      await tester.tap(find.widgetWithText(FilledButton, '참여'));
      await tester.pumpAndSettle();
      expect(find.byType(CrewLobbyPage), findsOneWidget);
      expect(find.text('내 색상'), findsNothing);
      expect(find.textContaining('위치 권한을 켜야'), findsOneWidget);
    });

    testWidgets('카드에서 참여 → 색 고르고 준비 완료 → 준비 중엔 못 나가요', (tester) async {
      late String runId;
      await tester.runAsync(() async {
        await setUpCrew();
        crews.actor = minji.uid;
        runId = await storeFor(minji).openRun(crewId, '반포대교 한 바퀴 뛰어요');
      });
      friends = FriendStore(backend: server, me: () => haeun);
      store = storeFor(haeun);
      crews.actor = haeun.uid;
      await open(
        tester,
        CrewRoomPage(id: crewId, friends: friends, store: store),
      );

      expect(find.text('반포대교 한 바퀴 뛰어요'), findsOneWidget);
      expect(find.text('1/10명 참여'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '참여'));
      await tester.pumpAndSettle();

      expect(find.text('김민지 님이 열었어요 · 2/10명'), findsOneWidget);
      // 참여하자마자 색 고르는 화면이 떠요(팀원은 '준비 완료').
      expect(find.text('내 색상'), findsOneWidget);
      // 팀장이 고른 색은 고를 수 없어요.
      expect(find.bySemanticsLabel('주황 · 김민지 님이 골랐어요'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('갈색'));
      await tester.pump();
      // 색 고르기 창의 '준비 완료'(대기실 아래쪽 버튼과 이름이 같아요).
      await tester.tap(find.widgetWithText(FilledButton, '준비 완료').last);
      await tester.pumpAndSettle();

      final run = crews.runs['$crewId/$runId']!;
      expect(run.colorOf(haeun.uid), 5);
      expect(run.ready, {haeun.uid});
      expect(find.widgetWithText(OutlinedButton, '준비 취소'), findsOneWidget);

      // 준비 완료면 나갈 수 없어요.
      await tester.tap(find.byTooltip('준비 취소를 누른 뒤 나갈 수 있어요'));
      await tester.pumpAndSettle();
      expect(find.text('준비 취소를 누른 뒤 나갈 수 있어요'), findsWidgets);
      expect(find.byType(CrewLobbyPage), findsOneWidget);
      // 안내 띠가 닫힐 때까지 기다립니다(아래쪽 버튼을 가려서).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '준비 취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('대기실 나가기'));
      await tester.pumpAndSettle();
      expect(find.byType(CrewLobbyPage), findsNothing);
      expect(crews.runs['$crewId/$runId']!.members, [minji.uid]);
    });

    testWidgets('출발하면 카드에 러닝 진행 중이 보이고, 팀이 끝나면 기록 보기가 나와요', (tester) async {
      late String key;
      await tester.runAsync(() async {
        await setUpCrew();
        final a = storeFor(minji), b = storeFor(haeun);
        final runId = await as(minji, () => a.openRun(crewId, '반포대교 한 바퀴'));
        key = '$crewId/$runId';
        await as(haeun, () => b.joinRun(crews.runs[key]!));
        await as(haeun, () => b.setRunReady(crews.runs[key]!, ready: true));
        await as(minji, () => a.startRun(crews.runs[key]!));
      });
      // 달리기에 참여하지 않은 사람이 채팅방에서 봐요.
      friends = FriendStore(backend: server, me: () => seojun);
      store = storeFor(seojun);
      await open(
        tester,
        CrewRoomPage(id: crewId, friends: friends, store: store),
      );
      expect(find.text('러닝 진행 중'), findsOneWidget);
      expect(find.text('2명이 함께 달리고 있어요'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '참여'), findsNothing);
      expect(find.widgetWithText(FilledButton, '대기실로 가기'), findsNothing);

      await tester.runAsync(
        () => as(
          minji,
          () => storeFor(minji).endTeam(crewId, key.split('/').last),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('러닝 진행 중'), findsNothing);
      expect(find.widgetWithText(FilledButton, '대기실로 가기'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, '기록 보기'));
      await tester.pumpAndSettle();
      // 팀 기록 화면을 만들기 전까지는 채팅방 메뉴의 '함께 달린 기록'이 열려요.
      expect(find.text('함께 달린 기록'), findsOneWidget);
    });

    testWidgets('팀장이 나가면 팀원에게 모집이 닫혔다고 알려 줘요', (tester) async {
      late String runId;
      await tester.runAsync(() async {
        await setUpCrew();
        crews.actor = minji.uid;
        runId = await storeFor(minji).openRun(crewId, '모집');
        crews.actor = haeun.uid;
        await storeFor(haeun).joinRun(crews.runs['$crewId/$runId']!);
      });
      friends = FriendStore(backend: server, me: () => haeun);
      store = storeFor(haeun);
      await open(
        tester,
        CrewLobbyPage(
          crewId: crewId,
          runId: runId,
          friends: friends,
          store: store,
        ),
      );
      expect(find.byType(CrewLobbyPage), findsOneWidget);

      await tester.runAsync(() async {
        crews.actor = minji.uid;
        await storeFor(minji).leaveRun(crews.runs['$crewId/$runId']!);
        await settle();
      });
      await tester.pumpAndSettle();
      expect(find.text('모집이 닫혔어요'), findsOneWidget);
    });
  });
}
