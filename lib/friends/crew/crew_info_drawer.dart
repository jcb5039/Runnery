import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/inline_notice.dart';
import '../../home/running/running_start_page.dart' show runningNumberStyle;
import '../../record/list/detail/record_detail_page.dart' show recordDelete;
import '../../record/models/running_record.dart' show clockText;
import '../data/crew_store.dart';
import '../data/friend_store.dart';
import '../widgets/friend_widgets.dart';
import 'crew_new_page.dart' show CrewInvitePage;
import 'crew_tab.dart' show CrewFaces;

/// 17-11 크루 채팅방 서랍: 크루 이름·인원, 공지(크루장만 씀), 함께 달린 기록, 멤버(크루장은 내보내기),
/// 초대 코드(복사, 크루장은 바꾸기), 멤버 초대, 나가기, 알림 켜고 끄기(종 아이콘).
class CrewInfoDrawer extends StatefulWidget {
  const CrewInfoDrawer({
    super.key,
    required this.crew,
    required this.friends,
    required this.onLeft,
    this.store,
  });

  final Crew crew;
  final FriendStore friends;

  /// 크루를 나간 뒤 부릅니다(서랍과 채팅방을 닫습니다).
  final VoidCallback onLeft;
  final CrewStore? store;

  /// 처음에 보여 주는 멤버 수. 나머지는 '더 보기'로 펼칩니다.
  static const previewMembers = 3;

  @override
  State<CrewInfoDrawer> createState() => _CrewInfoDrawerState();
}

class _CrewInfoDrawerState extends State<CrewInfoDrawer> {
  CrewStore get _store => widget.store ?? CrewStore.instance;
  Crew get _crew => widget.crew;

  List<CrewMember>? _members;

  /// 팀 기록이 끝난 모집들. 불러오는 중이면 null.
  List<CrewRun>? _runs;
  bool _allMembers = false;

  /// 안 되면 누른 곳 바로 아래(맨 아래 버튼이면 위)에 빨간 글씨로 알립니다.
  /// 자리: 'code' 코드 칸, 'notice' 공지 칸, 'member:uid' 멤버 줄, 'bottom' 나가기·알림 버튼 줄.
  final _notices = Notices();

