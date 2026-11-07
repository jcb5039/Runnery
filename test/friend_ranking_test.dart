import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/ranking.dart';
import 'package:runnery_new/friends/friends_page.dart';
import 'package:runnery_new/record/models/running_record.dart';

import 'support/fake_friend_backend.dart';

void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');
  const seojun = PublicProfile(uid: 'u3', name: '이서준', id: 'seojun_k');
  const yuna = PublicProfile(uid: 'u4', name: '최유나', id: 'yuna_jog');

  // 2026년 10월 29일 목요일. 이번 주는 26일(월)~11월 1일(일).
  final now = DateTime(2026, 10, 29, 12);

  RunningRecord run(DateTime startedAt, double km) => RunningRecord(
    id: 'r${startedAt.millisecondsSinceEpoch}',
    startedAt: startedAt,
    distanceKm: km,
    movingSeconds: 1800,
    calories: 300,
    route: const [],
  );

  RunStats stats({
    String week = '2026-10-26',
    double weekKm = 0,
    int runs = 0,
    double monthKm = 0,
    int? goal,
  }) => RunStats(
    weekStart: week,
    monthKey: '2026-10',
    weekKm: weekKm,
    weekRuns: runs,
    monthKm: monthKm,
    goalKm: goal,
  );

  test('stats count only this week and this month', () {
    final s = RunStats.from(
      [
        (DateTime(2026, 10, 26, 7), 5.0), // 이번 주 월요일
        (DateTime(2026, 10, 29, 7), 3.25),
        (DateTime(2026, 10, 25, 23), 10.0), // 지난주 일요일
        (DateTime(2026, 9, 30, 7), 8.0), // 지난달
      ],
      now,
      goalKm: 20,
    );
    expect(s.weekStart, '2026-10-26');
    expect(s.weekKm, 8.25);
    expect(s.weekRuns, 2);
    expect(s.monthKm, 18.25);
    expect(s.goalKm, 20);
    // 다음 주가 되면 지난주 합계는 0으로 봅니다.
    expect(s.weekKmAt(DateTime(2026, 11, 2)), 0);
    expect(s.monthKmAt(DateTime(2026, 11, 2)), 0);
  });

  test('ranking shares ranks on ties and finds the gap above me', () {
    final rows = rankRows(RankingKind.weekDistance, minji, stats(weekKm: 10), {
      haeun: stats(weekKm: 18.6),
      seojun: stats(weekKm: 10),
      yuna: stats(week: '2026-10-19', weekKm: 30), // 지난주 합계
    }, now);
    expect(
      [for (final r in rows) (r.person.name, r.rank)],
      [('박하은', 1), ('김민지', 2), ('이서준', 2), ('최유나', 4)],
    );
    final (ahead, gap) = gapAbove(rows)!;
    expect(ahead.person, haeun);
    expect(gap, closeTo(8.6, 1e-9));
  });

  test('first place has no gap above', () {
    final rows = rankRows(RankingKind.weekRuns, minji, stats(runs: 5), {
      haeun: stats(runs: 2),
    }, now);
    expect(rows.first.me, isTrue);
    expect(gapAbove(rows), isNull);
  });

  test('goal comparison shows only public goals, highest rate first', () {
    final rows = goalRows(
      minji,
      stats(weekKm: 15.2),
      const WeeklyGoal(km: 20),
      {
        haeun: stats(weekKm: 18.6, goal: 20),
        seojun: stats(weekKm: 24.3), // 목표 비공개
        yuna: stats(weekKm: 9.4, goal: 8),
      },
      now,
    );
    expect(
      [for (final r in rows) (r.person.name, r.percent)],
      [('최유나', 117), ('박하은', 93), ('김민지', 76)],
    );
    expect(rows.first.achieved, isTrue);

    final hidden = goalRows(
      minji,
      stats(weekKm: 15.2),
      const WeeklyGoal(km: 20, public: false),
      const {},
      now,
    );
    expect(hidden, isEmpty);
  });

  test('refresh publishes my totals and public goal for friends', () async {
    final server = FakeFriendBackend()
      ..friends[minji.uid] = {haeun.uid}
      ..friends[haeun.uid] = {minji.uid}
      ..profilesByUid[haeun.uid] = haeun
      ..statsByUid[haeun.uid] = stats(weekKm: 18.6, goal: 20);
    final records = [run(DateTime(2026, 10, 27, 7), 6.0)];
    final store = FriendStore(
      backend: server,
      me: () => minji,
      records: () async => records,
      clock: () => now,
    );
    await store.refresh();
    expect(server.statsByUid[minji.uid]!.weekKm, 6.0);
    expect(server.statsByUid[minji.uid]!.goalKm, isNull);
    expect(store.statsOf(haeun.uid)!.weekKm, 18.6);

    await store.saveGoal(const WeeklyGoal(km: 15));
    expect(server.goals[minji.uid], const WeeklyGoal(km: 15));
    expect(server.statsByUid[minji.uid]!.goalKm, 15);

    await store.saveGoal(const WeeklyGoal(km: 15, public: false));
    expect(server.statsByUid[minji.uid]!.goalKm, isNull);

    records.add(run(DateTime(2026, 10, 28, 7), 4.0));
    await store.recordsChanged();
    expect(server.statsByUid[minji.uid]!.weekKm, 10.0);
    expect(server.statsByUid[minji.uid]!.weekRuns, 2);
  });

  testWidgets('ranking and goal tabs show friends and save a goal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = FakeFriendBackend()
      ..friends[minji.uid] = {haeun.uid}
      ..friends[haeun.uid] = {minji.uid}
      ..profilesByUid[haeun.uid] = haeun
      ..statsByUid[haeun.uid] = stats(weekKm: 18.6, runs: 3, goal: 20);
    final store = FriendStore(
      backend: server,
      me: () => minji,
      records: () async => [run(DateTime(2026, 10, 27, 7), 15.2)],
      clock: () => now,
    );
    await tester.pumpWidget(MaterialApp(home: FriendsPage(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('랭킹'));
    await tester.pumpAndSettle();
    expect(find.text('이번 주 내 순위'), findsOneWidget);
    expect(find.text('2명 중'), findsOneWidget);
    expect(find.text('1위 박하은까지'), findsOneWidget);
    expect(find.text('3.4'), findsOneWidget);
    expect(find.text('10월 26일 – 11월 1일'), findsOneWidget);

    await tester.tap(find.text('주간 횟수'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('목표'));
    await tester.pumpAndSettle();
    expect(find.text('이번 주 목표를 정해 보세요'), findsOneWidget);
    expect(find.text('박하은'), findsOneWidget);
    expect(find.text('93'), findsOneWidget);

    await tester.tap(find.text('목표 정하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 km'));
    await tester.pump();
    await tester.tap(find.byTooltip('1 km 늘리기'));
    await tester.pump();
    expect(find.text('16'), findsOneWidget);
    await tester.tap(find.text('이 목표로 저장'));
    await tester.pumpAndSettle();

    expect(server.goals[minji.uid], const WeeklyGoal(km: 16));
    expect(find.text('이번 주 내 목표'), findsOneWidget);
    expect(find.text('/ 16 km'), findsWidgets);
    expect(find.text('4일 남았어요', findRichText: true), findsNothing);
    expect(find.textContaining('4일 남았어요'), findsOneWidget);
  });
}
