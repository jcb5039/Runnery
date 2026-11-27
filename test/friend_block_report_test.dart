import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/friends_page.dart';

import 'support/fake_friend_backend.dart';

/// 친구 탭(추가 수정): 위쪽 메뉴, 친구 달력, 신고·차단.
void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');
  const seojun = PublicProfile(uid: 'u3', name: '이서준', id: 'seojun_k');
  final now = DateTime(2026, 10, 24, 12);

  late FakeFriendBackend server;
  late FriendStore store;

  FeedPost post(String id, PublicProfile owner, DateTime at, double km) =>
      FeedPost(
        ownerUid: owner.uid,
        recordId: id,
        startedAt: at,
        distanceKm: km,
        movingSeconds: 3252,
        paceSeconds: 325,
        kcal: 640,
        area: '반포 한강공원',
        shape: const [(0, 0), (1, 1)],
      );

  setUp(() {
    server = FakeFriendBackend()
      ..profilesByUid[minji.uid] = minji
      ..profilesByUid[haeun.uid] = haeun
      ..profilesByUid[seojun.uid] = seojun
      ..friends[minji.uid] = {haeun.uid, seojun.uid}
      ..friends[haeun.uid] = {minji.uid}
      ..friends[seojun.uid] = {minji.uid}
      ..postsByOwner[haeun.uid] = {
        'h1': post('h1', haeun, DateTime(2026, 10, 24, 7, 12), 6.02),
      }
      ..postsByOwner[seojun.uid] = {
        's1': post('s1', seojun, DateTime(2026, 10, 23, 21, 3), 10),
        's2': post('s2', seojun, DateTime(2026, 10, 2, 7), 5),
        's0': post('s0', seojun, DateTime(2026, 9, 30, 7), 4),
      };
    store = FriendStore(backend: server, me: () => minji, clock: () => now);
  });

  group('저장소', () {
    test('차단하면 친구·요청이 지워지고, 찾기와 받은 요청에서 빠져요', () async {
      server.requests.add((seojun.uid, minji.uid));
      await store.refresh();
      await store.block(seojun);

      expect(server.blocks[minji.uid], {seojun.uid});
      expect(server.friends[minji.uid], {haeun.uid});
      expect(server.friends[seojun.uid], isEmpty);
      expect(server.requests, isEmpty);
      expect(store.friends.map((f) => f.uid), [haeun.uid]);
      expect(store.feed.map((f) => f.friend.uid), [haeun.uid]);
      expect(store.blocked.map((p) => p.uid), [seojun.uid]);
      expect(await store.search('서준'), isEmpty);

      // 차단당한 사람은 다시 친구 요청을 보낼 수 없어요.
      final other = FriendStore(backend: server, me: () => seojun);
      await other.refresh();
      expect(() => other.sendRequest(minji), throwsA(isA<FriendException>()));

      await store.unblock(seojun.uid);
      expect(store.blocked, isEmpty);
      expect(server.blocks[minji.uid], isEmpty);
      // 차단을 풀어도 친구로 돌아오지 않아요.
      expect(server.friends[minji.uid], {haeun.uid});
    });

    test('신고는 사유와 내용(300자까지)을 올려요', () async {
      await store.refresh();
      await store.report(
        haeun,
        ReportReason.fakeRecord,
        detail: '  ${'가' * 400}  ',
        recordId: 'h1',
      );
      final report = server.reports.single;
      expect(report.reporter, minji.uid);
      expect(report.target, haeun.uid);
      expect(report.reason, ReportReason.fakeRecord);
      expect(report.detail.length, 300);
      expect(report.recordId, 'h1');
    });

    test('친구 달력은 그 달에 공유한 기록만 가져와요', () async {
      await store.refresh();
      final october = await store.monthPosts(seojun.uid, DateTime(2026, 10));
      expect(october.map((p) => p.recordId), ['s1', 's2']);
    });
  });

  group('화면', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: FriendsPage(store: store)));
      await tester.pumpAndSettle();
    }

    testWidgets('위쪽 메뉴는 친구 · 함께 달리기 · 크루예요', (tester) async {
      await open(tester);
      expect(find.text('친구'), findsWidgets);
      expect(find.text('함께 달리기'), findsOneWidget);
      expect(find.text('크루'), findsOneWidget);
      expect(find.text('랭킹'), findsNothing);
      expect(find.text('목표'), findsNothing);

      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle();
      expect(find.text('크루는 준비 중이에요'), findsOneWidget);
    });

    testWidgets('친구 이름을 누르면 그 친구의 달력이 열려요', (tester) async {
      await open(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^이서준 님 러닝 달력 보기')).first);
      await tester.pumpAndSettle();

      expect(find.text('이서준 님의 러닝'), findsOneWidget);
      expect(find.text('10월에 2번 달렸어요 · 15.00 km'), findsOneWidget);
      expect(find.text('2026년 10월'), findsOneWidget);
      // 가장 최근에 달린 날(23일)이 골라져 있어요.
      expect(find.text('10월 23일 금요일'), findsOneWidget);
      expect(find.text('10.00km'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp('^10월 2일, 러닝 1건')));
      await tester.pumpAndSettle();
      expect(find.text('10월 2일 금요일'), findsOneWidget);

      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(find.text('9월에 1번 달렸어요 · 4.00 km'), findsOneWidget);
    });

    testWidgets('신고하기: 사유를 골라야 보낼 수 있고, 보내면 접수 안내가 떠요', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('박하은 님 더보기 · 신고 · 차단'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('신고하기'));
      await tester.pumpAndSettle();

      expect(find.text('박하은 님을 신고해요'), findsOneWidget);
      final submit = find.widgetWithText(FilledButton, '신고하기');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);

      await tester.tap(find.text('스팸 · 광고'));
      await tester.enterText(find.byType(TextField), '광고만 올려요');
      await tester.pump();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('신고가 접수됐어요'), findsOneWidget);
      expect(server.reports.single.reason, ReportReason.spam);
      expect(server.reports.single.detail, '광고만 올려요');

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('박하은 님을 신고해요'), findsNothing);
    });

    testWidgets('차단하면 카드가 사라지고, 되돌리기를 누르면 차단하지 않아요', (tester) async {
      await open(tester);
      Future<void> startBlock() async {
        await tester.tap(find.byTooltip('박하은 님 더보기 · 신고 · 차단'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('차단하기'));
        await tester.pumpAndSettle();
        expect(find.text('박하은 님을 차단할까요?'), findsOneWidget);
        await tester.tap(find.text('박하은 님 차단하기'));
        await tester.pumpAndSettle();
      }

      await startBlock();
      expect(find.text('박하은 님을 차단했어요'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^박하은 님의 러닝')), findsNothing);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('^박하은 님의 러닝')), findsOneWidget);
      expect(server.blocks[minji.uid], isNull);

      await startBlock();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(server.blocks[minji.uid], {haeun.uid});
      expect(server.friends[minji.uid], {seojun.uid});
      expect(find.bySemanticsLabel(RegExp('^박하은 님의 러닝')), findsNothing);
    });
  });
}
