import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/crew_store.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/together_store.dart';
import 'package:runnery_new/friends/friends_page.dart';

import 'support/fake_crew_backend.dart';
import 'support/fake_friend_backend.dart';

/// 크루 3-1: 크루 만들기·초대·채팅·서랍(공지, 내보내기, 나가기).
void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');
  const seojun = PublicProfile(uid: 'u3', name: '이서준', id: 'seojun_k');

  late FakeFriendBackend server;
  late FakeCrewBackend crews;
  var tick = DateTime(2026, 10, 24, 18);
  DateTime now() => tick = tick.add(const Duration(minutes: 1));

  CrewStore storeFor(PublicProfile me) =>
      CrewStore(backend: crews, me: () => me, clock: () => tick);

  setUp(() {
    tick = DateTime(2026, 10, 24, 18);
    server = FakeFriendBackend()
      ..profilesByUid[minji.uid] = minji
      ..profilesByUid[haeun.uid] = haeun
      ..profilesByUid[seojun.uid] = seojun
      ..friends[minji.uid] = {haeun.uid, seojun.uid}
      ..friends[haeun.uid] = {minji.uid}
      ..friends[seojun.uid] = {minji.uid};
    crews = FakeCrewBackend(server)..clock = now;
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('저장소', () {
    test('만들고 초대하면, 초대받은 친구가 수락해 들어와요', () async {
      final a = storeFor(minji), b = storeFor(haeun);
      final id = await a.create('  여의도 퇴근런 ', [haeun]);
      await settle();
      expect(a.crews.single.name, '여의도 퇴근런');
      expect(a.crews.single.owner, minji.uid);

      b.start();
      await settle();
      expect(b.invites.single.crewName, '여의도 퇴근런');
      await b.accept(b.invites.single);
      await settle();
      expect(b.invites, isEmpty);
      expect(b.crews.single.id, id);
      expect(crews.crewById[id]!.members, [minji.uid, haeun.uid]);
      expect(crews.messagesById[id]!.last.kind, CrewMessageKind.join);
    });

    test('이름은 비우거나 20자를 넘길 수 없어요', () async {
      final a = storeFor(minji);
      expect(() => a.create('  ', const []), throwsA(isA<FriendException>()));
      expect(
        () => a.create('가' * 21, const []),
        throwsA(isA<FriendException>()),
      );
    });

    test('메시지를 보내면 다른 멤버에게 안 읽은 수가 생기고, 읽으면 0이 돼요', () async {
      final a = storeFor(minji), b = storeFor(haeun);
      final id = await a.create('반포 저녁런', [haeun]);
      b.start();
      await settle();
      await b.accept(b.invites.single);
      await a.send(id, '오늘 8시 어때요?');
      await a.send(id, '물빛광장에서 만나요');
      await b.refresh();
      await settle();
      expect(b.unread(id), 2);
      expect(b.crews.single.lastMessage!.text, '물빛광장에서 만나요');

      await b.markRead(id);
      await b.refresh();
      expect(b.unread(id), 0);
      // 내가 보낸 메시지는 세지 않아요.
      expect(a.unread(id), 0);
    });

    test('공지와 내보내기는 크루장만 해요', () async {
      final a = storeFor(minji), b = storeFor(haeun);
      final id = await a.create('주말 LSD', [haeun]);
      b.start();
      await settle();
      await b.accept(b.invites.single);
      await settle();

      expect(
        () => b.setNotice(b.byId(id)!, '공지'),
        throwsA(isA<FriendException>()),
      );
      await a.setNotice(a.byId(id)!, '매주 토요일 7시');
      expect(crews.crewById[id]!.notice!.text, '매주 토요일 7시');

      expect(
        () => b.kick(b.byId(id)!, minji.uid),
        throwsA(isA<FriendException>()),
      );
      await a.kick(a.byId(id)!, haeun.uid);
      await settle();
      expect(crews.crewById[id]!.members, [minji.uid]);
      expect(b.crews, isEmpty);
    });

    test('크루장이 나가면 가장 오래된 멤버가 크루장이 되고, 혼자면 크루가 지워져요', () async {
      final a = storeFor(minji), b = storeFor(haeun);
      final id = await a.create('초보 모임', [haeun]);
      b.start();
      await settle();
      await b.accept(b.invites.single);
      await settle();

      await a.leave(a.byId(id)!);
      await settle();
      expect(crews.crewById[id]!.owner, haeun.uid);
      expect(crews.crewById[id]!.members, [haeun.uid]);

      await b.leave(b.byId(id)!);
      await settle();
      expect(crews.crewById[id], isNull);
    });
  });

  group('화면', () {
    late FriendStore friends;
    late CrewStore crewStore;

    setUp(() {
      friends = FriendStore(
        backend: server,
        me: () => minji,
        clock: () => tick,
      );
      crewStore = storeFor(minji);
    });

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: FriendsPage(
            store: friends,
            crew: crewStore,
            together: TogetherStore(
              backend: server,
              me: () => minji,
              records: () async => const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle();
    }

    testWidgets('크루를 만들면 채팅방이 열리고, 메시지를 보낼 수 있어요', (tester) async {
      await open(tester);
      expect(find.text('아직 크루가 없어요'), findsOneWidget);

      await tester.tap(find.text('크루 만들기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '여의도 퇴근런');
      await tester.tap(find.text('박하은'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '만들기'));
      await tester.pumpAndSettle();

      expect(find.text('첫 메시지를 보내 보세요'), findsOneWidget);
      expect(crews.invitesById.values.single.to, haeun.uid);

      await tester.enterText(find.byType(TextField), '오늘 한강 한 바퀴 어때요?');
      await tester.pump();
      await tester.tap(find.byTooltip('보내기'));
      await tester.pumpAndSettle();
      expect(find.text('오늘 한강 한 바퀴 어때요?'), findsOneWidget);

      await tester.tap(find.byTooltip('크루 목록으로'));
      await tester.pumpAndSettle();
      expect(find.text('여의도 퇴근런'), findsOneWidget);
      expect(find.text('나: 오늘 한강 한 바퀴 어때요?'), findsOneWidget);
    });

    testWidgets('차단한 사람의 메시지는 가려져요', (tester) async {
      await tester.runAsync(() async {
        final id = await crewStore.create('반포 저녁런', [haeun]);
        final b = storeFor(haeun)..start();
        await settle();
        await b.accept(b.invites.single);
        await b.send(id, '광고 링크예요');
        server.blocks[minji.uid] = {haeun.uid};
        await settle();
      });

      await open(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^반포 저녁런 크루 채팅방')));
      await tester.pumpAndSettle();
      expect(find.text('광고 링크예요'), findsNothing);
      expect(find.text('차단한 사용자의 메시지예요'), findsOneWidget);
      expect(find.text('박하은 님이 들어왔어요'), findsOneWidget);
    });

    testWidgets('서랍에서 공지를 쓰고 크루를 나갈 수 있어요', (tester) async {
      await tester.runAsync(() async {
        await crewStore.create('주말 LSD', const []);
        await settle();
      });
      await open(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^주말 LSD 크루 채팅방')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('채팅방 메뉴'));
      await tester.pumpAndSettle();
      expect(find.text('멤버 1명'), findsOneWidget);
      expect(find.text('크루장'), findsOneWidget);

      await tester.tap(find.byTooltip('공지 쓰기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '매주 토요일 7시에 모여요');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.text('매주 토요일 7시에 모여요'), findsOneWidget);

      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('혼자 남은 크루라'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '나가기'));
      await tester.pumpAndSettle();
      expect(find.text('아직 크루가 없어요'), findsOneWidget);
      expect(crews.crewById, isEmpty);
    });
  });
}
