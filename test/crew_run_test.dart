import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/crew/crew_room_page.dart';
import 'package:runnery_new/friends/crew/crew_run_pages.dart';
import 'package:runnery_new/friends/data/crew_store.dart';
import 'package:runnery_new/friends/data/friend_store.dart';

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
      expect(crews.runs[key()]!.status, CrewRunStatus.closed);
      expect(crews.runnerLocks, isEmpty);
      // 닫히면 둘 다 새 모집을 열 수 있어요.
      await as(haeun, () => b.openRun(crewId, '새 모집'));
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
      await tester.enterText(find.byType(TextField), '물빛광장 5 km 같이 뛰어요');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '만들기'));
      await tester.pumpAndSettle();

      expect(find.text('대기실'), findsOneWidget);
      expect(find.text('물빛광장 5 km 같이 뛰어요'), findsOneWidget);
      expect(find.text('내가 열었어요 · 1/10명'), findsOneWidget);
      expect(find.text('팀장'), findsOneWidget);
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
      expect(crews.runs.values.single.status, CrewRunStatus.closed);
      // 채팅방의 카드가 '모집이 닫혔어요'로 바뀌어요.
      expect(find.text('모집이 닫혔어요'), findsOneWidget);
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
      expect(find.text('내 이름을 눌러 색을 고를 수 있어요'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '준비 완료'));
      await tester.pumpAndSettle();
      expect(find.text('내 색상'), findsOneWidget);
      // 팀장이 고른 색은 고를 수 없어요.
      expect(find.bySemanticsLabel('색 1, 김민지 님이 고름'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('색 6'));
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
      expect(find.text('대기실'), findsOneWidget);
      // 안내 띠가 닫힐 때까지 기다립니다(아래쪽 버튼을 가려서).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '준비 취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('대기실 나가기'));
      await tester.pumpAndSettle();
      expect(find.text('대기실'), findsNothing);
      expect(crews.runs['$crewId/$runId']!.members, [minji.uid]);
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
      expect(find.text('대기실'), findsOneWidget);

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
