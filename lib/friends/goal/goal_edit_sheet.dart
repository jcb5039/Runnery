import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../home/running/running_start_page.dart' show runningNumberStyle;
import '../data/friend_store.dart';
import '../widgets/friend_widgets.dart';

/// 17-3 주간 목표 설정 창. 저장하면 true를 돌려줍니다.
Future<bool> showGoalEditSheet(BuildContext context, FriendStore store) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.card,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _GoalSheet(store: store),
  );
  return saved ?? false;
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.store});

  final FriendStore store;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  static const _presets = [10, 15, 20, 30];

  late int _km = widget.store.goal?.km ?? 20;
  late bool _public = widget.store.goal?.public ?? true;
  bool _saving = false;
  String? _error;

  void _set(int km) =>
      setState(() => _km = km.clamp(WeeklyGoal.minKm, WeeklyGoal.maxKm));

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.store.saveGoal(WeeklyGoal(km: _km, public: _public));
      if (mounted) Navigator.pop(context, true);
    } on FriendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.store.myStats.weekKmAt(widget.store.now);
    final left = _km - done;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '이번 주 목표 거리',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              '매주 월요일에 새로 시작돼요. 친구들은 내 달성률을 볼 수 있어요.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                _RoundButton(
                  icon: Icons.remove,
                  tooltip: '1 km 줄이기',
                  onPressed: _km > WeeklyGoal.minKm
                      ? () => _set(_km - 1)
                      : null,
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$_km',
                        style: runningNumberStyle(80, weight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'km',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundButton(
                  icon: Icons.add,
                  tooltip: '1 km 늘리기',
                  onPressed: _km < WeeklyGoal.maxKm
                      ? () => _set(_km + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              left > 0
                  ? '지금까지 ${done.toStringAsFixed(1)} km · ${left.toStringAsFixed(1)} km 더 달리면 달성'
                  : '지금까지 ${done.toStringAsFixed(1)} km · 이미 달성했어요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                for (final (i, km) in _presets.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: FriendPillButton(
                      label: '$km km',
                      filled: km == _km,
                      onPressed: () => _set(km),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),
            const Divider(height: 1, color: AppColors.divider),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _public,
              onChanged: (v) => setState(() => _public = v),
              activeTrackColor: Colors.white,
              activeThumbColor: AppColors.background,
              inactiveTrackColor: AppColors.divider,
              inactiveThumbColor: AppColors.textSecondary,
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
              title: const Text(
                '친구에게 목표 공개',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                '끄면 친구 목표 비교에 내가 보이지 않아요',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 18),
            FriendSheetButton(
              label: _saving ? '저장하는 중이에요' : '이 목표로 저장',
              filled: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      fixedSize: const Size.square(56),
      foregroundColor: AppColors.textPrimary,
      side: const BorderSide(color: AppColors.borderDefault),
    ),
  );
}
