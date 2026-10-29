import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/together_live.dart';
import 'package:runnery_new/friends/data/together_store.dart';
import 'package:runnery_new/record/models/running_record.dart';

import 'support/fake_friend_backend.dart';

void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');

  late DateTime now;
  late FakeFriendBackend server;
  setUp(() {
    now = DateTime(2026, 10, 29, 19);
    server = FakeFriendBackend()
      ..clock = (() => now)
      ..friends[minji.uid] = {haeun.uid}
      ..friends[haeun.uid] = {minji.uid}
      ..profilesByUid[minji.uid] = minji
      ..profilesByUid[haeun.uid] = haeun;
  });

  TogetherStore storeFor(PublicProfile me) => TogetherStore(
    backend: server,
    me: () => me,
    records: () async => const [],
    clock: () => now,
  );

  /// 민지가 '지금 바로 같이 뛰기'를 보내고 하은이 수락한 뒤 함께 시작합니다.
  Future<(TogetherStore, TogetherStore)> runTogether() async {
    final a = storeFor(minji), b = storeFor(haeun);
    await a.startNow([haeun]);
    await b.refresh();
    await b.answer(b.requests.single, TogetherStatus.accepted);
    await server.startTogether('t1');
    await a.refresh();
    return (a, b);
  }

  testWidgets('shares my run every 5 seconds with route points 15 m apart', (
    tester,
  ) async {
    final (a, _) = await runTogether();
    final live = TogetherLive('t1', store: a, clock: () => now)..start();
    addTearDown(live.dispose);

    live
      ..update(
        meters: 1200,
        moving: const Duration(seconds: 420),
        paused: false,
        position: (37.5, 127.0),
        routePoint: (37.5, 127.0),
      )
      // 5m쯤 움직인 점은 지나간 길에 더하지 않습니다.
      ..update(
        meters: 1205,
        moving: const Duration(seconds: 422),
        paused: false,
        position: (37.50005, 127.0),
        routePoint: (37.50005, 127.0),
      );
    expect(server.liveWrites, 0);
    await tester.pump(TogetherLive.interval);
    var mine = server.liveById['t1']![minji.uid]!;
    expect(mine.distanceKm, 1.21);
    expect(mine.movingSeconds, 422);
    expect(mine.position, (37.50005, 127.0));
    expect(mine.route, [(37.5, 127.0)]);

    // 20m 넘게 움직이면 점이 늘고, 새 점만 서버에 붙습니다.
    live.update(
      meters: 1230,
      moving: const Duration(seconds: 430),
      paused: false,
      position: (37.5002, 127.0),
      routePoint: (37.5002, 127.0),
    );
    now = now.add(TogetherLive.interval);
    await tester.pump(TogetherLive.interval);
    mine = server.liveById['t1']![minji.uid]!;
    expect(mine.route, [(37.5, 127.0), (37.5002, 127.0)]);

    // 바뀐 게 없으면(멈춰 있으면) 15초마다 한 번만 올립니다.
    final writes = server.liveWrites;
    now = now.add(TogetherLive.interval);
    await tester.pump(TogetherLive.interval);
    expect(server.liveWrites, writes);
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    expect(server.liveWrites, writes + 1);

    // 끝내면 내 위치·지나간 길을 지웁니다.
    await live.close();
    expect(server.liveById['t1'], isEmpty);
  });

  testWidgets('friends show as waiting, running, paused, lost and finished', (
    tester,
  ) async {
    final (a, b) = await runTogether();
    final watching = TogetherLive('t1', store: b, clock: () => now)..start();
    addTearDown(watching.dispose);
    await tester.pump();
    expect(watching.friends.single.name, '김민지');
    expect(watching.friends.single.state, LiveFriendState.waiting);

    await server.setTogetherLive(
      't1',
      LiveRun(
        uid: minji.uid,
        distanceKm: 2.31,
        movingSeconds: 860,
        position: (37.5, 127.0),
        route: const [(37.5, 127.0), (37.5002, 127.0)],
      ),
    );
    await tester.pump();
    var friend = watching.friends.single;
    expect(friend.state, LiveFriendState.running);
    expect(friend.run!.paceSeconds, 372);
    expect(friend.run!.route, hasLength(2));

    await server.setTogetherLive(
      't1',
      LiveRun(
        uid: minji.uid,
        distanceKm: 2.31,
        movingSeconds: 860,
        paused: true,
        position: (37.5002, 127.0),
        route: const [(37.5, 127.0), (37.5002, 127.0)],
      ),
      sentPoints: 2,
    );
    await tester.pump();
    expect(watching.friends.single.state, LiveFriendState.paused);
    expect(watching.friends.single.run!.route, hasLength(2));

    // 30초 넘게 소식이 없으면 '신호 없음'.
    now = now.add(const Duration(seconds: 31));
    expect(watching.friends.single.state, LiveFriendState.lost);

    // 끝내고 결과를 올리면 '끝났어요'가 되고, 서버의 실시간 위치는 지워집니다.
    await a.runFinished(
      't1',
      RunningRecord(
        id: 'r1',
        startedAt: now.subtract(const Duration(minutes: 30)),
        distanceKm: 5.12,
        movingSeconds: 1900,
        calories: 310,
        route: const [],
      ),
    );
    await tester.pump();
    friend = watching.friends.single;
    expect(friend.state, LiveFriendState.finished);
    expect(friend.result!.distanceKm, 5.12);
    expect(server.liveById['t1'], isNot(contains(minji.uid)));
    await watching.close();
  });

  test('people who did not accept are not shown', () async {
    final a = storeFor(minji);
    await a.startNow([haeun]);
    final live = TogetherLive('t1', store: a, clock: () => now)..start();
    addTearDown(live.dispose);
    await pumpEventQueue();
    expect(live.friends, isEmpty);
  });
}
