import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/crew_store.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/notifications/friend_request_banner.dart';

import 'support/fake_crew_backend.dart';
import 'support/fake_friend_backend.dart';

/// 앱을 켜 둔 동안 새 친구 요청이 오면 위에서 띠가 내려와요.
void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');
  const seojun = PublicProfile(uid: 'u3', name: '이서준', id: 'seojun_k');

  late FakeFriendBackend server;
  late FriendStore store;

  setUp(() {
    server = FakeFriendBackend()
      ..profilesByUid[minji.uid] = minji
      ..profilesByUid[haeun.uid] = haeun
      ..profilesByUid[seojun.uid] = seojun
      // 앱을 켜기 전에 와 있던 요청.
      ..requests.add((seojun.uid, minji.uid));
    store = FriendStore(backend: server, me: () => minji);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FriendRequestListener(
          store: store,
          child: const Scaffold(body: Text('홈')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> sendFrom(WidgetTester tester, PublicProfile from) async {
    server
      ..requests.add((from.uid, minji.uid))
      ..requestsChanged();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('새 요청이 오면 띠가 뜨고, 4초 뒤 사라져요', (tester) async {
    await open(tester);
    // 이미 와 있던 요청은 띠 없이 빨간 점으로만 알려요.
    expect(find.textContaining('친구 요청을 보냈어요'), findsNothing);
    expect(store.incoming.map((p) => p.uid), [seojun.uid]);

    await sendFrom(tester, haeun);
    expect(find.text('박하은 님이 친구 요청을 보냈어요'), findsOneWidget);
    expect(store.incoming.map((p) => p.uid), contains(haeun.uid));

    await tester.pump(FriendRequestListener.showFor);
    await tester.pumpAndSettle();
    expect(find.text('박하은 님이 친구 요청을 보냈어요'), findsNothing);
  });

  testWidgets('띠를 누르면 알림 화면이 열려요', (tester) async {
    await open(tester);
    await sendFrom(tester, haeun);
    await tester.tap(find.text('박하은 님이 친구 요청을 보냈어요'));
    await tester.pumpAndSettle();

    expect(find.text('알림'), findsOneWidget);
    expect(find.text('친구 요청'), findsOneWidget);
    expect(find.bySemanticsLabel('박하은 님 요청 수락'), findsOneWidget);
  });

  testWidgets('차단한 사람의 요청은 띠를 띄우지 않아요', (tester) async {
    server.blocks[minji.uid] = {haeun.uid};
    await store.refresh();
    await open(tester);
    await sendFrom(tester, haeun);
    expect(find.textContaining('친구 요청을 보냈어요'), findsNothing);
    expect(store.incoming.map((p) => p.uid), isNot(contains(haeun.uid)));
  });

  group('크루 초대', () {
    late FakeCrewBackend crews;
    late CrewStore crew;

    setUp(() {
      // 크루 초대는 친구에게만 보낼 수 있어요.
      server.friends
        ..[haeun.uid] = {minji.uid}
        ..[seojun.uid] = {minji.uid};
      crews = FakeCrewBackend(server);
      crew = CrewStore(backend: crews, me: () => minji);
    });

    Future<void> openWithCrew(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FriendRequestListener(
            store: store,
            crew: crew,
            child: const Scaffold(body: Text('홈')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> inviteFrom(
      WidgetTester tester,
      PublicProfile from,
      String name,
    ) async {
      await tester.runAsync(
        () => CrewStore(backend: crews, me: () => from).create(name, [minji]),
      );
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('새 크루 초대가 오면 띠가 뜨고, 누르면 알림 화면이 열려요', (tester) async {
      await openWithCrew(tester);
      await inviteFrom(tester, haeun, '주말 LSD');
      expect(find.text("박하은 님이 '주말 LSD' 크루에 초대했어요"), findsOneWidget);

      await tester.tap(find.text("박하은 님이 '주말 LSD' 크루에 초대했어요"));
      await tester.pumpAndSettle();
      expect(find.text('알림'), findsOneWidget);
      expect(find.textContaining('주말 LSD'), findsWidgets);
    });

    testWidgets('앱을 켤 때 와 있던 크루 초대는 띠를 띄우지 않아요', (tester) async {
      await tester.runAsync(
        () => CrewStore(
          backend: crews,
          me: () => seojun,
        ).create('반포 저녁런', [minji]),
      );
      await openWithCrew(tester);
      expect(find.textContaining('크루에 초대했어요'), findsNothing);

      await tester.pump(FriendRequestListener.showFor);
      await tester.pumpAndSettle();
      expect(find.textContaining('크루에 초대했어요'), findsNothing);
    });
  });
}
