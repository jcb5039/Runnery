import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/together_store.dart';
import 'package:runnery_new/friends/friends_page.dart';

import 'support/fake_friend_backend.dart';

/// 친구 탭 알림 종: 받은 친구 요청과 함께 달리기 초대를 모아 보고 답합니다.
void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');
  const seojun = PublicProfile(uid: 'u3', name: '이서준', id: 'seojun_k');
  final now = DateTime(2026, 10, 24, 12);

  late FakeFriendBackend server;
  late FriendStore friends;
  late TogetherStore together;

  setUp(() async {
    server = FakeFriendBackend()
      ..profilesByUid[minji.uid] = minji
      ..profilesByUid[haeun.uid] = haeun
      ..profilesByUid[seojun.uid] = seojun
      ..friends[minji.uid] = {seojun.uid}
      ..friends[seojun.uid] = {minji.uid}
      ..requests.add((haeun.uid, minji.uid));
    server.clock = () => now;
    // 이서준 님이 함께 달리자고 보낸 약속.
    await TogetherStore(
      backend: server,
      me: () => seojun,
      records: () async => const [],
      clock: () => now,
    ).create([minji], DateTime(2026, 10, 26, 20), 5);
    friends = FriendStore(backend: server, me: () => minji, clock: () => now);
    together = TogetherStore(
      backend: server,
      me: () => minji,
      records: () async => const [],
      clock: () => now,
    );
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsPage(store: friends, together: together),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('알림 종에 새 알림 수가 붙고, 눌러서 친구 요청과 초대에 답해요', (tester) async {
    await open(tester);
    expect(find.byTooltip('알림 · 새 알림 2개'), findsOneWidget);

    await tester.tap(find.byTooltip('알림 · 새 알림 2개'));
    await tester.pumpAndSettle();
    expect(find.text('친구 요청'), findsOneWidget);
    expect(find.text('함께 달리기 초대'), findsOneWidget);
    expect(find.text('이서준 님이 함께 달리자고 해요'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('박하은 님 요청 수락'));
    await tester.pumpAndSettle();
    expect(find.text('친구가 됐어요'), findsOneWidget);
    expect(server.friends[minji.uid], contains(haeun.uid));

    await tester.tap(find.text('수락'));
    await tester.pumpAndSettle();
    expect(find.text('이서준 님과의 약속을 수락했어요'), findsOneWidget);
    expect(together.active, hasLength(1));

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('알림'), findsOneWidget);
  });

  testWidgets('알림이 없으면 빨간 점 없이 빈 안내가 보여요', (tester) async {
    server.requests.clear();
    server.togetherById.clear();
    await open(tester);
    expect(find.byTooltip('알림'), findsOneWidget);

    await tester.tap(find.byTooltip('알림'));
    await tester.pumpAndSettle();
    expect(find.text('받은 친구 요청이 없어요'), findsOneWidget);
    expect(find.text('받은 함께 달리기 초대가 없어요'), findsOneWidget);
  });
}
