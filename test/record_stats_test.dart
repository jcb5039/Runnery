import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/record/data/record_stats.dart';
import 'package:runnery_new/record/models/running_record.dart';

RunningRecord _run(
  DateTime at,
  double km, {
  int seconds = 600,
  int calories = 100,
}) => RunningRecord(
  id: at.toIso8601String(),
  startedAt: at,
  distanceKm: km,
  movingSeconds: seconds,
  calories: calories,
  route: const [],
);

void main() {
  // 2026년 10월 24일은 토요일입니다.
  final saturday = DateTime(2026, 10, 24, 21);

  RecordStats week(List<RunningRecord> records, {int offset = 0}) =>
      RecordStats.of(
        records,
        period: StatsPeriod.week,
        now: saturday,
        offset: offset,
      );

  RecordStats month(List<RunningRecord> records, {DateTime? now}) =>
      RecordStats.of(records, period: StatsPeriod.month, now: now ?? saturday);

  test('week runs Monday to Sunday and splits this week from last week', () {
    final stats = week([
      _run(DateTime(2026, 10, 19, 6), 5), // 이번 주 월요일
      _run(DateTime(2026, 10, 25, 23), 1), // 이번 주 일요일
      _run(DateTime(2026, 10, 18, 23), 4), // 지난주 일요일
      _run(DateTime(2026, 10, 12, 6), 2), // 지난주 월요일
      _run(DateTime(2026, 10, 11, 6), 9), // 2주 전, 안 셈
    ]);
    expect(stats.start, DateTime(2026, 10, 19));
    expect(stats.rangeLabel(saturday), '10월 19일 – 25일');
    expect(stats.current.runs, 2);
    expect(stats.current.km, 6);
    expect(stats.previous.runs, 2);
    expect(stats.previous.km, 6);
    expect(stats.isCurrent, isTrue);
    expect(stats.todayIndex, 5);
    // 이번 주 선은 오늘(토)까지만, 지난주 선은 일주일 전체.
    expect(stats.currentCumulative, [5, 5, 5, 5, 5, 5]);
    expect(stats.previousCumulative, [2, 2, 2, 2, 2, 2, 6]);
  });

  test(
    'week across months shows both months and older weeks are not current',
    () {
      final stats = week(const [], offset: -4);
      expect(stats.rangeLabel(saturday), '9월 21일 – 27일');
      expect(stats.isCurrent, isFalse);
      expect(stats.currentLabel, '이 주');
      expect(stats.previousLabel, '전 주');
      expect(
        week(const [], offset: -3).rangeLabel(saturday),
        '9월 28일 – 10월 4일',
      );
    },
  );

  test('trend is steady only within one percent', () {
    final last = _run(DateTime(2026, 10, 13), 10);
    StatsTrend trendFor(double km) =>
        week([last, _run(DateTime(2026, 10, 20), km)]).trend;
    expect(trendFor(10.1), StatsTrend.steady);
    expect(trendFor(9.9), StatsTrend.steady);
    expect(trendFor(10.11), StatsTrend.growing);
    expect(trendFor(9.89), StatsTrend.falling);
  });

  test('headline follows the trend', () {
    final last = _run(DateTime(2026, 10, 13), 10);
    expect(
      week([last, _run(DateTime(2026, 10, 20), 15.4)]).headline,
      '지난주보다 54% 더 달렸어요',
    );
    expect(
      week([last, _run(DateTime(2026, 10, 20), 7)]).headline,
      '지난주보다 30% 덜 달렸어요',
    );
    expect(
      week([last, _run(DateTime(2026, 10, 20), 10)]).headline,
      '지난주와 거의 비슷해요',
    );
    expect(week([last]).headline, '지난주보다 100% 덜 달렸어요');
    expect(week([last]).trend, StatsTrend.falling);
  });

  test('falling shows a gray down arrow, growing an orange up arrow', () {
    final last = _run(DateTime(2026, 10, 13), 10, seconds: 3600, calories: 600);
    final down = week([
      last,
      _run(DateTime(2026, 10, 20), 7, seconds: 3000, calories: 400),
    ]);
    expect(down.distanceChange.text, '▼ 3.00 km');
    expect(down.distanceChange.highlight, isFalse);
    expect(down.timeChange.text, '▼ 10분');
    expect(down.kcalChange.text, '▼ 200 kcal');
    expect(down.runsChange.text, '지난주와 같아요');

    final up = week([
      last,
      _run(DateTime(2026, 10, 20), 12, seconds: 3600, calories: 800),
      _run(DateTime(2026, 10, 21), 3, seconds: 4200, calories: 900),
    ]);
    expect(up.distanceChange.text, '▲ 5.00 km');
    expect(up.distanceChange.highlight, isTrue);
    expect(up.runsChange.text, '▲ 1회');
    expect(up.timeChange.text, '▲ 1시간 10분');
    expect(up.kcalChange.text, '▲ 1,100 kcal');
  });

  test('pace compares seconds per km', () {
    final last = _run(DateTime(2026, 10, 13), 10, seconds: 3600); // 6'00"
    final faster = week([
      last,
      _run(DateTime(2026, 10, 20), 10, seconds: 3540),
    ]);
    expect(faster.paceChange.text, '6초 빨라졌어요');
    expect(faster.paceChange.highlight, isTrue);
    final slower = week([
      last,
      _run(DateTime(2026, 10, 20), 10, seconds: 4300),
    ]);
    expect(slower.paceChange.text, '1분 10초 느려졌어요');
    expect(slower.paceChange.highlight, isFalse);
    expect(week([last]).paceChange.text, '비교할 기록이 없어요');
  });

  test('no runs last period: growing if ran now, steady if neither', () {
    final now = week([_run(DateTime(2026, 10, 20), 3)]);
    expect(now.trend, StatsTrend.growing);
    expect(now.headline, '지난주엔 달리지 않았어요');
    expect(now.changePercent, isNull);

    final none = week(const []);
    expect(none.trend, StatsTrend.steady);
    expect(none.headline, '이번 주엔 아직 달리지 않았어요');
    expect(month(const []).headline, '이번 달엔 아직 달리지 않았어요');
    expect(week(const [], offset: -2).headline, '이 주엔 달리지 않았어요');
  });

  test('month uses month names and the right number of days', () {
    final stats = month([
      _run(DateTime(2026, 10, 1, 7), 4),
      _run(DateTime(2026, 9, 30, 7), 2),
    ]);
    expect(stats.rangeLabel(saturday), '2026년 10월');
    expect(stats.days, 31);
    expect(stats.previousDays, 30);
    expect(stats.currentLabel, '10월');
    expect(stats.previousLabel, '9월');
    expect(stats.headline, '9월보다 100% 더 달렸어요');
    expect(stats.currentCumulative.length, 24); // 오늘(24일)까지
    expect(stats.previousCumulative.length, 30);
    expect(stats.previousCumulative.last, 2);

    final steady = month([
      _run(DateTime(2026, 10, 1), 2),
      _run(DateTime(2026, 9, 1), 2),
    ]);
    expect(steady.headline, '9월과 거의 비슷해요');
    expect(steady.runsChange.text, '9월과 같아요');
  });

  test('a longer previous month folds its last days into the final point', () {
    // 2027년 2월(28일)과 1월(31일). 1월 30일 기록도 마지막 점에 들어갑니다.
    final stats = month([
      _run(DateTime(2027, 1, 30), 5),
    ], now: DateTime(2027, 2, 10));
    expect(stats.days, 28);
    expect(stats.previousCumulative.length, 28);
    expect(stats.previousCumulative[26], 0);
    expect(stats.previousCumulative.last, 5);
    expect(stats.headline, '1월보다 100% 덜 달렸어요');
  });

  test('January compares with December of the previous year', () {
    final stats = month(const [], now: DateTime(2027, 1, 5));
    expect(stats.previousStart, DateTime(2026, 12));
    expect(stats.previousLabel, '12월');
  });

  test('number helpers', () {
    expect(groupDigits(3553), '3,553');
    expect(groupDigits(918), '918');
    expect(groupDigits(1234567), '1,234,567');
    expect(minutesText(95), '1시간 35분');
    expect(minutesText(35), '35분');
  });
}
