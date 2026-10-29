import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_spacing.dart';
import '../../home/running/running_start_page.dart' show runningNumberStyle;
import '../add/friend_add_page.dart';
import '../data/friend_store.dart';
import '../together/together_new_page.dart';
import '../widgets/friend_widgets.dart';

enum _MenuAction { together, delete }

/// 18-1 내 친구: 친구 목록과 이번 주 거리. 줄 오른쪽 버튼으로 친구를 삭제합니다(18-2).
class FriendListPage extends StatefulWidget {
  const FriendListPage({super.key, this.store});

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final FriendStore? store;

  @override
  State<FriendListPage> createState() => _FriendListPageState();
}

class _FriendListPageState extends State<FriendListPage> {
  FriendStore get _store => widget.store ?? FriendStore.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_store.refresh());
  }

  void _openAdd() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => FriendAddPage(store: widget.store)),
  );

  Future<void> _manage(PublicProfile person) async {
    final action = await showModalBottomSheet<_MenuAction>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      builder: (context) => _MenuSheet(person: person),
    );
    if (!mounted) return;
    if (action == _MenuAction.together) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              TogetherNewPage(friends: _store, preselected: [person.uid]),
        ),
      );
      return;
    }
    if (action != _MenuAction.delete) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      builder: (context) => _DeleteSheet(person: person),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _store.remove(person.uid);
      if (mounted) showFriendMessage(context, '${person.name} 님을 친구에서 삭제했어요');
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: friendAppBar(
      context,
      '내 친구',
      actions: [
        IconButton(
          tooltip: '친구 추가',
          icon: const Icon(Icons.person_add_alt_outlined),
          onPressed: _openAdd,
        ),
        const SizedBox(width: 4),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final friends = _store.friends;
          return RefreshIndicator(
            onRefresh: _store.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space4,
                AppSpacing.screenHorizontal,
                AppSpacing.space6,
              ),
              children: [
                FriendSectionHeader(
                  title: '친구 ${friends.length}명',
                  meta: '이번 주 거리',
                ),
                const SizedBox(height: 6),
                if (friends.isEmpty)
                  _empty()
                else
                  for (final (i, person) in friends.indexed)
                    FriendRow(
                      person: person,
                      divider: i > 0,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _WeekDistance(
                            km: _store
                                .statsOf(person.uid)
                                ?.weekKmAt(_store.now),
                          ),
                          IconButton(
                            tooltip: '${person.name} 님 관리',
                            icon: const Icon(Icons.more_horiz),
                            onPressed: () => _manage(person),
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

  Widget _empty() {
    if (_store.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(
            _store.error ?? '아직 친구가 없어요',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FriendPillButton(label: '친구 추가', onPressed: _openAdd),
        ],
      ),
    );
  }
}

/// 친구의 이번 주 거리. 합계를 올린 적이 없으면 '–'.
class _WeekDistance extends StatelessWidget {
  const _WeekDistance({required this.km});

  final double? km;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(
        km == null ? '–' : km!.toStringAsFixed(1),
        style: runningNumberStyle(17, weight: FontWeight.w600),
      ),
      const SizedBox(width: 3),
      const Text(
        'km',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );
}

/// 친구를 눌렀을 때 뜨는 메뉴.
class _MenuSheet extends StatelessWidget {
  const _MenuSheet({required this.person});

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
                      '@${person.id}',
                      style: const TextStyle(
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
          const Divider(height: 1, color: AppColors.divider),
          _item(
            context,
            Icons.directions_run,
            '함께 달리기 약속 잡기',
            _MenuAction.together,
          ),
          const Divider(height: 1, color: AppColors.divider),
          _item(
            context,
            Icons.person_remove_outlined,
            '친구 삭제',
            _MenuAction.delete,
          ),
          const Divider(height: 1, color: AppColors.divider),
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

Widget _item(
  BuildContext context,
  IconData icon,
  String label,
  _MenuAction action,
) => InkWell(
  onTap: () => Navigator.pop(context, action),
  child: SizedBox(
    height: 56,
    child: Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  ),
);

/// 18-2 친구 삭제 확인.
class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet({required this.person});

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
            '${person.name} 님을\n친구에서 삭제할까요?',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '상대에게 알림은 가지 않아요. 삭제하면 서로의 피드와 랭킹, 목표 비교에서 보이지 않아요.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 26),
          FriendSheetButton(
            label: '삭제하기',
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
