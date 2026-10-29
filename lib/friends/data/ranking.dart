import 'package:flutter/foundation.dart';

import 'friend_models.dart';

/// 17-1 랭킹 기준.
enum RankingKind {
  weekDistance('주간 거리', 'km', '이번 주 내 순위', '매주 월요일에 새로 시작해요'),
  weekRuns('주간 횟수', '회', '이번 주 내 순위', '매주 월요일에 새로 시작해요'),
  monthDistance('월간 거리', 'km', '이번 달 내 순위', '매달 1일에 새로 시작해요');

  const RankingKind(this.label, this.unit, this.title, this.reset);
  final String label, unit, title, reset;

  double valueOf(RunStats stats, DateTime now) => switch (this) {
    weekDistance => stats.weekKmAt(now),
    weekRuns => stats.weekRunsAt(now).toDouble(),
    monthDistance => stats.monthKmAt(now),
  };

  /// 표에 보이는 값: 거리는 소수 한 자리, 횟수는 정수.
  String format(double value) =>
      this == weekRuns ? value.round().toString() : value.toStringAsFixed(1);

  /// 기간: 10월 26일 – 11월 1일 / 10월 1일 – 31일.
  String period(DateTime now) {
    if (this == monthDistance) {
      final last = DateTime(now.year, now.month + 1, 0);
      return '${now.month}월 1일 – ${last.day}일';
    }
    final start = weekOf(now), end = start.add(const Duration(days: 6));
    return '${start.month}월 ${start.day}일 – '
        '${end.month == start.month ? '' : '${end.month}월 '}${end.day}일';
  }
}

/// 랭킹 한 줄.
@immutable
class RankRow {
  const RankRow({
    required this.person,
    required this.value,
    required this.rank,
    required this.me,
  });
  final PublicProfile person;
  final double value;

  /// 같은 값이면 같은 순위입니다(1, 2, 3, 3, 5).
  final int rank;
  final bool me;
}

/// 나와 친구들을 [kind] 값이 큰 순서로 세웁니다. 값이 같으면 나를 먼저 둡니다.
List<RankRow> rankRows(
  RankingKind kind,
  PublicProfile me,
  RunStats myStats,
  Map<PublicProfile, RunStats?> friends,
  DateTime now,
) {
  final entries =
      [
        (me, kind.valueOf(myStats, now), true),
        for (final MapEntry(key: person, value: stats) in friends.entries)
          (person, stats == null ? 0.0 : kind.valueOf(stats, now), false),
      ]..sort((a, b) {
        final byValue = b.$2.compareTo(a.$2);
        if (byValue != 0) return byValue;
        if (a.$3 != b.$3) return a.$3 ? -1 : 1;
        return a.$1.name.compareTo(b.$1.name);
      });
  final rows = <RankRow>[];
  for (final (i, (person, value, isMe)) in entries.indexed) {
    final rank = i > 0 && entries[i - 1].$2 == value ? rows[i - 1].rank : i + 1;
    rows.add(RankRow(person: person, value: value, rank: rank, me: isMe));
  }
  return rows;
}

/// 내 바로 위 순위 사람과의 차이. 내가 1위면 null.
(RankRow, double)? gapAbove(List<RankRow> rows) {
  final mine = rows.indexWhere((r) => r.me);
  if (mine < 0) return null;
  final ahead = rows
      .take(mine)
      .where((r) => r.value > rows[mine].value)
      .lastOrNull;
  if (ahead == null) return null;
  return (ahead, ahead.value - rows[mine].value);
}

/// 목표 비교 한 줄.
@immutable
class GoalRow {
  const GoalRow({
    required this.person,
    required this.doneKm,
    required this.goalKm,
    required this.me,
  });
  final PublicProfile person;
  final double doneKm;
  final int goalKm;
  final bool me;

  /// 달성률(%). 100을 넘을 수 있습니다.
  int get percent => goalKm <= 0 ? 0 : (doneKm / goalKm * 100).floor();
  bool get achieved => doneKm >= goalKm;
}

/// 목표를 공개한 사람만 달성률이 높은 순서로 세웁니다.
List<GoalRow> goalRows(
  PublicProfile me,
  RunStats myStats,
  WeeklyGoal? myGoal,
  Map<PublicProfile, RunStats?> friends,
  DateTime now,
) {
  final rows = [
    if (myGoal != null && myGoal.public)
      GoalRow(
        person: me,
        doneKm: myStats.weekKmAt(now),
        goalKm: myGoal.km,
        me: true,
      ),
    // 지난주에 올린 합계의 목표는 이번 주 목표가 아니므로 뺍니다.
    for (final MapEntry(key: person, value: stats) in friends.entries)
      if (stats != null &&
          stats.goalKm != null &&
          stats.weekStart == dayKey(weekOf(now)))
        GoalRow(
          person: person,
          doneKm: stats.weekKm,
          goalKm: stats.goalKm!,
          me: false,
        ),
  ];
  rows.sort((a, b) {
    final byRate = (b.doneKm / b.goalKm).compareTo(a.doneKm / a.goalKm);
    return byRate != 0 ? byRate : a.person.name.compareTo(b.person.name);
  });
  return rows;
}
