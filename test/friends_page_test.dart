import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/friends_page.dart';

import 'support/fake_friend_backend.dart';

void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');
  const seojun = PublicProfile(uid: 'u3', name: '이서준', id: 'seojun_k');

  late FakeFriendBackend server;
  late FriendStore store;

  setUp(() {
    server = FakeFriendBackend()
      ..profilesByUid[haeun.uid] = haeun
      ..profilesByUid[seojun.uid] = seojun
      ..requests.add((haeun.uid, minji.uid));
    store = FriendStore(
      backend: server,
      me: () => minji,
      records: () async => const [],
    );
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: FriendsPage(store: store)));
    await tester.pumpAndSettle();
  }

  testWidgets('received request can be accepted from the banner', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('친구를 추가하고 함께 달려요'), findsOneWidget);
    await tester.tap(find.text('확인하기'));
    await tester.pumpAndSettle();

    expect(find.text('받은 친구 요청'), findsOneWidget);
    expect(find.text('1개'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('박하은 님 요청 수락'));
    await tester.pumpAndSettle();
    expect(find.text('친구가 됐어요'), findsOneWidget);
    expect(find.text('모두 확인했어요'), findsOneWidget);
    expect(server.friends[minji.uid], {haeun.uid});

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('아직 친구들이 공유한 러닝이 없어요'), findsOneWidget);
    expect(find.text('확인하기'), findsNothing);
  });

  testWidgets('search sends and cancels a friend request', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('친구 추가').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '서준');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('검색 결과'), findsOneWidget);
    expect(find.text('@seojun_k'), findsOneWidget);

    await tester.tap(find.text('친구 요청'));
    await tester.pumpAndSettle();
    expect(server.requests, contains((minji.uid, seojun.uid)));
    expect(find.text('요청됨'), findsOneWidget);

    await tester.tap(find.text('요청됨'));
    await tester.pumpAndSettle();
    expect(server.requests, isNot(contains((minji.uid, seojun.uid))));
  });

  testWidgets('friend list deletes after confirmation', (tester) async {
    server.friends[minji.uid] = {seojun.uid};
    server.friends[seojun.uid] = {minji.uid};
    await open(tester);
    await tester.tap(find.byTooltip('내 친구 목록'));
    await tester.pumpAndSettle();
    expect(find.text('친구 1명'), findsOneWidget);

    await tester.tap(find.byTooltip('이서준 님 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('친구 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('이서준 님을\n친구에서 삭제할까요?'), findsOneWidget);

    // 취소하면 그대로 둡니다.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(server.friends[minji.uid], {seojun.uid});

    await tester.tap(find.byTooltip('이서준 님 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('친구 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    expect(server.friends[minji.uid], isEmpty);
    expect(server.friends[seojun.uid], isEmpty);
    expect(find.text('친구 0명'), findsOneWidget);
  });
}
