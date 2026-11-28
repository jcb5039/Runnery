import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/crew/crew_room_page.dart';
import 'package:runnery_new/friends/data/crew_store.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/together_store.dart';
import 'package:runnery_new/friends/friends_feature.dart';
import 'package:runnery_new/hamster/hamster_room_page.dart';
import 'package:runnery_new/hamster/roommate_feature.dart';
import 'package:runnery_new/home/home_page.dart';
import 'package:runnery_new/home/main_tabs.dart';
import 'package:runnery_new/record/list/record_list_page.dart';

import 'support/fake_crew_backend.dart';
import 'support/fake_friend_backend.dart';

/// 친구 탭 아이콘의 빨간 점.
final _dot = find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == '새 소식 있음',
);

void main() {
  testWidgets('tabs switch instantly, hide others and keep pages alive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: MainTabs()));
    await tester.pump();
    final home = tester.state(find.byType(HomePageV2));

    // 한 프레임 만에 기록만 보이고 홈은 그려지지 않습니다.
    await tester.tap(find.text('기록').last);
    await tester.pump();
    expect(find.byType(RecordListPageV2), findsOneWidget);
    expect(find.byType(HomePageV2), findsNothing);
    expect(find.byType(HomePageV2, skipOffstage: false), findsOneWidget);

    // 다시 홈으로 오면 처음 만든 화면을 그대로 씁니다.
    await tester.tap(find.text('홈').last);
    await tester.pump();
    expect(find.byType(RecordListPageV2), findsNothing);
    expect(tester.state(find.byType(HomePageV2)), same(home));
    expect(tester.takeException(), isNull);
  });

  testWidgets('without friends feature there is no friend tab', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: MainTabs()));
    await tester.pump();

    expect(find.text('친구'), findsNothing);
    // 세 번째 탭은 캐릭터(룸메이트) 미리보기, 네 번째 탭이 내 정보입니다.
    await tester.tap(find.text('룸메이트').last);
    await tester.pump();
    expect(find.byType(HamsterRoomPage), findsOneWidget);
    await tester.tap(find.text('내 정보').last);
    await tester.pump();
    expect(find.byType(HomePageV2), findsNothing);
    expect(find.byType(HamsterRoomPage), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: FriendsFeature.available || !RoommateFeature.available);

  testWidgets('roommate tab is hidden while the feature is off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: MainTabs()));
    await tester.pump();

    expect(find.text('룸메이트'), findsNothing);
    expect(find.byType(HamsterRoomPage, skipOffstage: false), findsNothing);
    // 마지막 탭인 내 정보로 가면 홈은 그려지지 않습니다.
    await tester.tap(find.text('내 정보').last);
    await tester.pump();
    expect(find.byType(HomePageV2), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: RoommateFeature.available);

  testWidgets(
    'friend tab shows a red dot while a together invite waits for an answer',
    skip: !FriendsFeature.available,
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
      const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');
      final now = DateTime(2026, 10, 29, 12);
      final server = FakeFriendBackend()
        ..clock = (() => now)
        ..profilesByUid[minji.uid] = minji
        ..profilesByUid[haeun.uid] = haeun;
      TogetherStore storeFor(PublicProfile me) => TogetherStore(
        backend: server,
        me: () => me,
        records: () async => const [],
        clock: () => now,
      );
      final before = TogetherStore.instance;
      TogetherStore.instance = storeFor(haeun);
      addTearDown(() => TogetherStore.instance = before);

      await tester.pumpWidget(const MaterialApp(home: MainTabs()));
      await tester.pump();
      await storeFor(minji).create([haeun], DateTime(2026, 10, 30, 20), 5);
      await tester.pumpAndSettle();
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(_dot, findsOneWidget);

      // 답하면 점이 바로 사라집니다.
      final store = TogetherStore.instance;
      await store.answer(store.requests.single, TogetherStatus.accepted);
      await tester.pumpAndSettle();
      expect(_dot, findsNothing);
    },
  );

  group('친구 탭 빨간 점과 크루 채팅 띠', skip: !FriendsFeature.available, () {
    const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
    const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');
    late FakeFriendBackend server;
    late FakeCrewBackend crews;
    late CrewStore owner;

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      server = FakeFriendBackend()
        ..profilesByUid[minji.uid] = minji
        ..profilesByUid[haeun.uid] = haeun
        ..friends[minji.uid] = {haeun.uid}
        ..friends[haeun.uid] = {minji.uid};
      crews = FakeCrewBackend(server);
      owner = CrewStore(backend: crews, me: () => minji);
      final friends = FriendStore.instance,
          crew = CrewStore.instance,
          together = TogetherStore.instance;
      FriendStore.instance = FriendStore(backend: server, me: () => haeun);
      CrewStore.instance = CrewStore(backend: crews, me: () => haeun);
      TogetherStore.instance = TogetherStore(
        backend: server,
        me: () => haeun,
        records: () async => const [],
      );
      addTearDown(() {
        FriendStore.instance = friends;
        CrewStore.instance = crew;
        TogetherStore.instance = together;
      });
      await tester.pumpWidget(const MaterialApp(home: MainTabs()));
      await tester.pumpAndSettle();
    }

    /// 크루를 만들어 박하은을 초대하고, 박하은이 수락합니다.
    Future<String> joinCrew(WidgetTester tester) async {
      final id = await owner.create('주말 LSD', [haeun]);
      await tester.pumpAndSettle();
      await CrewStore.instance.accept(CrewStore.instance.invites.single);
      await tester.pumpAndSettle();
      return id;
    }

    Future<void> say(WidgetTester tester, String id, String text) async {
      await owner.send(id, text);
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('크루 초대·친구 요청이 오면 친구 탭에 빨간 점이 붙어요', (tester) async {
      await open(tester);
      expect(_dot, findsNothing);

      await owner.create('주말 LSD', [haeun]);
      await tester.pumpAndSettle();
      expect(_dot, findsOneWidget);
      await CrewStore.instance.decline(CrewStore.instance.invites.single);
      await tester.pumpAndSettle();
      expect(_dot, findsNothing);

      server
        ..requests.add((minji.uid, haeun.uid))
        ..requestsChanged();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(_dot, findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('알림이 켜진 크루에 채팅이 오면 띠가 뜨고, 누르면 채팅방이 열려요', (tester) async {
      await open(tester);
      final id = await joinCrew(tester);
      expect(_dot, findsNothing);

      await say(tester, id, '오늘 8시에 만나요');
      // 크루 이름 없이 '보낸 사람: 내용'만 보여요.
      expect(find.text('주말 LSD'), findsNothing);
      expect(find.text('김민지: 오늘 8시에 만나요'), findsOneWidget);
      expect(_dot, findsOneWidget);

      await tester.tap(find.text('김민지: 오늘 8시에 만나요'));
      await tester.pumpAndSettle();
      expect(find.byType(CrewRoomPage), findsOneWidget);

      // 그 채팅방을 보고 있으면 띠를 띄우지 않아요.
      await say(tester, id, '물빛광장이에요');
      expect(find.text('김민지: 물빛광장이에요'), findsNothing);
      expect(find.text('물빛광장이에요'), findsOneWidget);
    });

    testWidgets('알림을 끈 크루는 띠 없이 빨간 점만 붙어요', (tester) async {
      await open(tester);
      final id = await joinCrew(tester);
      await CrewStore.instance.setMuted(id, muted: true);
      await tester.pumpAndSettle();

      await say(tester, id, '오늘 8시에 만나요');
      expect(find.text('김민지: 오늘 8시에 만나요'), findsNothing);
      expect(_dot, findsOneWidget);
    });
  });
}
