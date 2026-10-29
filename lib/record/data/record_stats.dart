import '../models/running_record.dart';

/// 통계를 묶는 기간. 주간은 월요일부터 일요일까지입니다.
enum StatsPeriod { week, month }

/// 지난 기간과 비교한 상태.
enum StatsTrend { growing, steady, falling }

/// 달린 거리 변화가 이 비율(%) 안이면 '정체 중'으로 봅니다.
const statsSteadyPercent = 1.0;

/// 기간 하나의 합계.
class StatsTotals {
  const StatsTotals({
    this.runs = 0,
    this.km = 0,
    this.seconds = 0,
    this.kcal = 0,
  });
  final int runs;
  final double km;
  final int seconds;
  final double kcal;

  /// 1km당 초. 거리가 거의 없으면 null.
  int? get paceSeconds =>
      km >= .01 && seconds > 0 ? (seconds / km).round() : null;

  StatsTotals operator +(RunningRecord r) => StatsTotals(
    runs: runs + 1,
    km: km + r.distanceKm,
    seconds: seconds + r.movingSeconds,
    kcal: kcal + r.energyKcal,
  );
}

/// 지난 기간과 비교한 한 줄 문구. 늘었거나 빨라졌으면 [highlight]가 참입니다.
class StatsChange {
  const StatsChange(this.text, {this.highlight = false});
  final String text;
  final bool highlight;
}

/// 고른 주(또는 달)와 바로 앞 기간의 기록을 모아 계산합니다.
class RecordStats {
  RecordStats._({
    required this.period,
    required this.start,
    required this.days,
    required this.previousStart,
    required this.previousDays,
    required this.todayIndex,
    required this.current,
    required this.previous,
    required this.currentCumulative,
    required this.previousCumulative,
  });

  /// [offset]은 이번 기간에서 몇 칸 앞인지(0 = 이번 주·이번 달, -1 = 그 전).
  factory RecordStats.of(
    List<RunningRecord> records, {
    required StatsPeriod period,
    required DateTime now,
    int offset = 0,
  }) {
    final start = periodStart(period, now, offset);
    final previousStart = periodStart(period, now, offset - 1);
    final days = _length(period, start);
    final previousDays = _length(period, previousStart);
    final today = _dayIndex(start, now);
    final todayIndex = today >= 0 && today < days ? today : null;

    var current = const StatsTotals();
    var previous = const StatsTotals();
    final daily = List<double>.filled(days, 0);
    final previousDaily = List<double>.filled(previousDays, 0);
    for (final r in records) {
      final i = _dayIndex(start, r.startedAt);
      if (i >= 0 && i < days) {
        current += r;
        daily[i] += r.distanceKm;
        continue;
      }
      final j = _dayIndex(previousStart, r.startedAt);
      if (j >= 0 && j < previousDays) {
        previous += r;
        previousDaily[j] += r.distanceKm;
      }
    }
    return RecordStats._(
      period: period,
      start: start,
      days: days,
      previousStart: previousStart,
      previousDays: previousDays,
      todayIndex: todayIndex,
      current: current,
      previous: previous,
      // 이번 기간은 오늘까지만 선을 긋습니다.
      currentCumulative: _cumulative(
        daily,
        todayIndex == null ? days : todayIndex + 1,
      ),
      previousCumulative: _previousLine(previousDaily, days),
    );
  }

  final StatsPeriod period;
  final DateTime start, previousStart;
  final int days, previousDays;

  /// 오늘이 이 기간 안이면 몇 번째 날인지(0부터).
  final int? todayIndex;
  final StatsTotals current, previous;

  /// 날짜별 누적 거리(km). 그래프 가로축은 이번 기간의 [days]일입니다.
  final List<double> currentCumulative, previousCumulative;

  bool get isWeek => period == StatsPeriod.week;

  /// 오늘이 들어 있는 기간인지. 이번 기간이면 다음 기간으로 넘어갈 수 없습니다.
  bool get isCurrent => todayIndex != null;

  DateTime get end => DateTime(start.year, start.month, start.day + days - 1);

  /// 기간 줄에 보이는 날짜. 예: '10월 19일 – 25일', '2026년 10월'.
  String rangeLabel(DateTime now) {
    if (!isWeek) return '${start.year}년 ${start.month}월';
    final year = end.year == now.year ? '' : '${end.year}년 ';
    final tail = end.month == start.month
        ? '${end.day}일'
        : '${end.month}월 ${end.day}일';
    return '$year${start.month}월 ${start.day}일 – $tail';
  }

  /// 그래프 범례와 문구에 쓰는 기간 이름.
  String get currentLabel =>
      isWeek ? (isCurrent ? '이번 주' : '이 주') : '${start.month}월';
  String get previousLabel =>
      isWeek ? (isCurrent ? '지난주' : '전 주') : '${previousStart.month}월';