  /// 코드를 복사했으면 잠깐 복사 버튼이 체크 표시로 바뀝니다.
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _notices.dispose();
    _copiedTimer?.cancel();
    super.dispose();
  }

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMembers());
    unawaited(_loadRuns());
    // 코드가 없는 예전 크루는 크루장이 서랍을 열 때 코드를 만듭니다.
    final me = _store.me?.uid;
    if (_crew.code == null && me != null && _crew.isOwner(me)) {
      unawaited(_makeCode());
    }
  }

  Future<void> _makeCode() async {
    try {
      await _store.issueCode(_crew);
    } on FriendException {
      // 서랍을 다시 열면 또 만듭니다.
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _changeCode() async {
    final ok = await _confirm(
      '초대 코드를 바꿀까요?',
      '바꾸면 지금 코드로는 더 이상 들어올 수 없어요.',
      '바꾸기',
    );
    if (ok != true || !mounted) return;
    await _run('code', () => _store.issueCode(_crew));
  }

  Future<void> _loadRuns() async {
    try {
      final runs = await _store.endedRuns(_crew.id);
      if (mounted) setState(() => _runs = runs);
    } on FriendException {
      if (mounted) setState(() => _runs = const []);
    }
  }

  @override
  void didUpdateWidget(CrewInfoDrawer old) {
    super.didUpdateWidget(old);
    if (old.crew.members.length != widget.crew.members.length) {
      unawaited(_loadMembers());
    }
  }

  Future<void> _loadMembers() async {
    try {
      final list = await _store.members(_crew.id);
      if (mounted) setState(() => _members = list);
    } on FriendException {
      if (mounted) setState(() => _members = const []);
    }
  }

  /// 들어온 순서의 멤버 uid. 멤버 문서가 없는 사람은 크루 목록 순서대로 뒤에 붙입니다.
  List<String> get _ordered {
    final known = [for (final m in _members ?? const <CrewMember>[]) m.uid];
    return [
      _crew.owner,
      for (final uid in known)
        if (uid != _crew.owner && _crew.members.contains(uid)) uid,
      for (final uid in _crew.members)
        if (uid != _crew.owner && !known.contains(uid)) uid,
    ];
  }

  /// 잘 되면 화면이 바뀌는 것으로 알 수 있어 따로 알리지 않고, 안 되면 [at] 자리에 이유를 보여 줍니다.
  Future<void> _run(String at, Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    _notices.clear(at);
    try {
      await task();
    } on FriendException catch (e) {
      if (mounted) _notices.show(at, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNotice() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.sheet,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _NoticeSheet(initial: _crew.notice?.text ?? ''),
    );
    if (text == null) return;
    await _run('notice', () => _store.setNotice(_crew, text));
  }

  Future<void> _kick(String uid) async {
    final name = _store.nameOf(uid);
    final ok = await _confirm(
      '$name 님을 내보낼까요?',
      '내보내면 채팅방에 안내가 남아요. 다시 초대하면 들어올 수 있어요.',
      '내보내기',
    );
    if (ok != true || !mounted) return;
    final sure = await _confirmAgain(
      '정말 내보낼까요?',
      '$name 님은 바로 채팅방에서 나가게 돼요.',
      '내보내기',
    );
    if (!sure) return;
    await _run('member:$uid', () => _store.kick(_crew, uid));
  }

  Future<void> _leave() async {
    final me = _store.me?.uid;
    final owner = me != null && _crew.isOwner(me);
    final next = _ordered.where((u) => u != me).firstOrNull;
    final ok = await _confirm(
      '${_crew.name}에서 나갈까요?',
      !owner
          ? '나가면 채팅방에 안내가 남아요. 다시 들어오려면 초대를 받아야 해요.'
          : next == null
          ? '혼자 남은 크루라 나가면 크루와 대화가 모두 지워져요.'
          : '나가면 가장 오래된 멤버인 ${_store.nameOf(next)} 님이 크루장이 돼요.',
      '나가기',
    );
    if (ok != true || !mounted) return;
    final sure = await _confirmAgain(
      '정말 나갈까요?',
      owner && next == null ? '크루와 대화가 모두 지워져요.' : '나가면 다시 초대를 받아야 들어올 수 있어요.',
      '나가기',
    );
    if (!sure || _busy) return;
    setState(() => _busy = true);
    _notices.clear('bottom');
    try {
      await _store.leave(_crew);
      widget.onLeft();
    } on FriendException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _notices.show('bottom', e.message);
      }
    }
  }

  /// 되돌리기 어려운 일이라 한 번 더 묻는 창(기록 삭제 확인 창과 같은 모양).
  Future<bool> _confirmAgain(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.pick(
            const Color(0xFF171818),
            AppColors.background,
          ),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: recordDelete),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool?> _confirm(String title, String body, String action) =>
      showModalBottomSheet<bool>(
        context: context,
        backgroundColor: AppColors.sheet,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 26),
                FriendSheetButton(
                  label: action,
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
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) {
      final me = _store.me?.uid ?? '';
      final owner = _crew.isOwner(me);
      final ordered = _ordered;
      final shown = _allMembers
          ? ordered
          : ordered.take(CrewInfoDrawer.previewMembers).toList();
      final muted = _store.muted(_crew.id);
      return Drawer(
        backgroundColor: AppColors.background,
        width: 320,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  children: [
                    Row(
                      children: [
                        CrewFaces(crew: _crew, store: _store, size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _crew.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '멤버 ${_crew.members.length}명',
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
                    const SizedBox(height: 24),
                    _codeCard(owner),
                    NoticeSlot(notices: _notices, id: 'code'),
                    const SizedBox(height: 12),
                    _noticeCard(owner),
                    NoticeSlot(notices: _notices, id: 'notice'),
                    const SizedBox(height: 28),
                    const FriendSectionHeader(title: '함께 달린 기록'),
                    _CrewRecords(runs: _runs, me: me, now: _store.now),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FriendSectionHeader(
                            title: '멤버',
                            meta: '${_crew.members.length}명',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CrewInvitePage(
                            crew: _crew,
                            friends: widget.friends,
                            store: widget.store,
                          ),
                        ),
                      ),
                      child: SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.borderControl,
                                ),
                              ),
                              child: const Icon(Icons.add, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '멤버 초대',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final uid in shown) ...[
                      _memberRow(uid, me, owner),
                      NoticeSlot(notices: _notices, id: 'member:$uid'),
                    ],
                    if (!_allMembers &&
                        ordered.length > CrewInfoDrawer.previewMembers)
                      TextButton(
                        onPressed: () => setState(() => _allMembers = true),
                        child: Text(
                          '멤버 ${ordered.length - CrewInfoDrawer.previewMembers}명 더 보기',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              // 나가기·알림 버튼은 서랍 맨 아래라, 안 되면 그 바로 위에 보여 줍니다.
              NoticeSlot(
                notices: _notices,
                id: 'bottom',
                textAlign: TextAlign.center,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              ),
              Divider(height: 1, color: AppColors.divider),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _busy ? null : _leave,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('나가기'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ),
                  // 글자 없이 지금 상태만 보여 줍니다: 종이면 켜짐, 작대기 그어진 종이면 꺼짐.
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: muted ? '크루 알림 꺼짐, 눌러서 켜기' : '크루 알림 켜짐, 눌러서 끄기',
                      excludeSemantics: true,
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                'bottom',
                                () => _store.setMuted(_crew.id, muted: !muted),
                              ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: Icon(
                          muted
                              ? Icons.notifications_off_outlined
                              : Icons.notifications_none,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  /// 초대 코드: 친구가 아니어도 이 코드로 들어올 수 있어요. 멤버는 복사하고, 크루장은 바꿀 수 있습니다.
  Widget _codeCard(bool owner) {
    final code = _crew.code;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.thumbnailBorder,
      ),
      child: Row(
        children: [
          Icon(
            Icons.vpn_key_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '초대 코드',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                if (code != null)
                  Text(
                    code,
                    semanticsLabel: '초대 코드 ${code.split('').join(' ')}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  )
                else
                  Text(
                    owner ? '코드를 만드는 중이에요' : '아직 코드가 없어요',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '친구가 아니어도 이 코드로 들어올 수 있어요',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          if (code != null)
            IconButton(
              tooltip: _copied ? '복사했어요' : '코드 복사',
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 20,
              ),
              color: AppColors.textSecondary,
              onPressed: () => _copyCode(code),
            ),
          if (owner)
            IconButton(
              tooltip: '코드 바꾸기',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: AppColors.textSecondary,
              onPressed: _busy ? null : _changeCode,
            ),
        ],
      ),
    );
  }

  Widget _noticeCard(bool owner) {
    final notice = _crew.notice;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.thumbnailBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.campaign_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice == null
                      ? '공지'
                      : '공지 · ${_store.nameOf(notice.by)} · ${notice.at.month}월 ${notice.at.day}일',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notice?.text ??
                      (owner ? '크루원에게 알릴 내용을 적어 보세요' : '아직 공지가 없어요'),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: notice == null
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (owner)
            IconButton(
              tooltip: notice == null ? '공지 쓰기' : '공지 고치기',
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: _busy ? null : _editNotice,
            ),
        ],
      ),
    );
  }

  Widget _memberRow(String uid, String me, bool owner) {
    final person = _store.person(uid);
    final isOwner = _crew.isOwner(uid);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          FriendAvatar(initial: person?.initial ?? '·'),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              uid == me ? '나' : (person?.name ?? '멤버'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          if (isOwner) const FriendChip(label: '크루장'),
          if (owner && !isOwner)
            IconButton(
              tooltip: '${person?.name ?? '멤버'} 님 내보내기',
              icon: Icon(Icons.more_horiz, color: AppColors.textSecondary),
              onPressed: _busy ? null : () => _kick(uid),
            ),
        ],
      ),
    );
  }
}

/// 공지 쓰기: 200자까지. 비우고 저장하면 공지를 지웁니다.
class _NoticeSheet extends StatefulWidget {
  const _NoticeSheet({required this.initial});

  final String initial;

  @override
  State<_NoticeSheet> createState() => _NoticeSheetState();
}

class _NoticeSheetState extends State<_NoticeSheet> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '공지',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              autofocus: true,
              maxLength: CrewNotice.maxText,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '예: 매주 화·목 오후 8시, 여의도 물빛광장에서 모여요',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.borderDefault),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FriendSheetButton(
              label: '저장',
              filled: true,
              onPressed: () => Navigator.pop(context, _text.text),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 서랍의 '함께 달린 기록': 이번 달 크루 함께 달리기 횟수, 내가 함께 뛴 거리, 최근 기록.
/// 팀 기록(팀장이 끝낸 때)을 보여 주고, 이 기록은 크루방 안에서만 봅니다.
class _CrewRecords extends StatelessWidget {
  const _CrewRecords({required this.runs, required this.me, required this.now});

  final List<CrewRun>? runs;
  final String me;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final list = runs;
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '아직 크루로 함께 달린 기록이 없어요',
          style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
        ),
      );
    }
    DateTime at(CrewRun r) => r.startedAt ?? r.endedAt ?? now;
    final month = [
      for (final r in list)
        if (at(r).year == now.year && at(r).month == now.month) r,
    ];
    final myKm = month.fold<double>(
      0,
      (sum, r) => sum + (r.team[me]?.distanceKm ?? 0),
    );
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _stat('${now.month}월 크루 함께 달리기', '${month.length}', '번'),
            ),
            Expanded(child: _stat('내가 함께 뛴 거리', myKm.toStringAsFixed(2), 'km')),
          ],
        ),
        const SizedBox(height: 8),
        for (final r in list.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${at(r).month}월 ${at(r).day}일 (${weekdays[at(r).weekday - 1]})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.title} · ${r.members.length}명 · ${clockText(at(r))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  r.team[me] == null
                      ? '–'
                      : '${r.team[me]!.distanceKm.toStringAsFixed(2)} km',
                  style: runningNumberStyle(16, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stat(String label, String value, String unit) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
      ),
      const SizedBox(height: 4),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value,
              style: runningNumberStyle(24, weight: FontWeight.w700),
            ),
            TextSpan(
              text: ' $unit',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ],
  );
}
