import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../../design_system/app_colors.dart';
import '../../design_system/app_component_metrics.dart';
import '../../design_system/app_motion.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_spacing.dart';
import '../../friends/share/share_record_sheet.dart';
import '../../record/data/record_from_session.dart';
import 'running_home_page.dart';
import 'running_start_page.dart';

// ═════════════════════════════════════════════════════
// 09 러닝 결과
// ═════════════════════════════════════════════════════

class RunningResultPage extends StatelessWidget {
  const RunningResultPage({super.key, required this.record});

  final RunningRecord record;

  /// 결과→홈: 러닝 흐름 이전 화면까지 모두 닫습니다.
  void _done(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 지도는 화면 전체에 깔리고, 경로는 아래 시트에 가리지 않는 위쪽에 맞춥니다.
    final sheetHeight = 430 + media.padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: FutureBuilder(
            future: record.places,
            builder: (context, snapshot) => _RecordMap(
              record: record,
              places: snapshot.data,
              fitPadding: EdgeInsets.fromLTRB(
                48,
                media.padding.top + 150,
                48,
                sheetHeight + 40,
              ),
              overlayBuilder: (camera) => Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.space4,
                          AppSpacing.topControlSafeAreaGapMax,
                          AppSpacing.space4,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                MapCircleButton(
                                  icon: Icons.close,
                                  tooltip: '닫기',
                                  onPressed: () => _done(context),
                                ),
                                const Spacer(),
                                _ShareButton(record: record),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.space5),
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '오늘의 러닝',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${RunningFormat.monthDay(record.startedAt)} · '
                                    '${RunningFormat.timeRange(record.startedAt, record.endedAt)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.mapScaleLeft,
                            0,
                            AppSpacing.space4,
                            AppSpacing.mapControlAboveCard,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MapScaleBar(camera: camera),
                              const Spacer(),
                              _BigMapButton(
                                record: record,
                                places: snapshot.data,
                              ),
                            ],
                          ),
                        ),
                        _ResultSheet(
                          record: record,
                          onDetail: () => Navigator.of(context).push(
                            runningPushRoute(
                              RunningRouteDetailPage(record: record),
                              AppMotion.detailPush,
                            ),
                          ),
                          onDone: () => _done(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.record,
    required this.onDetail,
    required this.onDone,
  });

  final RunningRecord record;
  final VoidCallback onDetail;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space3,
        AppSpacing.space5,
        AppSpacing.space4 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SheetHandle()),
          const SizedBox(height: AppSpacing.space4),
          const Text('총 거리', style: _labelStyle),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: UnitValue(
                    value: RunningFormat.km(record.distanceMeters),
                    unit: 'km',
                    size: runningHeroSize(context),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              _HetbahnBadge(record: record, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),
          _StatGrid(
            columns: 3,
            cells: [
              _GridCell(
                '운동 시간',
                RunningFormat.durationParts(record.movingDuration),
              ),
              _GridCell(
                '평균 페이스',
                RunningFormat.paceParts(record.paceSecondsPerKm),
              ),
              _GridCell('평균 속도', [
                (RunningFormat.speed(record.averageSpeedKmh), 'km/h'),
              ]),
              _GridCell('최고 속도', _speedParts(record.maxSpeedKmh)),
              _GridCell('소모 칼로리', [
                (RunningFormat.kcal(record.calories), 'kcal'),
              ]),
              _GridCell(
                '최고 페이스',
                RunningFormat.paceParts(record.bestPaceSecondsPerKm),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),
          Row(
            children: [
              Expanded(
                child: OutlineButton(label: '자세히 보기', onPressed: onDetail),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: WhiteButton(label: '완료', onPressed: onDone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════
// 10 러닝 경로 상세
// ═════════════════════════════════════════════════════

class RunningRouteDetailPage extends StatelessWidget {
  const RunningRouteDetailPage({super.key, required this.record});

  final RunningRecord record;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: FutureBuilder(
          future: record.places,
          builder: (context, snapshot) {
            final places = snapshot.data;
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.paddingOf(context).bottom + AppSpacing.space8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 300 + topInset,
                    child: _RecordMap(
                      record: record,
                      places: places,
                      interactive: false,
                      fitPadding: EdgeInsets.fromLTRB(
                        40,
                        topInset + 70,
                        40,
                        56,
                      ),
                      overlayBuilder: (camera) =>
                          _detailMapOverlay(context, places, camera),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.space6),
                        _DateHeader(record: record, places: places),
                        const SizedBox(height: AppSpacing.space6),
                        _Timeline(record: record, places: places),
                        const SizedBox(height: AppSpacing.space6),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.space6),
                        const Text('총 거리', style: _labelStyle),
                        const SizedBox(height: 6),
                        UnitValue(
                          value: RunningFormat.km(record.distanceMeters),
                          unit: 'km',
                          size: runningHeroSize(context),
                        ),
                        const SizedBox(height: AppSpacing.space5),
                        _StatGrid(
                          columns: 2,
                          cells: [
                            _GridCell(
                              '운동 시간',
                              RunningFormat.durationParts(
                                record.movingDuration,
                              ),
                            ),
                            _GridCell(
                              '평균 페이스',
                              RunningFormat.paceParts(record.paceSecondsPerKm),
                              suffix: '/km',
                            ),
                            _GridCell('평균 속도', [
                              (
                                RunningFormat.speed(record.averageSpeedKmh),
                                'km/h',
                              ),
                            ]),
                            _GridCell('최고 속도', _speedParts(record.maxSpeedKmh)),
                            _GridCell(
                              '최고 페이스',
                              RunningFormat.paceParts(
                                record.bestPaceSecondsPerKm,
                              ),
                              suffix: '/km',
                            ),
                            _GridCell('소모 칼로리', [
                              (RunningFormat.kcal(record.calories), 'kcal'),
                            ]),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sectionGapMax),
                        _TimeSection(record: record),
                        const SizedBox(height: AppSpacing.sectionGapMax),
                        _SpeedSection(record: record),
                        const SizedBox(height: AppSpacing.sectionGapMax),
                        _SplitSection(record: record),
                        const SizedBox(height: AppSpacing.sectionGapMax),
                        _CalorieSection(record: record),
                        const SizedBox(height: AppSpacing.space8),
                        Text(
                          [
                            'GPS 기록',
                            '1초 간격',
                            if (record.averageAccuracy case final a?)
                              '평균 정확도 ±${a.round()} m',
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _detailMapOverlay(
    BuildContext context,
    RunningPlaces? places,
    ValueListenable<MapViewport?> camera,
  ) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space4,
                AppSpacing.topControlSafeAreaGapMax,
                AppSpacing.space4,
                0,
              ),
              child: Row(
                children: [
                  MapCircleButton(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: '뒤로',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      '러닝 경로 상세',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _ShareButton(record: record),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.mapScaleLeft,
          right: AppSpacing.space4,
          bottom: AppSpacing.space3,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MapScaleBar(camera: camera),
              const Spacer(),
              _BigMapButton(record: record, places: places),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.record, required this.places});

  final RunningRecord record;
  final RunningPlaces? places;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          RunningFormat.fullDate(record.startedAt),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          [
            RunningFormat.timeRange(
              record.startedAt,
              record.endedAt,
              repeatPeriod: true,
            ),
            ?places?.area,
          ].join(' · '),
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// 출발→도착 타임라인: 주황 연결선 2.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.record, required this.places});

  final RunningRecord record;
  final RunningPlaces? places;

  @override
  Widget build(BuildContext context) {
    Widget stop(Widget marker, String label, String? place, DateTime time) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 26, child: Center(child: marker)),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  place ?? '-',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            RunningFormat.time(time),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        stop(const RouteMarker.start(), '출발', places?.start, record.startedAt),
        Row(
          children: [
            SizedBox(
              width: 26,
              height: 36,
              child: Center(
                child: Container(
                  width: AppComponentMetrics.timelineWidth,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Text(
                '${RunningFormat.km(record.distanceMeters)} km · '
                '${RunningFormat.koreanDuration(record.movingDuration)} 동안 달린 길',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
        stop(const RouteMarker.finish(), '도착', places?.end, record.endedAt),
      ],
    );
  }
}

class _TimeSection extends StatelessWidget {
  const _TimeSection({required this.record});

  final RunningRecord record;

  @override
  Widget build(BuildContext context) {
    final moving = record.movingDuration.inMilliseconds;
    final paused = record.pausedDuration.inMilliseconds;

    Widget legend(Color color, String label, Duration value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, color: color),
            const SizedBox(width: 6),
            Text(label, style: _labelStyle),
          ],
        ),
        const SizedBox(height: 6),
        PartsValue(parts: RunningFormat.durationParts(value), size: 22),
      ],
    );

    Widget row(String label, String value) => Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: '시간',
          info: '전체 ${RunningFormat.koreanDuration(record.totalDuration)}',
        ),
        const SizedBox(height: AppSpacing.space4),
        SizedBox(
          height: 10,
          child: Row(
            children: [
              Expanded(
                flex: math.max(moving, 1),
                child: Container(color: AppColors.textPrimary),
              ),
              if (paused > 0) ...[
                const SizedBox(width: 2),
                Expanded(
                  flex: paused,
                  child: Container(color: AppColors.borderControl),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        Row(
          children: [
            Expanded(
              child: legend(
                AppColors.textPrimary,
                '이동 시간',
                record.movingDuration,
              ),
            ),
            Expanded(
              child: legend(
                AppColors.borderControl,
                '일시정지 시간',
                record.pausedDuration,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space4),
        row('시작 시간', RunningFormat.time(record.startedAt)),
        row('종료 시간', RunningFormat.time(record.endedAt)),
      ],
    );
  }
}

class _SpeedSection extends StatelessWidget {
  const _SpeedSection({required this.record});

  final RunningRecord record;

  @override
  Widget build(BuildContext context) {
    final enough = record.speedSamples.length >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: '속도',
          info: '평균 ${RunningFormat.speed(record.averageSpeedKmh)} km/h · 점선',
        ),
        const SizedBox(height: AppSpacing.space4),
        SizedBox(
          height: 170,
          child: enough
              ? CustomPaint(painter: _SpeedChartPainter(record))
              : const Center(
                  child: Text(
                    '속도를 그리기에는 기록이 짧아요',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
        ),
        if (enough && record.pausePoints.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space3),
          const Row(
            children: [
              _PauseDot(),
              SizedBox(width: 6),
              Text(
                '일시정지한 지점',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SplitSection extends StatelessWidget {
  const _SplitSection({required this.record});

  final RunningRecord record;

  @override
  Widget build(BuildContext context) {
    final splits = record.splits;
    final full = splits.where((s) => s.isFull).toList();
    final paces = full.map((s) => s.paceSecondsPerKm);
    final fastest = full.length >= 2
        ? full.reduce(
            (a, b) => a.paceSecondsPerKm <= b.paceSecondsPerKm ? a : b,
          )
        : null;
    final minPace = paces.isEmpty ? 0.0 : paces.reduce(math.min);
    final maxPace = paces.isEmpty ? 0.0 : paces.reduce(math.max);

    // 선이 길수록 빠른 구간. 가장 느린 구간도 45%는 보이게 합니다.
    double barFraction(double pace) => maxPace == minPace
        ? 1
        : 0.45 + 0.55 * (maxPace - pace) / (maxPace - minPace);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: '구간 기록', info: '1 km 페이스'),
        const SizedBox(height: AppSpacing.space3),
        if (splits.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
            child: Text(
              '구간을 나누기에는 거리가 짧아요',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ),
        for (final split in splits)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: split.isFull
                      ? Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${split.index}',
                                style: runningNumberStyle(15),
                              ),
                              const TextSpan(
                                text: ' km',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          (split.meters / 1000).toStringAsFixed(2),
                          style: runningNumberStyle(
                            15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
                Expanded(
                  child: split.isFull
                      ? Row(
                          children: [
                            Expanded(
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: barFraction(
                                  split.paceSecondsPerKm,
                                ),
                                child: Container(
                                  height: identical(split, fastest)
                                      ? AppComponentMetrics.fastestSplitBarWidth
                                      : AppComponentMetrics.splitBarWidth,
                                  decoration: BoxDecoration(
                                    color: identical(split, fastest)
                                        ? AppColors.primary
                                        : AppColors.textPrimary.withValues(
                                            alpha: 0.7,
                                          ),
                                    borderRadius: AppRadius.pillBorder,
                                  ),
                                ),
                              ),
                            ),
                            if (identical(split, fastest))
                              const Padding(
                                padding: EdgeInsets.only(
                                  left: AppSpacing.space2,
                                ),
                                child: Text(
                                  '가장 빠른 구간',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Text(
                          '남은 ${RunningFormat.km(split.meters)} km · '
                          '${RunningFormat.clock(split.duration)} 걸림',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    RunningFormat.livePace(split.paceSecondsPerKm)
                        .replaceAll('′', "'")
                        .replaceAll('″', '"'),
                    textAlign: TextAlign.right,
                    style: runningNumberStyle(
                      17,
                      color: identical(split, fastest)
                          ? AppColors.primary
                          : split.isFull
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (full.length >= 2) ...[
          const SizedBox(height: AppSpacing.space2),
          const Text(
            '선이 길수록 빠르게 달린 구간이에요',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }
}

class _CalorieSection extends StatelessWidget {
  const _CalorieSection({required this.record});

  final RunningRecord record;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: '소모 칼로리'),
        const SizedBox(height: AppSpacing.space4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: UnitValue(
                  value: RunningFormat.kcal(record.calories),
                  unit: 'kcal',
                  size: 48,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            _HetbahnBadge(record: record, compact: false),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════
// 지도
// ═════════════════════════════════════════════════════

/// 기록 경로 지도: 경로 전체가 보이게 맞추고 출발·도착 지명을 붙입니다.
/// 버튼·시트는 [overlayBuilder]로 지도 위에 겹칩니다. 지도 children에 두면
/// 그 위의 드래그가 지도를 움직이기 때문입니다.
class _RecordMap extends StatefulWidget {
  const _RecordMap({
    required this.record,
    required this.places,
    required this.fitPadding,
    this.overlayBuilder,
    this.interactive = true,
  });

  final RunningRecord record;
  final RunningPlaces? places;
  final EdgeInsets fitPadding;
  final Widget Function(ValueListenable<MapViewport?> camera)? overlayBuilder;
  final bool interactive;

  @override
  State<_RecordMap> createState() => _RecordMapState();
}

class _RecordMapState extends State<_RecordMap> {
  final _controller = RunneryMapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final places = widget.places;
    final coords = [for (final p in record.points) p.latLng];
    final first = coords.firstOrNull;
    final last = coords.length >= 2 ? coords.last : null;
    final finishIsNorth =
        first != null && last != null && last.latitude > first.latitude;

    final map = RunneryMap(
      controller: _controller,
      initialCenter:
          first ??
          record.pausePoints.firstOrNull?.latLng ??
          const LatLng(37.5665, 126.9780),
      initialZoom: MapZoom.basic,
      interactive: widget.interactive,
      routeWidth: RouteWidth.detail,
      route: [
        for (final segment in record.segments)
          [for (final p in segment) p.latLng],
      ],
      markers: [
        if (first != null) MapMarker(first, MapMarkerKind.start),
        if (last != null) MapMarker(last, MapMarkerKind.finish),
      ],
      // 출발·도착이 가까우면 칩이 서로의 마커를 가리므로 바깥쪽으로 벌립니다.
      labels: [
        if (first != null)
          MapLabel(
            first,
            MapLabelKind.start,
            places?.start,
            above: !finishIsNorth,
          ),
        if (last != null)
          MapLabel(
            last,
            MapLabelKind.finish,
            places?.end,
            above: finishIsNorth,
          ),
      ],
      fitPoints: coords,
      fitPadding: widget.fitPadding,
    );
    final overlay = widget.overlayBuilder?.call(_controller);
    return overlay == null ? map : Stack(children: [map, overlay]);
  }
}

/// '지도 크게 보기' → 전체 화면 지도.
class _BigMapButton extends StatelessWidget {
  const _BigMapButton({required this.record, required this.places});

  final RunningRecord record;
  final RunningPlaces? places;

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: '지도 크게 보기',
      icon: Icons.open_in_full,
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) =>
              _FullMapPage(record: record, places: places),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: AppMotion.pushSlideCurve,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullMapPage extends StatelessWidget {
  const _FullMapPage({required this.record, required this.places});

  final RunningRecord record;
  final RunningPlaces? places;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppColors.mapLand,
      body: _RecordMap(
        record: record,
        places: places,
        fitPadding: EdgeInsets.fromLTRB(
          40,
          media.padding.top + 80,
          40,
          media.padding.bottom + 60,
        ),
        overlayBuilder: (camera) => Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space4,
                    AppSpacing.topControlSafeAreaGapMax,
                    0,
                    0,
                  ),
                  child: MapCircleButton(
                    icon: Icons.close,
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.mapScaleLeft,
              bottom: media.padding.bottom + AppSpacing.space4,
              child: MapScaleBar(camera: camera),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════
// 공통 조각
// ═════════════════════════════════════════════════════

const _labelStyle = TextStyle(fontSize: 12, color: AppColors.textSecondary);

List<(String, String)> _speedParts(double? kmh) =>
    kmh == null ? [('-', '')] : [(RunningFormat.speed(kmh), 'km/h')];

/// 18-3 친구에게 기록 공유 창을 엽니다. 저장된 기록과 같은 번호로 올라가고, 장소 이름도 함께 담습니다.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.record});

  final RunningRecord record;

  Future<void> _share(BuildContext context) async {
    final places = await record.places;
    if (!context.mounted) return;
    await showShareRecordSheet(
      context,
      recordFromSession(record)
          .withPlaces(area: places.area, start: places.start, end: places.end),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MapCircleButton(
      icon: Icons.ios_share,
      tooltip: '친구에게 공유',
      onPressed: () => _share(context),
    );
  }
}

/// 섹션 헤더: 제목 + 선 + 보조 정보.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.info});

  final String title;
  final String? info;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        const Expanded(
          child: Divider(color: AppColors.borderDefault, height: 1),
        ),
        if (info != null) ...[
          const SizedBox(width: AppSpacing.space3),
          Text(
            info!,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }
}

class _GridCell {
  const _GridCell(this.label, this.parts, {this.suffix});
  final String label;
  final List<(String, String)> parts;
  final String? suffix;
}

/// 스탯 그리드: 위·사이 구분선 1.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.columns, required this.cells});

  final int columns;
  final List<_GridCell> cells;

  @override
  Widget build(BuildContext context) {
    final rows = <List<_GridCell>>[
      for (var i = 0; i < cells.length; i += columns)
        cells.sublist(i, math.min(i + columns, cells.length)),
    ];
    return Column(
      children: [
        for (final row in rows)
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  for (final (i, cell) in row.indexed) ...[
                    if (i > 0) const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          i == 0 ? 0 : 14,
                          14,
                          8,
                          14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cell.label, style: _labelStyle),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: PartsValue(
                                parts: cell.parts,
                                size: columns == 3 ? 22 : 26,
                                suffix: cell.suffix,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 햇반 환산 카드. 결과에서만 개수를 주황으로 강조합니다.
class _HetbahnBadge extends StatelessWidget {
  const _HetbahnBadge({required this.record, required this.compact});

  final RunningRecord record;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: const Icon(
            Icons.rice_bowl_outlined,
            size: 22,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '햇반 약 '),
                  TextSpan(
                    text: '${RunningFormat.hetbahn(record.hetbahnCount)}개',
                    style: TextStyle(
                      color: compact
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              compact
                  ? '1개 = ${RunningConfig.hetbahnKcal.round()} kcal'
                  : '1개(210g) = ${RunningConfig.hetbahnKcal.round()} kcal',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PauseDot extends StatelessWidget {
  const _PauseDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textTertiary),
      ),
      child: const Icon(Icons.pause, size: 10, color: AppColors.textTertiary),
    );
  }
}

/// 속도 그래프: 흰 선, 평균 점선, 최고 속도 주황 점, 일시정지 지점.
class _SpeedChartPainter extends CustomPainter {
  _SpeedChartPainter(this.record);

  final RunningRecord record;

  static const _left = 26.0;
  static const _right = 22.0;
  static const _top = 26.0;
  static const _bottom = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    // 5개 이동 평균으로 GPS 잔떨림을 줄입니다.
    final raw = record.speedSamples;
    final samples = [
      for (var i = 0; i < raw.length; i++)
        SpeedSample(
          raw[i].km,
          raw
                  .sublist(math.max(0, i - 2), math.min(raw.length, i + 3))
                  .map((s) => s.kmh)
                  .reduce((a, b) => a + b) /
              (math.min(raw.length, i + 3) - math.max(0, i - 2)),
        ),
    ];
    final maxKmh = samples.map((s) => s.kmh).reduce(math.max);
    final minKmh = samples.map((s) => s.kmh).reduce(math.min);
    final yMin = math.max(0, ((minKmh - 1) / 2).floor() * 2).toDouble();
    final yMax = math.max(yMin + 4, ((maxKmh + 1) / 2).ceil() * 2).toDouble();
    final totalKm = math.max(record.distanceMeters / 1000, samples.last.km);

    final chart = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );
    Offset at(double km, double kmh) => Offset(
      chart.left + chart.width * (km / totalKm),
      chart.bottom - chart.height * ((kmh - yMin) / (yMax - yMin)),
    );

    final labelStyle = const TextStyle(
      fontSize: 10,
      color: AppColors.textTertiary,
    );
    void label(
      String text,
      Offset anchor, {
      Alignment align = Alignment.center,
    }) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        anchor -
            Offset(tp.width * (align.x + 1) / 2, tp.height * (align.y + 1) / 2),
      );
    }

    // y축 눈금 3개
    for (final v in [yMin, (yMin + yMax) / 2, yMax]) {
      final y = at(0, v).dy;
      canvas.drawLine(
        Offset(chart.left, y),
        Offset(chart.right, y),
        Paint()..color = AppColors.divider,
      );
      label(
        v.round().toString(),
        Offset(chart.left - 6, y),
        align: Alignment.centerRight,
      );
    }

    // x축 km 눈금
    final step = totalKm <= 8 ? 1 : (totalKm <= 16 ? 2 : 5);
    if (totalKm < 1) {
      label(
        '0',
        Offset(chart.left, chart.bottom + 4),
        align: Alignment.topCenter,
      );
    } else {
      for (var km = 0; km <= totalKm; km += step) {
        label(
          '$km',
          Offset(at(km.toDouble(), yMin).dx, chart.bottom + 4),
          align: Alignment.topCenter,
        );
      }
    }
    label(
      'km',
      Offset(size.width, chart.bottom + 4),
      align: Alignment.topRight,
    );

    // 평균 점선
    final avgY = at(0, record.averageSpeedKmh.clamp(yMin, yMax)).dy;
    final dash = Paint()
      ..color = AppColors.textTertiary
      ..strokeWidth = 1;
    for (var x = chart.left; x < chart.right; x += 6) {
      canvas.drawLine(
        Offset(x, avgY),
        Offset(math.min(x + 3, chart.right), avgY),
        dash,
      );
    }

    // 속도 선
    final path = Path()
      ..moveTo(
        at(samples.first.km, samples.first.kmh).dx,
        at(samples.first.km, samples.first.kmh).dy,
      );
    for (final s in samples.skip(1)) {
      final o = at(s.km, s.kmh);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.textPrimary,
    );

    // 최고 속도 (원본 최고값이 아닌 그래프상의 최고점에 표시)
    final top = samples.reduce((a, b) => a.kmh >= b.kmh ? a : b);
    final topOffset = at(top.km, top.kmh);
    canvas.drawCircle(topOffset, 4, Paint()..color = AppColors.primary);
    final topLabel = TextPainter(
      text: TextSpan(
        text: '최고 ${RunningFormat.speed(record.maxSpeedKmh ?? top.kmh)} km/h',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelX = (topOffset.dx - topLabel.width / 2).clamp(
      0.0,
      size.width - topLabel.width,
    );
    topLabel.paint(canvas, Offset(labelX, topOffset.dy - topLabel.height - 8));

    // 일시정지 지점: 위쪽 동그라미 + 세로 점선
    for (final pause in record.pausePoints) {
      final x = at(pause.meters / 1000, yMin).dx;
      for (var y = chart.top; y < chart.bottom; y += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + 3, chart.bottom)),
          dash,
        );
      }
      final c = Offset(x, chart.top - 12);
      canvas
        ..drawCircle(c, 8, Paint()..color = AppColors.background)
        ..drawCircle(
          c,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = AppColors.textTertiary,
        );
      final bar = Paint()
        ..color = AppColors.textSecondary
        ..strokeWidth = 1.5;
      canvas
        ..drawLine(c + const Offset(-2, -3), c + const Offset(-2, 3), bar)
        ..drawLine(c + const Offset(2, -3), c + const Offset(2, 3), bar);
    }
  }

  @override
  bool shouldRepaint(_SpeedChartPainter old) => old.record != record;
}
