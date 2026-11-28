import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../design_system/app_colors.dart';
import '../../design_system/inline_notice.dart';
import '../../home/running/running_start_page.dart' show runningNumberStyle;
import '../../record/list/detail/record_detail_page.dart' show recordDelete;
import '../../record/models/running_record.dart' show clockText;
import '../data/crew_store.dart';
import '../data/friend_store.dart';
import '../widgets/friend_widgets.dart';
import 'crew_new_page.dart' show CrewInvitePage;
import 'crew_tab.dart' show CrewTile;

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
      final notice = _crew.notice;
      // 17-11 서랍: 폭 310, 위쪽 크루 얼굴·이름, 공지·초대 코드·함께 달린 기록·멤버, 아래 나가기·알림.
      return Drawer(
        backgroundColor: AppColors.background,
        width: 310,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    Row(
                      children: [
                        CrewTile(crew: _crew, store: _store),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _crew.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  letterSpacing: -0.36,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '멤버 ${_crew.members.length}명',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    FriendSectionHeader(
                      title: '공지',
                      meta: notice == null
                          ? null
                          : '${_store.nameOf(notice.by)} · ${notice.at.month}월 ${notice.at.day}일',
                    ),
                    const SizedBox(height: 10),
                    _noticeCard(owner),
                    NoticeSlot(notices: _notices, id: 'notice'),
                    const SizedBox(height: 22),
                    const FriendSectionHeader(title: '초대 코드'),
                    const SizedBox(height: 10),
                    _codeCard(owner),
                    NoticeSlot(notices: _notices, id: 'code'),
                    const SizedBox(height: 22),
                    FriendSectionHeader(
                      title: '함께 달린 기록',
                      meta: '${_store.now.month}월',
                    ),
                    _CrewRecords(runs: _runs, me: me, now: _store.now),
                    const SizedBox(height: 22),
                    FriendSectionHeader(
                      title: '멤버',
                      meta: '${_crew.members.length}명',
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
                        height: 46,
                        child: Row(
                          children: [
                            CustomPaint(
                              painter: _DashedCircle(AppColors.borderControl),
                              child: const SizedBox.square(
                                dimension: 36,
                                child: Center(
                                  child: FriendIcon(
                                    FriendIconKind.plus,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '멤버 초대',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1,
                                letterSpacing: -0.225,
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
                      InkWell(
                        onTap: () => setState(() => _allMembers = true),
                        child: SizedBox(
                          height: 44,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '멤버 ${ordered.length - CrewInfoDrawer.previewMembers}명 더 보기',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              FriendIcon(
                                FriendIconKind.chevronRight,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
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
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: _busy ? null : _leave,
                            icon: const FriendIcon(
                              FriendIconKind.leave,
                              size: 20,
                            ),
                            label: const Text('나가기'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.14,
                              ),
                            ),
                          ),
                          // 글자 없이 지금 상태만 보여 줍니다: 종이면 켜짐, 작대기 그어진 종이면 꺼짐.
                          Semantics(
                            button: true,
                            label: muted
                                ? '크루 알림 꺼짐, 눌러서 켜기'
                                : '크루 알림 켜짐, 눌러서 끄기',
                            excludeSemantics: true,
                            child: IconButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      'bottom',
                                      () => _store.setMuted(
                                        _crew.id,
                                        muted: !muted,
                                      ),
                                    ),
                              constraints: const BoxConstraints.tightFor(
                                width: 44,
                                height: 44,
                              ),
                              icon: FriendIcon(
                                muted
                                    ? FriendIconKind.bellOff
                                    : FriendIconKind.bell,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  /// 시안의 회색 카드(안쪽 여백 12×14, 모서리 14).
  static BoxDecoration get _cardBox => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(14),
  );

  /// 초대 코드: 친구가 아니어도 이 코드로 들어올 수 있어요. 멤버는 복사하고, 크루장은 바꿀 수 있습니다.
  /// 시안에 없는 칸이라 공지 카드와 같은 모양으로 만듭니다.
  Widget _codeCard(bool owner) {
    final code = _crew.code;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: _cardBox,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (code != null)
                  Text(
                    code,
                    semanticsLabel: '초대 코드 ${code.split('').join(' ')}',
                    style: runningNumberStyle(
                      24,
                      weight: FontWeight.w700,
                    ).copyWith(letterSpacing: 2),
                  )
                else
                  Text(
                    owner ? '코드를 만드는 중이에요' : '아직 코드가 없어요',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '친구가 아니어도 이 코드로 들어올 수 있어요',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (code != null)
            IconButton(
              tooltip: _copied ? '복사했어요' : '코드 복사',
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 18,
              ),
              color: AppColors.textSecondary,
              onPressed: () => _copyCode(code),
            ),
          if (owner)
            IconButton(
              tooltip: '코드 바꾸기',
              icon: const Icon(Icons.refresh_rounded, size: 18),
              color: AppColors.textSecondary,
              onPressed: _busy ? null : _changeCode,
            ),
        ],
      ),
    );
  }

  /// 공지 카드: 확성기 아이콘과 공지 글. 크루장은 눌러서 쓰거나 고칩니다.
  Widget _noticeCard(bool owner) {
    final notice = _crew.notice;
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _cardBox,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FriendIcon(
            FriendIconKind.notice,
            size: 18,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notice?.text ??
                  (owner ? '눌러서 크루원에게 알릴 내용을 적어 보세요' : '아직 공지가 없어요'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.45,
                letterSpacing: -0.14,
                color: notice == null
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
    if (!owner) return card;
    return Semantics(
      button: true,
      label: notice == null ? '공지 쓰기' : '공지 고치기',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _busy ? null : _editNotice,
        child: card,
      ),
    );
  }

  /// 멤버 한 줄(높이 46): 얼굴 36, 이름, '나'·'크루장' 칩. 크루장은 다른 멤버를 내보낼 수 있습니다.
  Widget _memberRow(String uid, String me, bool owner) {
    final person = _store.person(uid);
    final isOwner = _crew.isOwner(uid);
    Widget chip(String label, {required bool filled}) => Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.card : null,
        border: filled ? null : Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: -0.055,
          color: filled ? AppColors.textSecondary : AppColors.textPrimary,
        ),
      ),
    );
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          FriendAvatar(initial: person?.initial ?? '·', size: 36),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              person?.name ?? '멤버',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: -0.225,
              ),
            ),
          ),
          if (uid == me) ...[
            const SizedBox(width: 12),
            chip('나', filled: true),
          ],
          if (isOwner) ...[
            const SizedBox(width: 12),
            chip('크루장', filled: false),
          ],
          const Spacer(),
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

/// 점선 동그라미(멤버 초대 칸).
class _DashedCircle extends CustomPainter {
  _DashedCircle(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = size.shortestSide / 2 - 0.5;
    final center = size.center(Offset.zero);
    const dashes = 18;
    for (var i = 0; i < dashes; i++) {
      final start = i * 2 * math.pi / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        math.pi / dashes,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
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
    final recent = list.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _stat('크루 함께 달리기', '${month.length}', '번')),
            const SizedBox(width: 8),
            Expanded(child: _stat('내가 함께 뛴 거리', myKm.toStringAsFixed(2), 'km')),
          ],
        ),
        const SizedBox(height: 4),
        for (final (i, r) in recent.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: i == 0 ? Colors.transparent : AppColors.divider,
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
                        '${at(r).month}월 ${at(r).day}일 (${weekdays[at(r).weekday - 1]})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          letterSpacing: -0.13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${r.members.length}명 · ${clockText(at(r))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _number(
                  r.team[me] == null
                      ? '–'
                      : r.team[me]!.distanceKm.toStringAsFixed(2),
                  'km',
                  size: 18,
                  unitSize: 11,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 숫자(Archivo 좁은 글꼴)와 단위.
  Widget _number(
    String value,
    String unit, {
    required double size,
    required double unitSize,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(
        value,
        style: runningNumberStyle(
          size,
          weight: FontWeight.w600,
        ).copyWith(height: 0.8, letterSpacing: -0.01 * size),
      ),
      const SizedBox(width: 3),
      Text(
        unit,
        style: TextStyle(
          fontSize: unitSize,
          fontWeight: FontWeight.w600,
          height: 1,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );

  /// 회색 카드 안의 통계(제목 12, 숫자 26).
  Widget _stat(String label, String value, String unit) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1,
            letterSpacing: -0.06,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        // 숫자가 길어 칸을 넘치면 그만큼만 줄입니다.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _number(value, unit, size: 26, unitSize: 13),
        ),
      ],
    ),
  );
}
