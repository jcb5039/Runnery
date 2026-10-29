import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../home/running/running_start_page.dart' show runningNumberStyle;
import '../data/friend_store.dart';
import '../data/ranking.dart';
import '../widgets/friend_widgets.dart';
import 'goal_edit_sheet.dart';

/// 17-2 러닝 목표 비교: 이번 주 내 목표와 진행, 목표를 공개한 친구들의 달성률.
class FriendGoalTab extends StatelessWidget {
  const FriendGoalTab({super.key, required this.store});

  final FriendStore store;

  @override
  Widget build(BuildContext context) {
    final me = store.me;
    if (me == null) return const SizedBox.shrink();
    final now = store.now;
    final goal = store.goal;
    final rows = goalRows(me, store.myStats, goal, store.friendStats, now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (goal == null) _noGoal(context) else _myGoal(context, goal, now),
        const SizedBox(height: 26),
        const FriendSectionHeader(title: '친구들과 비교', meta: '달성률 높은 순'),
        const SizedBox(height: 6),
        if (store.statsError case final error?)
          _note(error)
        else if (rows.isEmpty)
          _note('아직 목표를 공개한 친구가 없어요')
        else
          for (final (i, row) in rows.indexed)
            _GoalTile(row: row, divider: i > 0),
        const SizedBox(height: 16),
        const Text(
          '목표를 공개한 친구만 보여요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _noGoal(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이번 주 목표를 정해 보세요',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '이번 주에 ${store.myStats.weekKmAt(store.now).toStringAsFixed(1)} km 달렸어요. '
          '목표를 정하면 친구들과 달성률을 비교할 수 있어요.',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        FriendPillButton(
          label: '목표 정하기',
          onPressed: () => showGoalEditSheet(context, store),
        ),
      ],
    ),
  );

  Widget _myGoal(BuildContext context, WeeklyGoal goal, DateTime now) {
    final done = store.myStats.weekKmAt(now);
    final percent = (done / goal.km * 100).floor();
    final left = (goal.km - done).clamp(0.0, double.infinity);
    // 오늘을 포함해 일요일까지 남은 날.
    final daysLeft = 8 - now.weekday;
    final perDay = left / daysLeft;
    final period = RankingKind.weekDistance.period(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '이번 주 내 목표',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$period · $daysLeft일 남았어요'
                    '${goal.public ? '' : ' · 비공개'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            FriendPillButton(
              label: '목표 수정',
              filled: false,
              onPressed: () => showGoalEditSheet(context, store),
            ),
          ],
        ),
        const SizedBox(height: 22),
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
                      done.toStringAsFixed(1),
                      style: runningNumberStyle(64, weight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ ${goal.km} km',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            _NumberUnit(value: '$percent', unit: '%', size: 40, unitSize: 16),
          ],
        ),
        const SizedBox(height: 16),
        FriendProgressBar(
          fraction: done / goal.km,
          color: AppColors.primary,
          height: 8,
        ),
        const SizedBox(height: 18),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cell('남은 거리', left.toStringAsFixed(1), 'km', first: true),
                _cell('남은 날', '$daysLeft', '일'),
                _cell('하루에', perDay.toStringAsFixed(1), 'km'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(String label, String value, String unit, {bool first = false}) =>
      Expanded(
        child: Container(
          padding: EdgeInsets.fromLTRB(first ? 0 : 14, 12, 0, 14),
          decoration: BoxDecoration(
            border: first
                ? null
                : const Border(left: BorderSide(color: AppColors.divider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _NumberUnit(value: value, unit: unit, size: 22, unitSize: 11),
            ],
          ),
        ),
      );

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
    ),
  );
}

class _NumberUnit extends StatelessWidget {
  const _NumberUnit({
    required this.value,
    required this.unit,
    required this.size,
    required this.unitSize,
  });

  final String value, unit;
  final double size, unitSize;

  /// 칸이 좁으면 글자를 줄여 넘치지 않게 합니다.
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: runningNumberStyle(size, weight: FontWeight.w600)),
        const SizedBox(width: 3),
        Text(
          unit,
          style: TextStyle(
            fontSize: unitSize,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

/// 목표 비교 한 줄.
class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.row, required this.divider});

  final GoalRow row;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 68),
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: divider ? AppColors.divider : Colors.transparent,
        ),
      ),
    ),
    child: Row(
      children: [
        FriendAvatar(
          initial: row.person.initial,
          borderColor: row.me ? AppColors.primary : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      row.person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (row.achieved) ...[
                    const SizedBox(width: 6),
                    const FriendChip(
                      label: '달성',
                      filled: true,
                      icon: Icons.check,
                    ),
                  ],
                  if (row.me) ...[
                    const SizedBox(width: 6),
                    const FriendChip(label: '나'),
                  ],
                  const Spacer(),
                  Text(
                    row.doneKm.toStringAsFixed(1),
                    style: runningNumberStyle(15, weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '/ ${row.goalKm} km',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              FriendProgressBar(
                fraction: row.doneKm / row.goalKm,
                color: row.achieved
                    ? AppColors.textPrimary
                    : AppColors.borderControl,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 56,
          child: Align(
            alignment: Alignment.centerRight,
            child: _NumberUnit(
              value: '${row.percent}',
              unit: '%',
              size: 22,
              unitSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}
