import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/crew/crew_run_pages.dart';
import 'package:runnery_new/friends/data/crew_store.dart';
import 'package:runnery_new/friends/data/friend_models.dart' show LiveRun;
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/together_live.dart';
import 'package:runnery_new/record/models/running_record.dart';

import 'support/fake_crew_backend.dart';
import 'support/fake_friend_backend.dart';

/// 크루 3-3: 함께 카운트다운 → 러닝, 같은 모집 사람만 지도에, 각자 끝내기, 팀장의 팀 끝내기.
void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');
  const seojun = PublicProfile(uid: 'u3', name: '이서준', id: 'seojun_k');

  late FakeFriendBackend server;
  late FakeCrewBackend crews;
  late String crewId;
  var tick = DateTime(2026, 10, 24, 20);
  DateTime now() => tick = tick.add(const Duration(seconds: 30));

  CrewStore storeFor(PublicProfile me) =>
      CrewStore(backend: crews, me: () => me, clock: () => tick);

  Future<T> as<T>(PublicProfile who, Future<T> Function() task) {
    crews.actor = who.uid;
    return task();
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// 김민지(팀장)가 연 모집에 박하은·이서준이 들어와 모두 준비한 상태.
  Future<String> readyRun() async {
    server = FakeFriendBackend()
      ..profilesByUid[minji.uid] = minji
      ..profilesByUid[haeun.uid] = haeun
      ..profilesByUid[seojun.uid] = seojun
      ..friends[minji.uid] = {haeun.uid, seojun.uid}
      ..friends[haeun.uid] = {minji.uid}
      ..friends[seojun.uid] = {minji.uid};
    crews = FakeCrewBackend(server)..clock = now;
    crewId = await storeFor(minji).create('여의도 퇴근런', [haeun, seojun]);
    for (final p in [haeun, seojun]) {
      final s = storeFor(p)..start();
      await settle();
      await s.accept(s.invites.single);
    }
    final id = await as(
      minji,
      () => storeFor(minji).openRun(crewId, '물빛광장 5 km'),
    );
    for (final p in [haeun, seojun]) {
      final s = storeFor(p);
      await as(p, () => s.joinRun(crews.runs['$crewId/$id']!));
      await as(p, () => s.setRunReady(crews.runs['$crewId/$id']!, ready: true));
    }
    return id;
  }

  CrewRun runOf(String id) => crews.runs['$crewId/$id']!;

  group('저장소', () {
    test('팀장만 시작하고, 모두 끝내면 팀 기록이 저절로 끝나요', () async {
      final id = await readyRun();
      expect(
        () => as(haeun, () => storeFor(haeun).startRun(runOf(id))),
        throwsA(isA<FriendException>()),
      );
      await as(minji, () => storeFor(minji).startRun(runOf(id)));
      expect(runOf(id).isStarted, isTrue);

      for (final (p, km) in [(minji, 5.0), (haeun, 4.2), (seojun, 6.1)]) {
        await as(
          p,
          () => storeFor(p).finishRun(
            crewId,
            id,
            recordId: 'r-${p.uid}',
            distanceKm: km,
            movingSeconds: 1800,
            kcal: 300,
          ),
        );
      }
      expect(runOf(id).isEnded, isTrue);
      expect(runOf(id).team[haeun.uid]!.finished, isTrue);
      expect(runOf(id).teamKm, closeTo(15.3, .001));
      expect(crews.runnerLocks, isEmpty);
    });

    test('팀장이 팀을 끝내면 아직 달리는 사람은 그때의 기록으로 남고, 계속 달릴 수 있어요', () async {
      final id = await readyRun();
      await as(minji, () => storeFor(minji).startRun(runOf(id)));
      await as(
        minji,
        () => storeFor(minji).finishRun(
          crewId,
          id,
          recordId: 'r1',
          distanceKm: 5,
          movingSeconds: 1500,
          kcal: 300,
        ),
      );
      // 박하은은 달리는 중(실시간 4.1 km).
      await crews.setRunLive(
        crewId,
        id,
        const LiveRun(
          uid: 'u2',
          distanceKm: 4.1,
          movingSeconds: 1400,
          paused: false,
        ),
      );
      expect(
        () => as(haeun, () => storeFor(haeun).endTeam(crewId, id)),
        throwsA(isA<FriendException>()),
      );
      await as(minji, () => storeFor(minji).endTeam(crewId, id));
      final ended = runOf(id);
      expect(ended.isEnded, isTrue);
      expect(ended.team[haeun.uid]!.distanceKm, 4.1);
      expect(ended.team[haeun.uid]!.finished, isFalse);

      // 나중에 끝내도 내 기록은 남고 팀 기록은 그대로예요.
      await as(
        haeun,
        () => storeFor(haeun).finishRun(
          crewId,
          id,
          recordId: 'r2',
          distanceKm: 7,
          movingSeconds: 2400,
          kcal: 400,
        ),
      );
      expect(runOf(id).results[haeun.uid]!.distanceKm, 7);
      expect(runOf(id).team[haeun.uid]!.distanceKm, 4.1);
      // 팀이 끝나면 다음 모집을 열 수 있어요.
      await as(minji, () => storeFor(minji).openRun(crewId, '다음 모집'));
    });

    test('달리는 동안 같은 모집 사람들의 위치만 받아요', () async {
      final id = await readyRun();
      await as(minji, () => storeFor(minji).startRun(runOf(id)));
      final store = storeFor(haeun);
      final live = TogetherLive.channel(
        store.liveChannel(crewId, id),
        clock: () => tick,
      )..start();
      addTearDown(live.dispose);
      await crews.setRunLive(
        crewId,
        id,
        const LiveRun(
          uid: 'u1',
          distanceKm: 1.2,
          movingSeconds: 400,
          paused: false,
          position: (37.52, 126.93),
        ),
      );
      await store.loadPeople([minji.uid, seojun.uid]);
      await settle();
      final friends = live.friends;
      expect(friends.map((f) => f.uid), [minji.uid, seojun.uid]);
      expect(friends.first.name, '김민지');
      expect(friends.first.run!.distanceKm, 1.2);
      expect(friends.last.state, LiveFriendState.waiting);
    });
  });

  test('크루와 함께 달린 기록은 크루 이름을 저장하고, 예전 기록도 그대로 열려요', () {
    final plain = RunningRecord(
      id: 'r1',
      startedAt: DateTime(2026, 10, 24, 20),
      distanceKm: 5,
      movingSeconds: 1800,
      calories: 300,
      route: const [],
    );
    expect(RunningRecord.fromJson(plain.toJson()).crewName, isNull);
    expect(plain.toJson().containsKey('crewName'), isFalse);
    final crew = plain.withCrew('여의도 퇴근런');
    expect(RunningRecord.fromJson(crew.toJson()).crewName, '여의도 퇴근런');
  });

  group('종료 투표', () {
    test('2시간이 지나면 투표가 열리고, 20%(최소 1명)가 종료를 누르면 끝나요', () async {
      final id = await readyRun();
      await as(minji, () => storeFor(minji).startRun(runOf(id)));
      crews.tick();
      expect(runOf(id).vote, isNull);
      tick = tick.add(const Duration(hours: 2));
      crews.tick();
      expect(runOf(id).vote, isNotNull);
      // 3명이면 1명만 종료를 눌러도 끝나요.
      await as(haeun, () => storeFor(haeun).voteRun(crewId, id, end: true));
      expect(runOf(id).isEnded, isTrue);
      expect(runOf(id).vote, isNull);
    });

    test('30분 동안 끝내지 않기가 없으면 끝나고, 있으면 다시 물어요', () async {
      final id = await readyRun();
      await as(minji, () => storeFor(minji).startRun(runOf(id)));
      tick = tick.add(const Duration(hours: 2));
      crews.tick();
      await as(haeun, () => storeFor(haeun).voteRun(crewId, id, end: false));
      final firstAsk = runOf(id).vote!.askedAt;
      tick = tick.add(const Duration(minutes: 30));
      crews.tick();
      expect(runOf(id).isStarted, isTrue);
      expect(runOf(id).vote!.askedAt, isNot(firstAsk));
      expect(runOf(id).vote!.keep, isEmpty);

      tick = tick.add(const Duration(minutes: 30));
      crews.tick();
      expect(runOf(id).isEnded, isTrue);
    });

    testWidgets('투표가 열리면 달리는 사람에게 묻고, 답을 보내요', (tester) async {
      late String id;
      await tester.runAsync(() async {
        id = await readyRun();
        crews.actor = minji.uid;
        await storeFor(minji).startRun(runOf(id));
      });
      crews.actor = seojun.uid;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final link = CrewRunLink(crewId: crewId, runId: id, crewName: '여의도 퇴근런');
      await tester.pumpWidget(
        MaterialApp(
          home: CrewVoteListener(
            link: link,
            store: storeFor(seojun),
            child: const Scaffold(body: Text('달리는 중')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('팀을 종료할까요?'), findsNothing);

      await tester.runAsync(() async {
        tick = tick.add(const Duration(hours: 2));
        crews.tick();
        await settle();
      });
      await tester.pumpAndSettle();
      expect(find.text('팀을 종료할까요?'), findsOneWidget);
      await tester.tap(find.text('끝내지 않기'));
      await tester.pumpAndSettle();
      expect(runOf(id).vote!.keep, {seojun.uid});
      expect(find.text('팀을 종료할까요?'), findsNothing);
    });
  });

  group('화면', () {
    testWidgets('팀장이 시작하면 대기실의 모두가 함께 세고 러닝 화면을 열어요', (tester) async {
      late String id;
      await tester.runAsync(() async => id = await readyRun());
      final store = storeFor(haeun);
      CrewRunLink? launched;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CrewLobbyPage(
            crewId: crewId,
            runId: id,
            friends: FriendStore(backend: server, me: () => haeun),
            store: store,
            checkLocation: () async => true,
            startRun: (context, link) async => launched = link,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('물빛광장 5 km'), findsOneWidget);

      await tester.runAsync(() async {
        await as(minji, () => storeFor(minji).startRun(runOf(id)));
        await settle();
      });
      await tester.pump();
      expect(find.text('함께 출발해요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(launched?.runId, id);
      expect(launched?.crewId, crewId);
    });

    testWidgets('결과 화면: 팀장은 달리는 사람이 있으면 팀을 끝낼 수 있어요', (tester) async {
      late String id;
      await tester.runAsync(() async {
        id = await readyRun();
        await as(minji, () => storeFor(minji).startRun(runOf(id)));
        await as(
          minji,
          () => storeFor(minji).finishRun(
            crewId,
            id,
            recordId: 'r1',
            distanceKm: 5,
            movingSeconds: 1500,
            kcal: 300,
          ),
        );
      });
      final link = CrewRunLink(crewId: crewId, runId: id, crewName: '여의도 퇴근런');
      crews.actor = minji.uid;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrewTeamBanner(link: link, store: storeFor(minji)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('팀원 2명이 아직 달리고 있어요'), findsOneWidget);

      await tester.tap(find.text('팀 끝내기'));
      await tester.pumpAndSettle();
      expect(find.text('팀을 끝낼까요?'), findsOneWidget);
      // 확인 창의 '팀 끝내기'(배너 버튼과 이름이 같아요).
      await tester.tap(find.widgetWithText(FilledButton, '팀 끝내기').last);
      await tester.pumpAndSettle();
      expect(runOf(id).isEnded, isTrue);
      expect(find.textContaining('팀 기록이 끝났어요'), findsOneWidget);
    });
  });
}
