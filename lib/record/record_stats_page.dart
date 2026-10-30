import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import '../design_system/app_text_styles.dart';
import 'data/record_stats.dart';
import 'models/running_record.dart';

/// RecordListPageV2의 통계 본문. 주간·월간 합계를 지난 기간과 비교합니다.
class RecordStatsView extends StatefulWidget {
  const RecordStatsView({super.key, required this.records, this.now});
  final List<RunningRecord> records;

  /// 테스트에서 오늘 날짜를 고정할 때만 넘깁니다.
  final DateTime? now;
  @override
  State<RecordStatsView> createState() => _RecordStatsViewState();
}

class _RecordStatsViewState extends State<RecordStatsView> {
  StatsPeriod _period = StatsPeriod.week;
  int _offset = 0;

  void _pick(StatsPeriod period) => setState(() {
    _period = period;
    _offset = 0;
  });

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final stats = RecordStats.of(
      widget.records,
      period: _period,
      now: now,
      offset: _offset,
    );
    final unit = stats.isWeek ? '주' : '달';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: PillTabs(
                  labels: const ['주간', '월간'],
                  selected: _period.index,
                  onTap: (i) => _pick(StatsPeriod.values[i]),
                ),
              ),
              const Spacer(),
              _arrow(
                Icons.chevron_left,
                '이전 $unit',
                () => setState(() => _offset--),
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 112),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      stats.rangeLabel(now),
                      textAlign: TextAlign.center,
                      style: _text(15, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              _arrow(
                Icons.chevron_right,
                '다음 $unit',
                stats.isCurrent ? null : () => setState(() => _offset++),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _CompareCard(stats: stats),
        const SizedBox(height: 2),
        _Grid(stats: stats),
        const SizedBox(height: 16),
        _Legend(stats: stats),
        const SizedBox(height: 8),
        Semantics(
          label:
              '누적 거리 그래프. ${stats.currentLabel} ${stats.current.km.toStringAsFixed(2)} km, '
              '${stats.previousLabel} ${stats.previous.km.toStringAsFixed(2)} km',
          child: SizedBox(
            height: 140,
            child: CustomPaint(painter: _ChartPainter(stats)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _arrow(IconData icon, String tooltip, VoidCallback? onPressed) =>
      SizedBox(
        width: 40,
        height: 44,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          color: AppColors.textPrimary,
          disabledColor: AppColors.borderDefault,
          icon: Icon(icon, size: 22),
        ),
      );
}

TextStyle _text(
  double size, {
  Color color = AppColors.textPrimary,
  FontWeight weight = FontWeight.w600,
}) => TextStyle(
  fontFamily: AppTextStyles.bodyFontFamily,
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: 1.2,
  letterSpacing: size * -.015,
);

TextStyle _number(double size) => AppTextStyles.statValue.copyWith(
  fontSize: size,
  color: AppColors.textPrimary,
  fontWeight: FontWeight.w600,
  height: 1,
  letterSpacing: size * -.01,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// 흰 바탕이 선택된 둥근 작은 탭(통계의 주간·월간, 친구 피드의 내 피드·친구).
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onTap,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.borderDefault),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: i == selected,
              button: true,
              child: Material(
                color: i == selected
                    ? AppColors.textPrimary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: i == selected ? null : () => onTap(i),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: _text(
                        14,
                        color: i == selected
                            ? AppColors.background
                            : AppColors.textSecondary,
                        weight: i == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// 상태 배지, 요약 문구, 달린 거리와 지난 기간 비교.
class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.stats});
  final RecordStats stats;

  @override
  Widget build(BuildContext context) {
    final change = stats.distanceChange;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(trend: stats.trend),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stats.headline,
                    style: _text(20, weight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('달린 거리', style: _text(15, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        stats.current.km.toStringAsFixed(2),
                        style: _number(72),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'km',
                        style: _text(20, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    change.text,
                    style: _text(
                      20,
                      color: change.highlight
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${stats.previousLabel} ${stats.previous.km.toStringAsFixed(2)} km',
                    style: _text(15, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.trend});
  final StatsTrend trend;

  @override
  Widget build(BuildContext context) {
    final growing = trend == StatsTrend.growing;
    final color = growing ? AppColors.background : AppColors.textPrimary;
    final (icon, label) = switch (trend) {
      StatsTrend.growing => (Icons.trending_up, '성장 중'),
      StatsTrend.steady => (Icons.arrow_forward, '정체 중'),
      StatsTrend.falling => (Icons.trending_down, '하락 중'),
    };
    return Container(
      height: 32,
      padding: const EdgeInsets.fromLTRB(9, 0, 11, 0),
      decoration: BoxDecoration(
        // 회색 배지는 시안의 #2C3238(지도 버튼 테두리와 같은 색)입니다.
        color: growing ? AppColors.primary : AppColors.mapButtonBorder,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: _text(15, color: color, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// 달린 횟수·시간·칼로리·평균 페이스 네 칸.
class _Grid extends StatelessWidget {
  const _Grid({required this.stats});
  final RecordStats stats;

  @override
  Widget build(BuildContext context) {
    final now = stats.current;
    final minutes = now.seconds ~/ 60;
    final pace = now.paceSeconds;
    return Column(
      children: [
        _row(
          _Cell(
            label: '달린 횟수',
            value: [('${now.runs}', '회')],
            change: stats.runsChange,
          ),
          _Cell(
            label: '달린 시간',
            value: [
              if (minutes >= 60) ('${minutes ~/ 60}', '시간'),
              ('${minutes % 60}', '분'),
            ],
            change: stats.timeChange,
          ),
          bottomLine: true,
        ),
        _row(
          _Cell(
            label: '칼로리',
            value: [(groupDigits(now.kcal.round()), 'kcal')],
            change: stats.kcalChange,
          ),
          _Cell(
            label: '평균 페이스',
            value: [(pace == null ? '—' : paceText(pace), '/km')],
            change: stats.paceChange,
          ),
        ),
      ],
    );
  }

  Widget _row(Widget left, Widget right, {bool bottomLine = false}) {
    const line = BorderSide(color: AppColors.divider);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: bottomLine ? line : BorderSide.none),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 16),
                decoration: const BoxDecoration(border: Border(left: line)),
                child: right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, required this.change});
  final String label;

  /// (숫자, 단위) 묶음. '1시간 35분'처럼 여러 개일 수 있습니다.
  final List<(String, String)> value;
  final StatsChange change;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _text(12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              for (final (i, (number, unit)) in value.indexed) ...[
                if (i > 0) const SizedBox(width: 5),
                Text(number, style: _number(26)),
                const SizedBox(width: 3),
                Text(unit, style: _text(13, color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 7),
        Text(
          change.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _text(
            13,
            color: change.highlight
                ? AppColors.primary
                : AppColors.textSecondary,
            weight: change.highlight ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// '누적 거리 km'와 이번·지난 기간 선 모양.
class _Legend extends StatelessWidget {
  const _Legend({required this.stats});
  final RecordStats stats;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text('누적 거리', style: _text(15, weight: FontWeight.w700)),
      const SizedBox(width: 5),
      Text('km', style: _text(12, color: AppColors.textSecondary)),
      const Spacer(),
      _key(const _LineSample(dashed: false), stats.currentLabel),
      const SizedBox(width: 14),
      _key(const _LineSample(dashed: true), stats.previousLabel),
    ],
  );

  Widget _key(Widget sample, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      sample,
      const SizedBox(width: 6),
      Text(label, style: _text(12, color: AppColors.textSecondary)),
    ],
  );
}

class _LineSample extends StatelessWidget {
  const _LineSample({required this.dashed});
  final bool dashed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 4,
    child: CustomPaint(
      painter: _LinePainter(
        dashed ? AppColors.borderControl : AppColors.primary,
        dashed: dashed,
      ),
    ),
  );
}

class _LinePainter extends CustomPainter {
  const _LinePainter(this.color, {required this.dashed});
  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    canvas.drawPath(dashed ? _dash(path) : path, _stroke(color));
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.color != color || old.dashed != dashed;
}

Paint _stroke(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

/// 4 그리고 3 쉬는 점선.
Path _dash(Path source) {
  final dashed = Path();
  for (final metric in source.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += 7) {
      dashed.addPath(
        metric.extractPath(d, math.min(d + 4, metric.length)),
        Offset.zero,
      );
    }
  }
  return dashed;
}

/// 누적 거리 그래프. 이번 기간은 주황 실선과 옅은 채움, 지난 기간은 회색 점선입니다.
class _ChartPainter extends CustomPainter {
  _ChartPainter(this.stats);
  final RecordStats stats;

  static const _left = 30.0, _right = 14.0, _top = 8.0, _bottom = 116.0;

  @override
  void paint(Canvas canvas, Size size) {
    final current = stats.currentCumulative,
        previous = stats.previousCumulative;
    final top = [...current, ...previous].fold(0.0, math.max);
    final step = _niceStep(top / 4);
    final width = size.width - _left - _right;
    double x(int i) => _left + width * i / (stats.days - 1);
    double y(double km) => _bottom - (_bottom - _top) * km / (step * 4);

    for (var i = 0; i <= 4; i++) {
      final gy = y(step * i);
      canvas.drawLine(
        Offset(_left, gy),
        Offset(size.width - _right, gy),
        Paint()
          ..color = i == 0 ? AppColors.borderDefault : AppColors.divider
          ..strokeWidth = 1,
      );
      _label(
        canvas,
        _axisNumber(step * i),
        Offset(20, gy),
        align: TextAlign.right,
      );
    }
    for (final (i, text) in _xLabels()) {
      final today = i == stats.todayIndex;
      _label(
        canvas,
        text,
        Offset(x(i), 130),
        color: today ? AppColors.textPrimary : AppColors.textTertiary,
        weight: today ? FontWeight.w700 : FontWeight.w500,
      );
    }

    Path line(List<double> values) {
      final path = Path()..moveTo(x(0), y(values.first));
      for (var i = 1; i < values.length; i++) {
        path.lineTo(x(i), y(values[i]));
      }
      return path;
    }

    if (current.isNotEmpty) {
      final area = line(current)
        ..lineTo(x(current.length - 1), _bottom)
        ..lineTo(x(0), _bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()..color = AppColors.primary.withValues(alpha: .12),
      );
    }
    if (previous.isNotEmpty) {
      canvas.drawPath(_dash(line(previous)), _stroke(AppColors.borderControl));
    }
    if (current.isEmpty) return;
    canvas.drawPath(line(current), _stroke(AppColors.primary));

    final last = Offset(x(current.length - 1), y(current.last));
    canvas.drawCircle(last, 5, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      last,
      5,
      Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _label(
      canvas,
      current.last.toStringAsFixed(2),
      Offset(last.dx, last.dy - 15),
      color: AppColors.textPrimary,
      size: 13,
      weight: FontWeight.w700,
      maxX: size.width,
    );
  }

  /// 주간은 월~일, 월간은 1·10·20·말일과 오늘(가까운 날짜 글자는 겹치지 않게 뺍니다).
  List<(int, String)> _xLabels() {
    if (stats.isWeek) {
      return [
        for (final (i, day) in const [
          '월',
          '화',
          '수',
          '목',
          '금',
          '토',
          '일',
        ].indexed)
          (i, day),
      ];
    }
    final today = stats.todayIndex;
    return [
      for (final i in {0, 9, 19, stats.days - 1})
        if (today == null || i == today || (i - today).abs() >= 3)
          (i, '${i + 1}일'),
      if (today != null && !{0, 9, 19, stats.days - 1}.contains(today))
        (today, '${today + 1}일'),
    ];
  }

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    TextAlign align = TextAlign.center,
    Color color = AppColors.textTertiary,
    double size = 12,
    FontWeight weight = FontWeight.w500,
    double? maxX,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: _text(size, color: color, weight: weight).copyWith(
          letterSpacing: 0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = align == TextAlign.right
        ? anchor.dx - painter.width
        : anchor.dx - painter.width / 2;
    if (maxX != null) dx = dx.clamp(0, maxX - painter.width);
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  static String _axisNumber(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  /// 눈금 간격을 1·2·5·10·20·25·50… 중에서 고릅니다.
  static double _niceStep(double raw) {
    for (var scale = 1.0; ; scale *= 10) {
      for (final base in const [1, 2, 2.5, 5]) {
        if (base * scale >= raw) return base * scale;
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.stats != stats;
}
