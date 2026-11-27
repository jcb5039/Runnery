import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_spacing.dart';
import '../data/friend_store.dart';
import '../data/together_store.dart';
import '../together/together_tab.dart'
    show TogetherAnsweredCard, TogetherRequestCard;
import '../widgets/friend_widgets.dart';

/// 친구 탭 오른쪽 위 알림 종: 받은 친구 요청과 함께 달리기 초대를 한곳에서 보고 답합니다.
class FriendNotificationsPage extends StatefulWidget {
  const FriendNotificationsPage({super.key, this.friends, this.together});

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final FriendStore? friends;
  final TogetherStore? together;

  @override
  State<FriendNotificationsPage> createState() =>
      _FriendNotificationsPageState();
}

class _FriendNotificationsPageState extends State<FriendNotificationsPage> {
  FriendStore get _friends => widget.friends ?? FriendStore.instance;
  TogetherStore get _together => widget.together ?? TogetherStore.instance;

  /// 이 화면에서 답한 친구 요청(uid → 수락했는지). 답한 뒤에도 결과를 보여 줍니다.
  final Map<String, (PublicProfile, bool)> _answeredFriends = {};

  /// 이 화면에서 답한 함께 달리기 초대.
  final Map<String, (Together, TogetherStatus)> _answeredInvites = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    unawaited(_friends.refresh());
    unawaited(_together.refresh());
  }

  /// 서버 작업을 하는 동안 그 줄의 버튼을 막고, 실패하면 이유를 알려 줍니다.
  Future<void> _act(String key, Future<void> Function() task) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await task();
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _answerFriend(PublicProfile person, {required bool accept}) =>
      _act(person.uid, () async {
        accept ? await _friends.accept(person) : await _friends.decline(person);
        _answeredFriends[person.uid] = (person, accept);
      });

  Future<void> _answerInvite(Together t, TogetherStatus status) =>
      _act(t.id, () async {
        await _together.answer(t, status);
        status == TogetherStatus.pending
            ? _answeredInvites.remove(t.id)
            : _answeredInvites[t.id] = (t, status);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: friendAppBar(context, '알림'),
    body: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([_friends, _together]),
        builder: (context, _) => RefreshIndicator(
          onRefresh: () =>
              Future.wait([_friends.refresh(), _together.refresh()]),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.space4,
              AppSpacing.screenHorizontal,
              AppSpacing.space6,
            ),
            children: [..._friendSection(), ..._inviteSection()],
          ),
        ),
      ),
    ),
  );

  List<Widget> _friendSection() {
    final waiting = [
      for (final p in _friends.incoming)
        if (!_answeredFriends.containsKey(p.uid)) p,
    ];
    final answered = _answeredFriends.values.toList();
    return [
      FriendSectionHeader(
        title: '친구 요청',
        meta: waiting.isNotEmpty
            ? '${waiting.length}개'
            : answered.isNotEmpty
            ? '모두 확인했어요'
            : null,
      ),
      const SizedBox(height: 6),
      if (waiting.isEmpty && answered.isEmpty)
        _note(
          _friends.loading ? '불러오는 중이에요' : _friends.error ?? '받은 친구 요청이 없어요',
        )
      else ...[
        for (final (i, person) in waiting.indexed)
          FriendRow(
            person: person,
            divider: i > 0,
            trailing: _friendButtons(person),
          ),
        for (final (i, (person, accepted)) in answered.indexed)
          FriendRow(
            person: person,
            divider: waiting.isNotEmpty || i > 0,
            trailing: _friendResult(accepted),
          ),
      ],
    ];
  }

  Widget _friendButtons(PublicProfile person) {
    final busy = _busy.contains(person.uid);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FriendPillButton(
          label: '거절',
          filled: false,
          semanticLabel: '${person.name} 님 요청 거절',
          onPressed: busy ? null : () => _answerFriend(person, accept: false),
        ),
        const SizedBox(width: 6),
        FriendPillButton(
          label: '수락',
          semanticLabel: '${person.name} 님 요청 수락',
          onPressed: busy ? null : () => _answerFriend(person, accept: true),
        ),
      ],
    );
  }

  Widget _friendResult(bool accepted) => accepted
      ? Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: AppRadius.pillBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 12, color: AppColors.background),
              const SizedBox(width: 4),
              Text(
                '친구가 됐어요',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.background,
                ),
              ),
            ],
          ),
        )
      : Text(
          '거절했어요',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        );

  List<Widget> _inviteSection() {
    final waiting = [
      for (final t in _together.requests)
        if (!_answeredInvites.containsKey(t.id)) t,
    ];
    final answered = _answeredInvites.values.toList();
    return [
      const SizedBox(height: 30),
      FriendSectionHeader(
        title: '함께 달리기 초대',
        meta: waiting.isNotEmpty
            ? '${waiting.length}개'
            : answered.isNotEmpty
            ? '모두 확인했어요'
            : null,
      ),
      if (waiting.isEmpty && answered.isEmpty)
        _note(
          _together.loading
              ? '불러오는 중이에요'
              : _together.error ?? '받은 함께 달리기 초대가 없어요',
        )
      else ...[
        for (final t in waiting)
          TogetherRequestCard(
            together: t,
            store: _together,
            busy: _busy.contains(t.id),
            onAnswer: (status) => _answerInvite(t, status),
          ),
        for (final (t, status) in answered)
          TogetherAnsweredCard(
            together: t,
            store: _together,
            status: status,
            onUndo: () => _answerInvite(t, TogetherStatus.pending),
          ),
      ],
    ];
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
    ),
  );
}

/// 친구 탭 위쪽의 알림 종. 답하지 않은 친구 요청이나 함께 달리기 초대가 있으면 빨간 점을 붙입니다.
class FriendNotificationBell extends StatelessWidget {
  const FriendNotificationBell({
    super.key,
    required this.count,
    required this.onPressed,
  });

  /// 답하지 않은 친구 요청과 함께 달리기 초대 수.
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: count > 0 ? '알림 · 새 알림 $count개' : '알림',
    onPressed: onPressed,
    icon: Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none),
        if (count > 0)
          Positioned(
            top: 1,
            right: 1,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error,
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
          ),
      ],
    ),
  );
}
