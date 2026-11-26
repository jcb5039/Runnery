import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/together_store.dart';
import 'package:runnery_new/friends/friends_feature.dart';
import 'package:runnery_new/hamster/hamster_room_page.dart';
import 'package:runnery_new/hamster/roommate_feature.dart';
import 'package:runnery_new/home/home_page.dart';
import 'package:runnery_new/home/main_tabs.dart';
import 'package:runnery_new/record/list/record_list_page.dart';

import 'support/fake_friend_backend.dart';

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
    'friend tab shows how many invites wait for an answer',
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
      expect(find.text('1'), findsOneWidget);

      // 답하면 배지가 바로 사라집니다.
      final store = TogetherStore.instance;
      await store.answer(store.requests.single, TogetherStatus.accepted);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNothing);
    },
  );
}
