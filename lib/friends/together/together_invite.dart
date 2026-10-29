import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../home/running/running_home_page.dart' show runningLocationActive;
import '../../record/models/running_record.dart' show clockText;
import '../data/friend_store.dart';
import '../data/together_store.dart';
import '../widgets/friend_widgets.dart';
import 'together_lobby_page.dart';

/// 앱을 켜 둔 동안 친구가 보낸 함께 달리기 약속이 오면 창을 띄웁니다(꺼진 폰을 깨우는 알림은 없음).
/// 날짜를 정한 약속은 수락하고 그 자리에 머물고, '지금 바로 같이 뛰기'는 참여하면 대기실로 갑니다.
/// 앱을 새로 열면 아직 답하지 않은 약속을 다시 알려 주고, 달리는 중에는 띄우지 않습니다.
class TogetherInviteListener extends StatefulWidget {
  const TogetherInviteListener({super.key, required this.child, this.store});

  final Widget child;

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final TogetherStore? store;

  @override
  State<TogetherInviteListener> createState() => _TogetherInviteListenerState();
}

class _TogetherInviteListenerState extends State<TogetherInviteListener> {
  TogetherStore get _store => widget.store ?? TogetherStore.instance;

  StreamSubscription<List<Together>>? _sub;
  List<Together> _invites = const [];

  /// 이미 창을 띄운 초대. '나중에'를 누른 초대는 앱을 켜 둔 동안 다시 띄우지 않고 함께 달리기 탭에서 답합니다.
  final _shown = <String>{};
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _sub = _store.invites().listen((invites) {
      _invites = invites;
      _showNext();
    }, onError: (Object _) {});
    runningLocationActive.addListener(_showNext);
  }

  @override
  void dispose() {
    _sub?.cancel();
    runningLocationActive.removeListener(_showNext);
    super.dispose();
  }

  Future<void> _showNext() async {
    if (_open || !mounted || runningLocationActive.value) return;
    // 달리는 동안 쌓인 초대는 그사이 답했거나 오래됐을 수 있어 다시 확인합니다.
    final t = _invites
        .where(
          (t) =>
              !_shown.contains(t.id) &&
              _store.isFreshInvite(_store.byId(t.id) ?? t),
        )
        .firstOrNull;
    if (t == null) return;
    _shown.add(t.id);
    _open = true;
    final join = await _ask(t);
    _open = false;
    if (!mounted) return;
    if (join == true) await (t.isQuick ? _join(t) : _accept(t));
    unawaited(_showNext());
  }

  Future<bool?> _ask(Together t) {
    final host = _store.person(t.host)?.name ?? '친구';
    final others = [
      for (final m in t.members)
        if (m != t.host && m != _store.me?.uid) _store.person(m)?.name ?? '친구',
    ];
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.isQuick ? '$host 님이 지금 같이 뛰자고 해요' : '$host 님이 함께 달리자고 해요',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                [
                  if (!t.isQuick)
                    '${t.startsAt.month}월 ${t.startsAt.day}일 '
                        '(${weekdayLetter(t.startsAt)}) ${clockText(t.startsAt)} · ${t.goalLabel}.',
                  if (others.isNotEmpty) '${others.join(', ')} 님도 함께해요.',
                  if (t.isQuick) '목표 없이 자유롭게 달려요. 참여하면 대기실로 가요.',
                ].join(' '),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 26),
              FriendSheetButton(
                label: t.isQuick ? '참여하기' : '수락하기',
                filled: true,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 10),
              FriendSheetButton(
                label: '나중에',
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 날짜를 정한 약속은 수락만 하고 지금 화면에 머뭅니다. 약속 시간에 함께 달리기 탭에서 대기실로 들어가요.
  Future<void> _accept(Together t) async {
    try {
      await _store.answer(t, TogetherStatus.accepted);
      if (mounted) {
        final host = _store.person(t.host)?.name ?? '친구';
        showFriendMessage(context, '$host 님과의 약속을 수락했어요');
      }
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    }
  }

  Future<void> _join(Together t) async {
    try {
      await _store.answer(t, TogetherStatus.accepted);
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TogetherLobbyPage(id: t.id, store: widget.store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
