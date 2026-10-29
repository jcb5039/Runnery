import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_spacing.dart';
import '../../record/data/running_record_store.dart';
import '../../record/models/running_record.dart';
import '../data/friend_store.dart';
import '../data/record_share.dart';
import '../widgets/friend_widgets.dart';

/// 18-4 기록 공개 설정: 자동 공유를 켜고 끄고, 이번 주 기록을 하나씩 공개·비공개로 바꿉니다.
class RecordVisibilityPage extends StatefulWidget {
  const RecordVisibilityPage({super.key, this.share, this.records, this.now});

  /// 테스트에서만 넣습니다. 없으면 앱 전체 공유 담당과 폰에 저장된 기록을 씁니다.
  final RecordShare? share;
  final Future<List<RunningRecord>> Function()? records;
  final DateTime? now;

  @override
  State<RecordVisibilityPage> createState() => _RecordVisibilityPageState();
}

class _RecordVisibilityPageState extends State<RecordVisibilityPage> {
  RecordShare get _share => widget.share ?? RecordShare.instance;

  ShareSettings? _settings;
  List<RunningRecord>? _week;
  Set<String> _shared = {};
  String? _error;
  final Set<String> _busy = {};
  bool _savingAuto = false;

  /// 이번 주 월요일 0시.
  DateTime get _weekStart {
    final now = widget.now ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final load = widget.records ?? RunningRecordStore.instance.load;
      final start = _weekStart;
      final (settings, shared, records) = await (
        _share.settings(),
        _share.loadShared(start),
        load(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _shared = shared;
        _week = [
          for (final r in records)
            if (!r.startedAt.isBefore(start)) r,
        ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        _error = null;
      });
    } on ParallelWaitError<
      (ShareSettings?, Set<String>?, List<RunningRecord>?),
      (AsyncError?, AsyncError?, AsyncError?)
    > catch (e) {
      final errors = [e.errors.$1, e.errors.$2, e.errors.$3];
      final reason = errors
          .map((a) => a?.error)
          .whereType<FriendException>()
          .firstOrNull;
      if (mounted) {
        setState(() => _error = reason?.message ?? '기록을 불러오지 못했어요');
      }
    }
  }

  Future<void> _toggleAuto(bool value) async {
    final settings = _settings;
    if (settings == null || _savingAuto) return;
    setState(() {
      _savingAuto = true;
      _settings = settings.copyWith(autoShare: value);
    });
    try {
      await _share.saveSettings(settings.copyWith(autoShare: value));
    } on FriendException catch (e) {
      if (mounted) {
        setState(() => _settings = settings);
        showFriendMessage(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _savingAuto = false);
    }
  }

  Future<void> _toggle(RunningRecord record, bool public) async {
    if (_busy.contains(record.id)) return;
    setState(() {
      _busy.add(record.id);
      public ? _shared.add(record.id) : _shared.remove(record.id);
    });
    try {
      public ? await _share.share(record) : await _share.unshare(record.id);
    } on FriendException catch (e) {
      if (mounted) {
        setState(() {
          public ? _shared.remove(record.id) : _shared.add(record.id);
        });
        showFriendMessage(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(record.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings, week = _week;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: friendAppBar(context, '기록 공개 설정'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.space4,
            AppSpacing.screenHorizontal,
            AppSpacing.space6,
          ),
          children: [
            _label('자동 공유'),
            _row(
              title: '러닝이 끝나면 친구에게 공유',
              subtitle: '끄면 공유할 기록을 직접 골라요',
              trailing: _switch(
                settings?.autoShare ?? false,
                settings == null ? null : _toggleAuto,
                '러닝이 끝나면 친구에게 공유',
              ),
            ),
            _row(
              title: '공개 범위',
              divider: true,
              trailing: const Text(
                '모든 친구',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(child: _label('이번 주 기록')),
                if (week != null && week.isNotEmpty)
                  Text(
                    '공개 ${week.where((r) => _shared.contains(r.id)).length}개 · '
                    '비공개 ${week.where((r) => !_shared.contains(r.id)).length}개',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
            if (_error case final error?)
              _note(error)
            else if (week == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (week.isEmpty)
              _note('이번 주에 달린 기록이 없어요')
            else
              for (final (i, record) in week.indexed) _recordRow(record, i > 0),
            const SizedBox(height: 16),
            const Text(
              '비공개로 바꾼 기록은 친구 피드에 보이지 않아요.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordRow(RunningRecord record, bool divider) {
    final public = _shared.contains(record.id);
    return _row(
      divider: divider,
      minHeight: 84,
      title: record.dateLabel,
      subtitle:
          '${record.distanceKm.toStringAsFixed(2)} km · ${record.durationLabel} · ${record.energyKcal.round()} kcal',
      status: public ? '친구 피드에 보여요' : '나만 볼 수 있어요',
      statusOn: public,
      trailing: _switch(
        public,
        _busy.contains(record.id) ? null : (v) => _toggle(record, v),
        '${record.dateLabel} 기록 공개',
      ),
    );
  }

  Widget _switch(bool value, ValueChanged<bool>? onChanged, String label) =>
      Semantics(
        label: label,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: Colors.white,
          activeThumbColor: AppColors.background,
          inactiveTrackColor: AppColors.divider,
          inactiveThumbColor: AppColors.textSecondary,
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      ),
    ),
  );

  Widget _row({
    required String title,
    String? subtitle,
    String? status,
    bool statusOn = false,
    required Widget trailing,
    bool divider = false,
    double minHeight = 60,
  }) => Container(
    constraints: BoxConstraints(minHeight: minHeight),
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: divider ? AppColors.divider : Colors.transparent,
        ),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: status == null ? 16 : 15,
                  fontWeight: status == null
                      ? FontWeight.w500
                      : FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: status == null ? 12 : 13,
                    fontWeight: FontWeight.w500,
                    color: status == null
                        ? AppColors.textTertiary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
              if (status != null) ...[
                const SizedBox(height: 6),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: statusOn
                        ? AppColors.textSecondary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        trailing,
      ],
    ),
  );

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
    ),
  );
}
