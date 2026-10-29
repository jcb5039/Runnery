import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../home/running/running_start_page.dart' show runningNumberStyle;
import '../data/friend_store.dart';
import '../data/ranking.dart';
import '../widgets/friend_widgets.dart';

/// 17-1 친구 랭킹: 주간 거리·주간 횟수·월간 거리로 나와 친구들의 순위를 보여 줍니다.
/// 비공개 기록도 합계에 들어갑니다(친구에게는 합계만 갑니다).
class FriendRankingTab extends StatefulWidget {
  const FriendRankingTab({super.key, required this.store});

  final FriendStore store;

  @override
  State<FriendRankingTab> createState() => _FriendRankingTabState();
}

class _FriendRankingTabState extends State<FriendRankingTab> {
  RankingKind _kind = RankingKind.weekDistance;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final me = store.me;
    if (me == null) return const SizedBox.shrink();
    final now = store.now;
    final rows = rankRows(_kind, me, store.myStats, store.friendStats, now);
    final mine = rows.firstWhere((r) => r.me);
    final gap = gapAbove(rows);
    final top = rows.isEmpty ? 0.0 : rows.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final kind in RankingKind.values)
                    _KindChip(
                      label: kind.label,
                      selected: kind == _kind,
                      onTap: () => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _summary(rows.length, mine, gap, rows),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.borderDefault),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _kind.period(now),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _kind.reset,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final row in rows)
          _RankTile(
            row: row,
            unit: _kind.unit,
            value: _kind.format(row.value),
            fraction: top <= 0 ? 0 : row.value / top,
          ),
        if (store.statsError case final error?)
          _note(error)
        else if (rows.length == 1)
          _note('친구를 추가하면 함께 순위를 겨룰 수 있어요'),
      ],
    );
  }

  Widget _summary(
    int count,
    RankRow mine,
    (RankRow, double)? gap,
    List<RankRow> rows,
  ) {
    // 바로 위 사람까지 남은 차이. 1위면 2위와의 차이를 보여 줍니다.
    final second = rows.where((r) => !r.me).firstOrNull;
    final (String, String, String)? side = switch (gap) {
      (final ahead, final diff) => (
        '${ahead.rank}위 ${ahead.person.name}까지',
        _kind.format(diff),
        '남았어요',
      ),
      null when second != null && mine.value > second.value => (
        '${second.rank}위 ${second.person.name}보다',
        _kind.format(mine.value - second.value),
        '앞섰어요',
      ),
      _ => null,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _kind.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${mine.rank}',
                    style: runningNumberStyle(72, weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '위',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$count명 중',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (side case (final label, final value, final suffix))
          Container(
            padding: const EdgeInsets.only(left: 16),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.divider)),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: runningNumberStyle(26, weight: FontWeight.w600),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _kind.unit,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      suffix,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
    ),
  );
}

/// 랭킹 기준 고르기 버튼.
class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.textPrimary : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.textPrimary : AppColors.borderDefault,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.background : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 랭킹 한 줄. 내 줄은 바탕을 칠하고 막대를 주황으로 그립니다.
class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.row,
    required this.unit,
    required this.value,
    required this.fraction,
  });

  final RankRow row;
  final String unit, value;
  final double fraction;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    margin: const EdgeInsets.only(bottom: 2),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: row.me ? AppColors.card : Colors.transparent,
      borderRadius: AppRadius.thumbnailBorder,
    ),
    child: Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(
            '${row.rank}',
            textAlign: TextAlign.center,
            style: runningNumberStyle(22, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
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
                  if (row.me) ...[
                    const SizedBox(width: 6),
                    const FriendChip(label: '나'),
                  ],
                ],
              ),
              const SizedBox(height: 9),
              FriendProgressBar(
                fraction: fraction,
                color: row.me ? AppColors.primary : AppColors.borderControl,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: runningNumberStyle(22, weight: FontWeight.w600),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
