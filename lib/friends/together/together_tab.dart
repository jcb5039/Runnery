import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../home/running/running_start_page.dart' show runningNumberStyle;
import '../../record/models/running_record.dart' show clockText;
import '../data/friend_store.dart';
import '../data/together_store.dart';
import '../widgets/friend_widgets.dart';
import 'together_done_page.dart';
import 'together_lobby_page.dart';
import 'together_new_page.dart';

/// 17-4 함께 달리기: 약속 잡기, 받은 요청, 진행 중인 약속(누르면 대기실), 지난 약속.
class TogetherTab extends StatefulWidget {
  const TogetherTab({super.key, required this.friends, this.store});

  final FriendStore friends;

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final TogetherStore? store;

  @override
  State<TogetherTab> createState() => _TogetherTabState();
}

class _TogetherTabState extends State<TogetherTab> {
  TogetherStore get _store => widget.store ?? TogetherStore.instance;

  /// 이 화면에서 답한 요청. 답한 뒤에도 결과 카드를 잠시 보여 줍니다.
  final Map<String, (Together, TogetherStatus)> _answered = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    unawaited(_store.refresh());
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    unawaited(_store.refresh());
  }

  void _openNew() =>
      _open(TogetherNewPage(friends: widget.friends, store: widget.store));

  /// 약속 없이 친구만 골라 바로 대기실로 갑니다.
  void _openQuick() => _open(
    TogetherNewPage(friends: widget.friends, store: widget.store, quick: true),
  );

  Future<void> _answer(Together t, TogetherStatus status) async {
    if (_busy.contains(t.id)) return;
    setState(() => _busy.add(t.id));
    try {
      await _store.answer(t, status);
      setState(() {
        status == TogetherStatus.pending
            ? _answered.remove(t.id)
            : _answered[t.id] = (t, status);
      });
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(t.id));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) {
      final me = _store.me;
      if (me == null) return const SizedBox.shrink();
      final now = _store.now;
      final requests = _store.requests;
      final active = _store.active;
      final past = _store.past;
      final answered = _answered.values.toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _newButton(),
          const SizedBox(height: 12),
          FriendSheetButton(label: '지금 바로 같이 뛰기', onPressed: _openQuick),
          if (requests.isNotEmpty || answered.isNotEmpty) ...[
            const SizedBox(height: 28),
            FriendSectionHeader(
              title: '받은 요청',
              meta: requests.isEmpty ? '확인 완료' : '${requests.length}개',
            ),
            for (final t in requests) _requestCard(t, now),
            for (final (t, status) in answered) _answeredCard(t, status),
          ],
          const SizedBox(height: 30),
          FriendSectionHeader(
            title: '진행 중인 약속',
            meta: active.isEmpty ? null : '${active.length}개',
          ),
          const SizedBox(height: 4),
          if (_store.error case final error? when active.isEmpty)
            _note(error)
          else if (active.isEmpty)
            _note(_store.loading ? '불러오는 중이에요' : '진행 중인 약속이 없어요')
          else
            for (final (i, t) in active.indexed)
              _TogetherRow(
                together: t,
                store: _store,
                divider: i > 0,
                chip: _activeChip(t, me.uid),
                detail: t.goalLabel,
                onTap: () =>
                    _open(TogetherLobbyPage(id: t.id, store: widget.store)),
              ),
          if (past.isNotEmpty) ...[
            const SizedBox(height: 30),
            FriendSectionHeader(title: '지난 약속', meta: '${past.length}개'),
            const SizedBox(height: 4),
            for (final (i, t) in past.indexed)
              _TogetherRow(
                together: t,
                store: _store,
                divider: i > 0,
                past: true,
                chip: _pastChip(t),
                detail: t.results.isEmpty
                    ? t.goalLabel
                    : '${t.goalLabel} · 함께 ${t.totalKm.toStringAsFixed(2)} km',
                onTap: () => _open(
                  TogetherDonePage(
                    id: t.id,
                    friends: widget.friends,
                    store: widget.store,
                  ),
                ),
              ),
          ],
        ],
      );
    },
  );

  FriendChip _activeChip(Together t, String me) {
    if (t.startedAt != null) return const FriendChip(label: '시작했어요');
    final others = t.others(me);
    if (others.every((m) => t.statusOf(m) == TogetherStatus.declined)) {
      return const FriendChip(label: '모두 거절했어요', muted: true);
    }
    return t.allAccepted(me)
        ? const FriendChip(label: '모두 수락', filled: true, icon: Icons.check)
        : const FriendChip(label: '수락 기다리는 중', muted: true);
  }

  FriendChip _pastChip(Together t) {
    final finished = t.results.values
        .where((r) => r.distanceKm >= t.goalKm)
        .length;
    final accepted = t.members
        .where((m) => t.statusOf(m) == TogetherStatus.accepted)
        .length;
    // 목표가 없으면 끝까지 달린 사람을 '달렸어요'로 셉니다.
    final done = t.isQuick ? '달렸어요' : '완주';
    if (t.results.isEmpty) return const FriendChip(label: '기록 없음', muted: true);
    if (finished == accepted && accepted > 0) {
      return FriendChip(label: accepted == 2 ? '둘 다 $done' : '모두 $done');
    }
    return FriendChip(label: '$finished명 $done');
  }

  Widget _newButton() => Material(
    color: AppColors.primary,
    borderRadius: AppRadius.sheetBorder,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _openNew,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 88),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '함께 달리기 약속 잡기',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.background,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '날짜 · 시간 · 목표 거리를 정해서 보내요',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color.fromRGBO(11, 11, 11, 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                ),
                child: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _requestCard(Together t, DateTime now) {
    final host = _store.person(t.host);
    final others = [
      for (final m in t.members)
        if (m != t.host && m != _store.me?.uid) _store.person(m)?.name ?? '친구',
    ];
    final busy = _busy.contains(t.id);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FriendAvatar(initial: host?.initial ?? '친'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${host?.name ?? '친구'} 님이 함께 달리자고 해요',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      agoLabel(t.createdAt ?? now, now),
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
          const SizedBox(height: 14),
          _infoLine(
            Icons.calendar_today_outlined,
            '${t.startsAt.month}월 ${t.startsAt.day}일 (${weekdayLetter(t.startsAt)}) '
            '${clockText(t.startsAt)}',
          ),
          const SizedBox(height: 10),
          _infoLine(Icons.flag_outlined, t.goalLabel),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoLine(Icons.people_outline, '함께: ${others.join(', ')}'),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FriendSheetButton(
                  label: '거절',
                  height: 44,
                  onPressed: busy
                      ? null
                      : () => _answer(t, TogetherStatus.declined),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FriendSheetButton(
                  label: '수락',
                  filled: true,
                  height: 44,
                  onPressed: busy
                      ? null
                      : () => _answer(t, TogetherStatus.accepted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _answeredCard(Together t, TogetherStatus status) {
    final host = _store.person(t.host)?.name ?? '친구';
    final accepted = status == TogetherStatus.accepted;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      constraints: const BoxConstraints(minHeight: 64),
      padding: EdgeInsets.fromLTRB(16, 12, accepted ? 16 : 4, 12),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          if (accepted) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textPrimary,
              ),
              child: const Icon(
                Icons.check,
                size: 16,
                color: AppColors.background,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accepted ? '$host 님과의 약속을 수락했어요' : '$host 님의 요청을 거절했어요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: accepted ? FontWeight.w700 : FontWeight.w500,
                    color: accepted
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                if (accepted) ...[
                  const SizedBox(height: 6),
                  const Text(
                    '진행 중인 약속에 추가됐어요',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!accepted)
            TextButton(
              onPressed: () => _answer(t, TogetherStatus.pending),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text(
                '되돌리기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    ],
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

/// 약속 한 줄: 날짜 상자, 시각, 상태 표시, 목표, 함께하는 친구.
class _TogetherRow extends StatelessWidget {
  const _TogetherRow({
    required this.together,
    required this.store,
    required this.chip,
    required this.detail,
    required this.onTap,
    this.divider = true,
    this.past = false,
  });

  final Together together;
  final TogetherStore store;
  final Widget chip;
  final String detail;
  final VoidCallback onTap;
  final bool divider, past;

  @override
  Widget build(BuildContext context) {
    final t = together;
    final others = t.others(store.me?.uid ?? '');
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: divider ? AppColors.divider : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                borderRadius: AppRadius.thumbnailBorder,
                border: Border.all(
                  color: past ? AppColors.divider : AppColors.borderDefault,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${t.startsAt.month}월', style: _small),
                  const SizedBox(height: 2),
                  Text(
                    '${t.startsAt.day}',
                    style: runningNumberStyle(
                      24,
                      weight: FontWeight.w600,
                      color: past
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(weekdayLetter(t.startsAt), style: _small),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          togetherTimeLabel(t.startsAt, store.now),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      chip,
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      for (final (i, m) in others.take(3).indexed)
                        Transform.translate(
                          offset: Offset(-6.0 * i, 0),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.background,
                            ),
                            child: FriendAvatar(
                              initial: store.person(m)?.initial ?? '친',
                              size: 24,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          store.names(t),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _small = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );
}
