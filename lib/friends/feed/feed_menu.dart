import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/inline_notice.dart';
import '../data/friend_backend.dart' show FriendException;
import '../data/friend_models.dart';
import '../widgets/friend_widgets.dart';

/// 17-16 피드 카드의 '더보기'에서 고르는 일.
enum FeedMenuAction { report, block }

/// 17-16 더보기: 신고하기 · 차단하기.
class FeedMenuSheet extends StatelessWidget {
  const FeedMenuSheet({super.key, required this.person});

  final PublicProfile person;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FriendAvatar(initial: person.initial, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '친구',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: AppColors.divider),
          _MenuItem(
            icon: Icons.flag_outlined,
            title: '신고하기',
            subtitle: '부적절한 기록이나 행동을 알려 주세요',
            onTap: () => Navigator.pop(context, FeedMenuAction.report),
          ),
          Divider(height: 1, color: AppColors.divider),
          _MenuItem(
            icon: Icons.block,
            title: '차단하기',
            subtitle: '서로의 러닝 기록이 보이지 않게 해요',
            onTap: () => Navigator.pop(context, FeedMenuAction.block),
          ),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 22),
          FriendSheetButton(
            label: '닫기',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 17-18 차단 확인. 차단하기를 누르면 true를 돌려줍니다.
class BlockConfirmSheet extends StatelessWidget {
  const BlockConfirmSheet({super.key, required this.person});

  final PublicProfile person;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${person.name} 님을 차단할까요?',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          for (final line in const [
            '서로의 러닝 기록과 피드가 보이지 않아요',
            '친구에서 삭제되고, 친구 요청과 함께 달리기 약속을 주고받지 못해요',
            '차단해도 상대에게 알림은 가지 않아요',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('·  ', style: TextStyle(color: AppColors.textSecondary)),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '차단은 내 친구 화면에서 언제든 풀 수 있어요.',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 26),
          FriendSheetButton(
            label: '${person.name} 님 차단하기',
            filled: true,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 10),
          FriendSheetButton(
            label: '취소',
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ),
  );
}

/// 17-17 신고하기: 사유 하나와 내용(300자까지). 신고하기를 누르면 [onSubmit]을 부르고,
/// 성공하면 사유와 내용을 돌려줍니다.
class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.person, required this.onSubmit});

  final PublicProfile person;
  final Future<void> Function(ReportReason reason, String detail) onSubmit;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  ReportReason? _reason;
  final _detail = TextEditingController();
  bool _sending = false;

  /// 보내지 못한 이유. 신고하기 버튼 바로 아래에 빨간 글씨로 보여 줍니다.
  String? _error;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(reason, _detail.text);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.sheet,
        showDragHandle: true,
        builder: (context) => const _ReportedSheet(),
      );
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e is FriendException ? e.message : '신고하지 못했어요. 다시 시도해주세요';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: friendAppBar(context, '신고하기'),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Row(
            children: [
              FriendAvatar(initial: widget.person.initial, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.person.name} 님을 신고해요',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '신고한 사실은 상대에게 알려지지 않아요',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const FriendSectionHeader(title: '신고 사유', meta: '하나를 골라 주세요'),
          const SizedBox(height: 4),
          for (final reason in ReportReason.values)
            Semantics(
              inMutuallyExclusiveGroup: true,
              checked: _reason == reason,
              button: true,
              label: reason.label,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => setState(() => _reason = reason),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          reason.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: _reason == reason
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        _reason == reason
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 22,
                        color: _reason == reason
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 28),
          const FriendSectionHeader(title: '신고 내용', meta: '300자까지'),
          const SizedBox(height: 12),
          TextField(
            controller: _detail,
            maxLength: FriendReport.maxDetail,
            minLines: 4,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: '어떤 일이 있었는지 알려 주세요(선택)',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.borderDefault),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FriendSheetButton(
            label: _sending ? '보내는 중…' : '신고하기',
            filled: true,
            onPressed: _reason == null || _sending ? null : _submit,
          ),
          InlineNotice(_error, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

/// 17-17-1 신고 완료.
class _ReportedSheet extends StatelessWidget {
  const _ReportedSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '신고가 접수됐어요',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            '보내 주신 내용을 확인할게요.\n신고한 사실은 상대에게 알려지지 않아요.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 26),
          FriendSheetButton(
            label: '확인',
            filled: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
