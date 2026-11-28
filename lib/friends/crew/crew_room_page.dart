import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../record/models/running_record.dart' show clockText;
import '../data/crew_store.dart';
import '../data/friend_store.dart';
import '../widgets/friend_widgets.dart';
import 'crew_info_drawer.dart';
import 'crew_run_pages.dart';

/// 17-8 크루 채팅방: 최근 메시지(위로 올리면 더 보기), 글자 보내기. 오른쪽 위 메뉴로 서랍(17-11)을 엽니다.
/// 차단한 사람의 메시지는 가려서 보여 줍니다. '함께 시작'으로 함께 달리기 모집을 열고, 채팅방의 모집 카드에서 참여합니다.
class CrewRoomPage extends StatefulWidget {
  const CrewRoomPage({
    super.key,
    required this.id,
    required this.friends,
    this.store,
  });

  final String id;
  final FriendStore friends;

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final CrewStore? store;

  /// 한 번에 불러오는 메시지 수.
  static const pageSize = 50;

  @override
  State<CrewRoomPage> createState() => _CrewRoomPageState();
}

class _CrewRoomPageState extends State<CrewRoomPage> {
  CrewStore get _store => widget.store ?? CrewStore.instance;

  final _text = TextEditingController();
  final _scaffold = GlobalKey<ScaffoldState>();
  StreamSubscription<Crew?>? _crewSub;
  StreamSubscription<List<CrewMessage>>? _messageSub;
  Crew? _crew;
  bool _gone = false;
  List<CrewMessage> _messages = const [];
  int _limit = CrewRoomPage.pageSize;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _crew = _store.byId(widget.id);
    _crewSub = _store.watch(widget.id).listen((crew) {
      if (!mounted) return;
      setState(() {
        _crew = crew;
        _gone = crew == null || !crew.members.contains(_store.me?.uid);
      });
      if (crew != null) unawaited(_store.loadPeople(crew.members));
    }, onError: (Object _) => setState(() => _gone = true));
    _listen();
    unawaited(_store.markRead(widget.id));
  }

  void _listen() {
    _messageSub?.cancel();
    _messageSub = _store.messages(widget.id, limit: _limit).listen((list) {
      if (!mounted) return;
      final fresh = list.length != _messages.length;
      setState(() => _messages = list);
      unawaited(_store.loadPeople({for (final m in list) m.uid}));
      if (fresh) unawaited(_store.markRead(widget.id));
    }, onError: (Object _) {});
  }

  void _loadOlder() {
    setState(() => _limit += CrewRoomPage.pageSize);
    _listen();
  }

  @override
  void dispose() {
    _crewSub?.cancel();
    _messageSub?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _store.send(widget.id, text);
      _text.clear();
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openRunTitle() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CrewRunTitlePage(
        crewId: widget.id,
        friends: widget.friends,
        store: widget.store,
      ),
    ),
  );

  void _openLobby(String runId) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CrewLobbyPage(
        crewId: widget.id,
        runId: runId,
        friends: widget.friends,
        store: widget.store,
      ),
    ),
  );

  Future<void> _join(CrewRun run) async {
    try {
      await _store.joinRun(run);
      if (mounted) _openLobby(run.id);
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crew = _crew;
    return Scaffold(
      key: _scaffold,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: '크루 목록으로',
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text.rich(
          TextSpan(
            text: crew?.name ?? '크루',
            children: [
              if (crew != null)
                TextSpan(
                  text: '  ${crew.members.length}',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (crew != null && !_gone)
            IconButton(
              tooltip: '채팅방 메뉴',
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffold.currentState?.openEndDrawer(),
            ),
          const SizedBox(width: 4),
        ],
      ),
      endDrawer: crew == null || _gone
          ? null
          : CrewInfoDrawer(
              crew: crew,
              friends: widget.friends,
              store: widget.store,
              onLeft: () => Navigator.of(context)
                ..pop()
                ..pop(),
            ),
      body: SafeArea(
        top: false,
        child: _gone
            ? _goneNote()
            : Column(
                children: [
                  Expanded(child: _list()),
                  _composer(),
                ],
              ),
      ),
    );
  }

  Widget _goneNote() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        '이 크루에 더 이상 들어갈 수 없어요',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
      ),
    ),
  );

  Widget _list() {
    final blocked = {for (final p in widget.friends.blocked) p.uid};
    final me = _store.me?.uid;
    final items = <Widget>[];
    DateTime? lastDay;
    for (final m in _messages) {
      final at = m.createdAt ?? _store.now;
      final day = DateTime(at.year, at.month, at.day);
      if (lastDay != day) {
        items.add(_DayLine(day: day));
        lastDay = day;
      }
      if (m.kind == CrewMessageKind.run && m.runId != null) {
        items.add(
          CrewRunCard(
            key: ValueKey(m.id),
            crewId: widget.id,
            runId: m.runId!,
            title: m.text,
            at: at,
            store: _store,
            onJoin: _join,
            onOpen: (run) => _openLobby(run.id),
          ),
        );
        continue;
      }
      items.add(
        m.kind == CrewMessageKind.text
            ? _Bubble(
                message: m,
                mine: m.uid == me,
                name: _store.nameOf(m.uid),
                initial: _store.person(m.uid)?.initial ?? '·',
                hidden: blocked.contains(m.uid),
                at: at,
              )
            : _Notice(text: _noticeText(m)),
      );
    }
    return ListView(
      // 새 메시지가 아래에 오도록 거꾸로 쌓고, 처음에는 맨 아래를 보여 줍니다.
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        ...items.reversed,
        if (_messages.length >= _limit)
          Center(
            child: TextButton(
              onPressed: _loadOlder,
              child: Text(
                '이전 메시지 보기',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        if (_messages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              '첫 메시지를 보내 보세요',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
      ],
    );
  }

  String _noticeText(CrewMessage m) => switch (m.kind) {
    CrewMessageKind.join => '${_store.nameOf(m.uid)} 님이 들어왔어요',
    CrewMessageKind.leave => '${_store.nameOf(m.uid)} 님이 나갔어요',
    CrewMessageKind.kick => '${_store.nameOf(m.target ?? '')} 님을 크루장이 내보냈어요',
    CrewMessageKind.text || CrewMessageKind.run => m.text,
  };

  Widget _composer() => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: '함께 시작',
          icon: Icon(Icons.directions_run, color: AppColors.primaryText),
          onPressed: _openRunTitle,
        ),
        Expanded(
          child: Semantics(
            label: '메시지 입력',
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 4,
              maxLength: CrewMessage.maxText,
              buildCounter: (
                _, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
              cursorColor: AppColors.textPrimary,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: '보내기',
          icon: Icon(
            Icons.arrow_upward,
            color: _text.text.trim().isEmpty
                ? AppColors.textTertiary
                : AppColors.textPrimary,
          ),
          onPressed: _text.text.trim().isEmpty || _sending ? null : _send,
        ),
      ],
    ),
  );
}

/// 날짜 줄: '10월 24일 토요일'.
class _DayLine extends StatelessWidget {
  const _DayLine({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          '${day.month}월 ${day.day}일 ${weekdays[day.weekday - 1]}요일',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// 들어옴·나감·내보냄 안내.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Center(
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ),
    ),
  );
}

/// 말풍선. 내 메시지는 오른쪽 흰 풍선, 다른 사람은 왼쪽에 얼굴·이름과 함께.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.name,
    required this.initial,
    required this.hidden,
    required this.at,
  });

  final CrewMessage message;
  final bool mine, hidden;
  final String name, initial;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final time = Text(
      clockText(at),
      style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
    );
    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          hidden ? '차단한 사용자의 메시지예요' : message.text,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            fontStyle: hidden ? FontStyle.italic : null,
            color: hidden
                ? AppColors.textTertiary
                : mine
                ? AppColors.background
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
    if (mine) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 56),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [time, const SizedBox(width: 6), bubble],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FriendAvatar(initial: initial, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [bubble, const SizedBox(width: 6), time],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
