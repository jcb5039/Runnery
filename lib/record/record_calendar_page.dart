import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';

import 'list/record_list_page.dart';
import 'list/detail/record_detail_page.dart';

/// 단독 라우트 또는 RecordListPageV2의 달력 본문으로 사용할 수 있습니다.
class RecordCalendarPage extends StatefulWidget {
  const RecordCalendarPage({
    super.key,
    this.records,
    this.month,
    this.selectedDay,
    this.onDaySelected,
    this.onRecordTap,
    this.embedded = false,
    this.onHome,
    this.onProfile,
  });
  final List<RunningRecord>? records;
  final DateTime? month, selectedDay;
  final ValueChanged<DateTime>? onDaySelected;
  final ValueChanged<RunningRecord>? onRecordTap;
  final VoidCallback? onHome, onProfile;
  final bool embedded;
  @override
  State<RecordCalendarPage> createState() => _RecordCalendarPageState();
}

class _RecordCalendarPageState extends State<RecordCalendarPage> {
  DateTime? _selection;
  List<RunningRecord> get records => widget.records ?? const [];
  DateTime get month => widget.month ?? DateTime.now();
  List<RunningRecord> _on(DateTime day) =>
      records.where((r) => DateUtils.isSameDay(r.startedAt, day)).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  DateTime get selected {
    if (widget.selectedDay != null) return widget.selectedDay!;
    if (_selection != null && DateUtils.isSameMonth(_selection, month)) {
      return _selection!;
    }
    final available =
        records.where((r) => DateUtils.isSameMonth(r.startedAt, month)).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return available.isEmpty
        ? DateTime(month.year, month.month)
        : available.first.startedAt;
  }

  void _open(RunningRecord record) {
    if (widget.onRecordTap != null) {
      widget.onRecordTap!(record);
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => RecordDetailPage(record: record)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedded) {
      return RecordListPageV2(
        records: widget.records,
        initialMonth: widget.month,
        initialCalendar: true,
        onHome: widget.onHome,
        onProfile: widget.onProfile,
      );
    }
    final first = DateTime(month.year, month.month);
    final offset = first.weekday % 7;
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final cells = ((offset + count) / 7).ceil() * 7;
    final runs = _on(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            for (final day in ['일', '월', '화', '수', '목', '금', '토'])
              Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: recordText(12, color: recordMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 66,
          ),
          itemBuilder: (context, index) {
            final number = index - offset + 1;
            if (number < 1 || number > count) return const SizedBox.shrink();
            final day = DateTime(month.year, month.month, number);
            final entries = _on(day),
                active = DateUtils.isSameDay(selected, day);
            final today = DateUtils.isSameDay(day, DateTime.now());
            return Semantics(
              label: '${month.month}월 $number일, 러닝 ${entries.length}건',
              selected: active,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(17),
                onTap: () {
                  setState(() => _selection = day);
                  widget.onDaySelected?.call(day);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 1,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.pick(
                            const Color(0xFF151616),
                            AppColors.card,
                          )
                        : Colors.transparent,
                    border: active
                        ? Border.all(color: AppColors.textPrimary)
                        : null,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        '$number',
                        style: recordNumber(
                          16,
                          color: entries.isEmpty
                              ? recordMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 15,
                        height: 2,
                        color: today
                            ? AppColors.textPrimary
                            : Colors.transparent,
                      ),
                      const SizedBox(height: 5),
                      // 그날 여러 번 달렸다면 가장 긴 거리의 경로만 그립니다.
                      if (entries.isNotEmpty)
                        SizedBox(
                          width: 30,
                          height: 18,
                          child: MiniRunningRoute(
                            coordinates: entries
                                .reduce(
                                  (a, b) => b.distanceKm > a.distanceKm ? b : a,
                                )
                                .route,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.route, size: 18, color: recordOrange),
            const SizedBox(width: 6),
            Text(
              '달린 날엔 그날의 경로가 그려져요',
              style: recordText(12, color: recordMuted),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Divider(height: 1, color: recordLine),
        if (runs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 44),
            child: Text(
              '선택한 날짜에는 러닝 기록이 없어요',
              textAlign: TextAlign.center,
              style: recordText(14, color: recordMuted),
            ),
          )
        else
          for (final r in runs) _card(r),
      ],
    );
  }

  Widget _card(RunningRecord r) => Semantics(
    button: true,
    label: '${r.dateLabel} ${r.distanceKm.toStringAsFixed(2)} km 기록 상세',
    child: InkWell(
      onTap: () => _open(r),
      child: Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.dateLabel,
                    style: recordText(17, weight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${clockText(r.startedAt)} · ${r.place}',
                  style: recordText(11, color: recordSecondary),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 176,
              child: RecordRouteMap(record: r, basemap: true),
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _metric('거리', r.distanceKm.toStringAsFixed(2), 'km'),
                  VerticalDivider(width: 24, color: recordLine),
                  _metric(
                    '운동 시간',
                    '${r.movingSeconds ~/ 60}:${(r.movingSeconds % 60).toString().padLeft(2, '0')}',
                    '',
                  ),
                  VerticalDivider(width: 24, color: recordLine),
                  _metric('페이스', r.paceLabel, ''),
                  VerticalDivider(width: 24, color: recordLine),
                  _metric('칼로리', '${r.calories}', 'kcal'),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _metric(String label, String value, String unit) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: recordText(11, color: recordSecondary)),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: recordNumber(23)),
                TextSpan(
                  text: unit,
                  style: recordText(10, color: recordSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
