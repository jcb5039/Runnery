import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/crew/crew_room_page.dart';
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

  /// 아무와도 친구가 아닌 사람.
  const stranger = PublicProfile(uid: 'u9', name: '정우진', id: 'woojin_9');

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
      ..profilesByUid[stranger.uid] = stranger
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

  group('초대 코드', () {
    /// 서버 함수처럼, 부르는 사람을 정한 뒤 그 사람의 저장소를 돌려줍니다.
    CrewStore as(PublicProfile who) {
      crews.actor = who.uid;
      return storeFor(who);
    }

    test('크루를 만들면 6자리 코드가 생기고, 친구가 아니어도 코드로 들어와요', () async {
      final id = await as(minji).create('주말 LSD', const []);
      final code = crews.crewById[id]!.code!;
      expect(Crew.normalizeCode(code), code);
      expect(code, hasLength(6));

      // 소문자로 쳐도 들어가요.
      expect(await as(stranger).joinByCode(code.toLowerCase()), id);
      expect(crews.crewById[id]!.members, [minji.uid, stranger.uid]);
      expect(crews.messagesById[id]!.last.kind, CrewMessageKind.join);
      // 이미 멤버면 그대로예요.
      expect(await as(stranger).joinByCode(code), id);
      expect(crews.crewById[id]!.members, hasLength(2));
    });

    test('틀린 코드·모양이 다른 코드는 들어갈 수 없어요', () async {
      await as(minji).create('주말 LSD', const []);
      await expectLater(
        as(stranger).joinByCode('ZZZZZZ'),
        throwsA(
          isA<FriendException>().having(
            (e) => e.message,
            'message',
            '코드를 다시 확인해 주세요',
          ),
        ),
      );
      await expectLater(
        as(stranger).joinByCode('AB0'),
        throwsA(
          isA<FriendException>().having(
            (e) => e.message,
            'message',
            '코드 6자리를 확인해 주세요',
          ),
        ),
      );
    });

    test('크루장이 코드를 바꾸면 예전 코드는 막혀요. 크루장만 바꿀 수 있어요', () async {
      final id = await as(minji).create('주말 LSD', const []);
      final old = crews.crewById[id]!.code!;
      final fresh = await as(minji).issueCode(crews.crewById[id]!);
      expect(fresh, isNot(old));
      expect(crews.crewById[id]!.code, fresh);

      await expectLater(
        as(stranger).joinByCode(old),
        throwsA(isA<FriendException>()),
      );
      expect(await as(stranger).joinByCode(fresh), id);
      await expectLater(
        as(stranger).issueCode(crews.crewById[id]!),
        throwsA(isA<FriendException>()),
      );
    });

    test('내보낸 사람은 코드로 못 들어와요. 다시 초대받아 들어오면 풀리고, 다시 내보내면 또 막혀요', () async {
      final id = await as(minji).create('주말 LSD', [haeun]);
      final code = crews.crewById[id]!.code!;
      final b = as(haeun)..start();
      await settle();
      await b.accept(b.invites.single);

      // 1. 내보내면 코드로 못 들어와요.
      await as(minji).kick(crews.crewById[id]!, haeun.uid);
      await expectLater(
        as(haeun).joinByCode(code),
        throwsA(
          isA<FriendException>().having(
            (e) => e.message,
            'message',
            '이 크루에는 코드로 들어갈 수 없어요',
          ),
        ),
      );

      // 2. 크루장이 다시 초대해 수락하면 막힘이 풀려요.
      await as(minji).invite(crews.crewById[id]!, haeun);
      final again = as(haeun)..start();
      await settle();
      await again.accept(again.invites.single);
      expect(crews.bannedById[id], isNot(contains(haeun.uid)));

      // 3. 스스로 나간 뒤에는 코드로 다시 들어올 수 있어요.
      await again.leave(crews.crewById[id]!);
      expect(await as(haeun).joinByCode(code), id);

      // 4. 다시 내보내면 또 막혀요.
      await as(minji).kick(crews.crewById[id]!, haeun.uid);
      await expectLater(
        as(haeun).joinByCode(code),
        throwsA(isA<FriendException>()),
      );
    });

    test('새로 들어온 사람은 들어온 뒤의 채팅만 보고, 다시 들어오면 그때부터 봐요', () async {
      final a = as(minji);
      final id = await a.create('주말 LSD', const []);
      final code = crews.crewById[id]!.code!;
      await a.send(id, '들어오기 전 이야기');

      final b = as(stranger);
      await b.joinByCode(code);
      await settle();
      var seen = await b.messages(id).first;
      expect(seen.map((m) => m.kind), [CrewMessageKind.join]);
      // 목록 미리보기에도 들어오기 전 메시지는 안 보여요.
      await b.refresh();
      await settle();
      expect(b.lastMessageOf(b.byId(id)!), isNull);

      await a.send(id, '어서 와요');
      seen = await b.messages(id).first;
      expect(seen.map((m) => m.text), ['', '어서 와요']);
      await b.refresh();
      await settle();
      expect(b.lastMessageOf(b.byId(id)!)?.text, '어서 와요');

      // 나갔다가 다시 들어오면 다시 들어온 때부터예요.
      await b.leave(b.byId(id)!);
      await a.send(id, '나간 동안 이야기');
      await as(stranger).joinByCode(code);
      seen = await b.messages(id).first;
      expect(seen.map((m) => m.kind), [CrewMessageKind.join]);
    });

    test('크루장과 차단 관계면 코드로 못 들어와요', () async {
      final id = await as(minji).create('주말 LSD', const []);
      server.blocks[minji.uid] = {stranger.uid};
      await expectLater(
        as(stranger).joinByCode(crews.crewById[id]!.code!),
        throwsA(isA<FriendException>()),
      );
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
      // 서버 함수(코드 만들기·코드로 들어가기)를 부르는 사람은 김민지예요.
      crews.actor = minji.uid;
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

    testWidgets('나가자마자 서버 소식이 먼저 와도 채팅방만 닫혀요(검은 화면 방지)', (tester) async {
      await tester.runAsync(() async {
        final id = await crewStore.create('주말 LSD', [haeun]);
        final b = storeFor(haeun)..start();
        await settle();
        await b.accept(b.invites.single);
        expect(crews.crewById[id]!.members, hasLength(2));
      });
      crews.notifyBeforeDone = true;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // 앱처럼 친구 탭 아래에 다른 화면(바닥)이 깔린 상태에서 시작합니다.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FriendsPage(
                        store: friends,
                        crew: crewStore,
                        together: TogetherStore(
                          backend: server,
                          me: () => minji,
                          records: () async => const [],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('바닥 화면'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('바닥 화면'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('^주말 LSD 크루 채팅방')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('채팅방 메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('김민지 님'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, '나가기'));
      await tester.pumpAndSettle();
      // 한 번 더 물어봐요.
      expect(find.text('정말 나갈까요?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('나가기'),
        ),
      );
      await tester.pumpAndSettle();

      // 직접 나갔으니 강제퇴장 안내는 뜨지 않아요.
      expect(find.text('강제퇴장됐어요'), findsNothing);
      // 크루 목록(친구 탭)으로 돌아오고, 바닥 화면까지 닫히지 않아요.
      expect(find.text('크루 만들기'), findsOneWidget);
      expect(find.text('바닥 화면'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('채팅방을 보는 중에 내보내지면 강제퇴장 안내가 뜨고, 확인하면 크루 목록으로 가요', (
      tester,
    ) async {
      late CrewStore owner;
      late String id;
      await tester.runAsync(() async {
        owner = storeFor(haeun);
        id = await owner.create('주말 LSD', [minji]);
        crewStore.start();
        await settle();
        await crewStore.accept(crewStore.invites.single);
        await settle();
      });
      await open(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^주말 LSD 크루 채팅방')));
      await tester.pumpAndSettle();
      expect(find.text('강제퇴장됐어요'), findsNothing);

      await tester.runAsync(() async {
        await owner.kick(crews.crewById[id]!, minji.uid);
        await settle();
      });
      await tester.pumpAndSettle();
      expect(find.text('강제퇴장됐어요'), findsOneWidget);
      expect(find.textContaining("'주말 LSD' 크루에서 내보냈어요"), findsOneWidget);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('강제퇴장됐어요'), findsNothing);
      expect(find.text('크루 만들기'), findsOneWidget);
      expect(find.byTooltip('채팅방 메뉴'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('내보내기와 나가기는 한 번 더 묻고, 취소하면 그대로예요', (tester) async {
      late String id;
      await tester.runAsync(() async {
        id = await crewStore.create('주말 LSD', [haeun]);
        final b = storeFor(haeun)..start();
        await settle();
        await b.accept(b.invites.single);
        await settle();
      });
      await open(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^주말 LSD 크루 채팅방')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('채팅방 메뉴'));
      await tester.pumpAndSettle();

      // 내보내기: 두 번째 창에서 취소하면 그대로예요.
      await tester.tap(find.byTooltip('박하은 님 내보내기'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '내보내기'));
      await tester.pumpAndSettle();
      expect(find.text('정말 내보낼까요?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('취소'),
        ),
      );
      await tester.pumpAndSettle();
      expect(crews.crewById[id]!.members, contains(haeun.uid));

      // 나가기: 두 번째 창에서 취소해도 그대로예요.
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '나가기'));
      await tester.pumpAndSettle();
      expect(find.text('정말 나갈까요?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('취소'),
        ),
      );
      await tester.pumpAndSettle();
      expect(crews.crewById[id]!.members, contains(minji.uid));

      // 두 번 다 누르면 내보내요.
      await tester.tap(find.byTooltip('박하은 님 내보내기'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '내보내기'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('내보내기'),
        ),
      );
      await tester.pumpAndSettle();
      expect(crews.crewById[id]!.members, [minji.uid]);
    });

    testWidgets('알림 버튼은 글자 없이 종 모양으로 지금 상태를 보여 줘요', (tester) async {
      late String id;
      await tester.runAsync(() async {
        id = await crewStore.create('주말 LSD', const []);
      });
      await open(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^주말 LSD 크루 채팅방')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('채팅방 메뉴'));
      await tester.pumpAndSettle();
      expect(find.text('알림 끄기'), findsNothing);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('크루 알림 켜짐, 눌러서 끄기'));
      await tester.pumpAndSettle();
      expect(crewStore.muted(id), isTrue);
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
      expect(find.bySemanticsLabel('크루 알림 꺼짐, 눌러서 켜기'), findsOneWidget);
    });

    testWidgets('서랍에 초대 코드가 보이고, 코드가 없던 크루는 크루장이 열면 생기고, 바꿀 수 있어요', (
      tester,
    ) async {
      late String id;
      await tester.runAsync(() async {
        // 코드를 못 만든 예전 크루처럼 만듭니다.
        crews.actor = '';
        id = await crewStore.create('주말 LSD', const []);
        crews.actor = minji.uid;
      });
      expect(crews.crewById[id]!.code, isNull);
      await open(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^주말 LSD 크루 채팅방')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('채팅방 메뉴'));
      await tester.pumpAndSettle();

      final code = crews.crewById[id]!.code!;
      expect(find.text(code), findsOneWidget);
      expect(find.text('친구가 아니어도 이 코드로 들어올 수 있어요'), findsOneWidget);
      // 복사한 글자를 받아 둡니다(테스트에는 진짜 클립보드가 없어서).
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.byTooltip('코드 복사'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(copied, code);
      expect(find.text('코드를 복사했어요'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byTooltip('코드 바꾸기'));
      await tester.pumpAndSettle();
      expect(find.text('초대 코드를 바꿀까요?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '바꾸기'));
      await tester.pumpAndSettle();
      final fresh = crews.crewById[id]!.code!;
      expect(fresh, isNot(code));
      expect(find.text(fresh), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('크루 탭에서 코드를 넣으면 그 크루 채팅방이 열려요(친구가 아니어도)', (tester) async {
      late String code;
      await tester.runAsync(() async {
        crews.actor = seojun.uid;
        final id = await storeFor(seojun).create('반포 저녁런', const []);
        code = crews.crewById[id]!.code!;
        crews.actor = minji.uid;
      });
      await open(tester);
      await tester.tap(find.text('코드로 참가'));
      await tester.pumpAndSettle();
      // 창 제목과 버튼 두 곳에 같은 이름이 보여요.
      expect(find.text('코드로 참가'), findsNWidgets(2));
      expect(find.text('코드 6자리를 입력해 주세요'), findsOneWidget);

      // 틀린 코드면 안내가 떠요.
      await tester.enterText(find.byType(TextField), 'zzzzzz');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '들어가기'));
      await tester.pumpAndSettle();
      expect(find.text('코드를 다시 확인해 주세요'), findsOneWidget);

      // 소문자로 쳐도 대문자로 바뀌어 들어가요.
      await tester.enterText(find.byType(TextField), code.toLowerCase());
      await tester.pump();
      expect(find.text(code), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기'));
      await tester.pumpAndSettle();
      expect(find.byType(CrewRoomPage), findsOneWidget);
      expect(find.text('김민지 님이 들어왔어요'), findsOneWidget);
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
      // 한 번 더 물어봐요.
      expect(find.text('정말 나갈까요?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('나가기'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('아직 크루가 없어요'), findsOneWidget);
      expect(crews.crewById, isEmpty);
    });
  });
}