  /// '지난주와', '9월과'처럼 받침에 맞춘 조사.
  String get _previousWith => '$previousLabel${isWeek ? '와' : '과'}';

  /// 달린 거리 변화율(%). 지난 기간에 달리지 않았으면 null.
  double? get changePercent =>
      previous.km > 0 ? (current.km - previous.km) / previous.km * 100 : null;

  StatsTrend get trend {
    final percent = changePercent;
    if (percent == null) {
      return current.km > 0 ? StatsTrend.growing : StatsTrend.steady;
    }
    if (percent > statsSteadyPercent) return StatsTrend.growing;
    if (percent < -statsSteadyPercent) return StatsTrend.falling;
    return StatsTrend.steady;
  }

  /// 비교 카드 맨 위 한 줄.
  String get headline {
    final percent = changePercent;
    if (percent == null) {
      if (current.km > 0) return '$previousLabel엔 달리지 않았어요';
      if (!isWeek) {
        return isCurrent ? '이번 달엔 아직 달리지 않았어요' : '$currentLabel엔 달리지 않았어요';
      }
      return isCurrent ? '이번 주엔 아직 달리지 않았어요' : '이 주엔 달리지 않았어요';
    }
    final rounded = percent.abs().round();
    return switch (trend) {
      StatsTrend.growing => '$previousLabel보다 $rounded% 더 달렸어요',
      StatsTrend.falling => '$previousLabel보다 $rounded% 덜 달렸어요',
      StatsTrend.steady => '$_previousWith 거의 비슷해요',
    };
  }

  /// 비교 카드 오른쪽의 거리 차이. 성장 중일 때만 강조합니다.
  StatsChange get distanceChange {
    final diff = _round2(current.km) - _round2(previous.km);
    final value = '${diff.abs().toStringAsFixed(2)} km';
    if (diff.abs() < .005) return StatsChange(value);
    return StatsChange(
      '${diff > 0 ? '▲' : '▼'} $value',
      highlight: trend == StatsTrend.growing,
    );
  }

  StatsChange get runsChange =>
      _countChange(current.runs - previous.runs, (n) => '$n회');

  /// 화면에 보이는 분 단위로 비교합니다.
  StatsChange get timeChange =>
      _countChange(current.seconds ~/ 60 - previous.seconds ~/ 60, minutesText);

  StatsChange get kcalChange => _countChange(
    current.kcal.round() - previous.kcal.round(),
    (n) => '${groupDigits(n)} kcal',
  );

  StatsChange get paceChange {
    final now = current.paceSeconds, before = previous.paceSeconds;
    if (now == null || before == null) return const StatsChange('비교할 기록이 없어요');
    final diff = now - before;
    if (diff == 0) return StatsChange('$_previousWith 같아요');
    final amount = diff.abs() >= 60
        ? '${diff.abs() ~/ 60}분 ${diff.abs() % 60}초'
        : '${diff.abs()}초';
    return diff < 0
        ? StatsChange('$amount 빨라졌어요', highlight: true)
        : StatsChange('$amount 느려졌어요');
  }

  StatsChange _countChange(int diff, String Function(int) unit) {
    if (diff == 0) return StatsChange('$_previousWith 같아요');
    return diff > 0
        ? StatsChange('▲ ${unit(diff)}', highlight: true)
        : StatsChange('▼ ${unit(-diff)}');
  }

  /// 기간의 첫날 0시.
  static DateTime periodStart(StatsPeriod period, DateTime now, int offset) =>
      period == StatsPeriod.week
      ? DateTime(now.year, now.month, now.day - (now.weekday - 1) + offset * 7)
      : DateTime(now.year, now.month + offset);

  static int _length(StatsPeriod period, DateTime start) =>
      period == StatsPeriod.week
      ? 7
      : DateTime(start.year, start.month + 1, 0).day;

  /// [start]에서 며칠째인지. 서머타임과 상관없이 날짜만 셉니다.
  static int _dayIndex(DateTime start, DateTime time) => DateTime.utc(
    time.year,
    time.month,
    time.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

  static List<double> _cumulative(List<double> daily, int length) {
    var sum = 0.0;
    return [for (var i = 0; i < length; i++) sum += daily[i]];
  }

  /// 지난 기간이 더 길면(예: 31일 → 30일) 남는 날의 거리를 마지막 날에 합칩니다.
  static List<double> _previousLine(List<double> daily, int days) {
    final line = _cumulative(daily, daily.length);
    if (line.length <= days) return line;
    return [...line.take(days - 1), line.last];
  }

  static double _round2(double value) => (value * 100).round() / 100;
}

/// '1시간 35분', '35분'.
String minutesText(int minutes) =>
    minutes >= 60 ? '${minutes ~/ 60}시간 ${minutes % 60}분' : '$minutes분';

/// 1241 → '1,241'.
String groupDigits(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
