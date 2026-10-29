import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../record/models/running_record.dart';
import '../data/friend_store.dart';
import '../data/record_share.dart';
import '../feed/feed_card.dart';
import '../widgets/friend_widgets.dart';
import 'record_visibility_page.dart';

/// 18-3 친구에게 기록 공유. 보여 줄 항목을 고르고 친구 피드에 올립니다.
Future<void> showShareRecordSheet(
  BuildContext context,
  RunningRecord record, {
  RecordShare? share,
}) async {
  final sharer = share ?? RecordShare.instance;
  if (sharer.me == null) {
    showFriendMessage(context, '로그인이 필요해요');
    return;
  }
  final message = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.card,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ShareSheet(record: record, share: sharer),
  );
  if (message != null && context.mounted) showFriendMessage(context, message);
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.record, required this.share});

  final RunningRecord record;
  final RecordShare share;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  ShareFields? _fields;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await widget.share.settings();
      if (mounted) setState(() => _fields = settings.fields);
    } on FriendException catch (e) {
      // 설정을 못 읽어도 모든 항목을 보이게 해서 공유할 수 있게 합니다.
      if (mounted) {
        setState(() {
          _fields = const ShareFields();
          _error = e.message;
        });
      }
    }
  }

  Future<void> _send() async {
    final fields = _fields;
    if (fields == null || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.share.share(widget.record, fields: fields);
      if (mounted) Navigator.pop(context, '친구 피드에 올렸어요');
    } on FriendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _unshare() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.share.unshare(widget.record.id);
      if (mounted) Navigator.pop(context, '공유를 취소했어요');
    } on FriendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openVisibility() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RecordVisibilityPage(share: widget.share),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fields = _fields;
    final shared = widget.share.isShared(widget.record.id);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '친구에게 기록 공유',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              shared
                  ? '이미 공유한 기록이에요. 보여줄 항목을 바꿔 다시 올릴 수 있어요.'
                  : '공유한 기록은 친구 피드에 올라가요.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            if (fields == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              _preview(fields),
              const SizedBox(height: 20),
              const Text(
                '보여줄 항목',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              const _FieldRow(label: '거리', value: true, note: '항상 보여요'),
              _FieldRow(
                label: '운동 시간',
                value: fields.time,
                onChanged: (v) =>
                    setState(() => _fields = fields.copyWith(time: v)),
              ),
              _FieldRow(
                label: '평균 페이스',
                value: fields.pace,
                onChanged: (v) =>
                    setState(() => _fields = fields.copyWith(pace: v)),
              ),
              _FieldRow(
                label: '소모 칼로리',
                value: fields.kcal,
                onChanged: (v) =>
                    setState(() => _fields = fields.copyWith(kcal: v)),
              ),
              _FieldRow(
                label: '햇반 환산',
                value: fields.food,
                onChanged: (v) =>
                    setState(() => _fields = fields.copyWith(food: v)),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _openVisibility,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('자동 공유 · 공개할 기록 고르기'),
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 16),
            FriendSheetButton(
              label: _sending
                  ? '보내는 중이에요'
                  : shared
                  ? '다시 올리기'
                  : '친구에게 공유',
              filled: true,
              onPressed: _send,
            ),
            if (shared) ...[
              const SizedBox(height: 10),
              FriendSheetButton(label: '공유 취소', onPressed: _unshare),
            ],
          ],
        ),
      ),
    );
  }

  Widget _preview(ShareFields fields) {
    final me = widget.share.me;
    final record = widget.record;
    final route = [
      if (record.startPlace != unknownPlace) record.startPlace,
      if (record.endPlace != unknownPlace) record.endPlace,
    ].join(' → ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FriendAvatar(initial: me?.initial ?? '나', size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me?.name ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      route.isEmpty ? '방금 전' : '방금 전 · $route',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 12),
          PostStats(
            post: postFor(me?.uid ?? '', record, fields),
            distanceSize: 36,
          ),
        ],
      ),
    );
  }
}

/// 보여줄 항목 한 줄. [onChanged]가 없으면 바꿀 수 없는 항목입니다.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    this.onChanged,
    this.note,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? note;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: value,
    enabled: onChanged != null,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: !value
                    ? Colors.transparent
                    : onChanged == null
                    ? AppColors.borderControl
                    : AppColors.textPrimary,
                borderRadius: const BorderRadius.all(Radius.circular(5)),
                border: value
                    ? null
                    : Border.all(color: AppColors.borderControl, width: 1.5),
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.background,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: value ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            if (note case final note?)
              Text(
                note,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
