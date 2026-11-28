import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/inline_notice.dart';
import '../data/crew_store.dart';
import '../data/friend_store.dart';
import '../widgets/friend_widgets.dart';
import 'crew_room_page.dart';

/// 크루 만들기: 이름(20자까지)을 정하고, 함께할 친구를 골라 초대합니다(나중에 서랍에서도 초대할 수 있음).
class CrewNewPage extends StatefulWidget {
  const CrewNewPage({super.key, required this.friends, this.store});

  final FriendStore friends;

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final CrewStore? store;

  @override
  State<CrewNewPage> createState() => _CrewNewPageState();
}

class _CrewNewPageState extends State<CrewNewPage> {
  CrewStore get _store => widget.store ?? CrewStore.instance;

  final _name = TextEditingController();
  final Set<String> _selected = {};
  bool _sending = false;

  /// 만들지 못한 이유. 만들기 버튼 바로 아래에 빨간 글씨로 보여 줍니다.
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(widget.friends.refresh());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_sending || _name.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final chosen = [
        for (final f in widget.friends.friends)
          if (_selected.contains(f.uid)) f,
      ];
      final id = await _store.create(_name.text, chosen);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CrewRoomPage(
            id: id,
            friends: widget.friends,
            store: widget.store,
          ),
        ),
      );
    } on FriendException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: friendAppBar(context, '크루 만들기'),
    body: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: widget.friends,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            const Text(
              '크루 이름',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              maxLength: Crew.maxName,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              cursorColor: AppColors.textPrimary,
              decoration: InputDecoration(
                hintText: '예: 여의도 퇴근런',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.borderControl),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '초대할 친구',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '고르지 않아도 돼요. 크루에 들어간 뒤 서랍에서 언제든 초대할 수 있어요.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 14),
            CrewFriendPicker(
              friends: widget.friends,
              selected: _selected,
              onToggle: (uid) =>
                  setState(() => _selected.remove(uid) || _selected.add(uid)),
            ),
            const SizedBox(height: 32),
            FriendSheetButton(
              label: _sending ? '만드는 중…' : '만들기',
              filled: true,
              onPressed: _name.text.trim().isEmpty || _sending ? null : _create,
            ),
            InlineNotice(_error, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

/// 크루에 초대할 친구 고르기. [members]는 이미 멤버라 빼고, [invited]는 '초대함'으로 막아 둡니다.
class CrewFriendPicker extends StatelessWidget {
  const CrewFriendPicker({
    super.key,
    required this.friends,
    required this.selected,
    required this.onToggle,
    this.members = const {},
    this.invited = const {},
  });

  final FriendStore friends;
  final Set<String> selected, members, invited;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final list = [
      for (final f in friends.friends)
        if (!members.contains(f.uid)) f,
    ];
    if (list.isEmpty) {
      return Text(
        friends.loading
            ? '불러오는 중이에요'
            : friends.friends.isEmpty
            ? '먼저 친구를 추가해 주세요'
            : '초대할 수 있는 친구가 모두 크루에 있어요',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in list)
          invited.contains(f.uid)
              ? Opacity(
                  opacity: .5,
                  child: Semantics(
                    label: '${f.name} 님 초대함',
                    excludeSemantics: true,
                    child: FriendChoice(
                      person: f,
                      selected: false,
                      onTap: () {},
                    ),
                  ),
                )
              : FriendChoice(
                  person: f,
                  selected: selected.contains(f.uid),
                  onTap: () => onToggle(f.uid),
                ),
      ],
    );
  }
}

/// 서랍의 '멤버 초대': 크루에 없는 친구를 골라 초대를 보냅니다.
class CrewInvitePage extends StatefulWidget {
  const CrewInvitePage({
    super.key,
    required this.crew,
    required this.friends,
    this.store,
  });

  final Crew crew;
  final FriendStore friends;
  final CrewStore? store;

  @override
  State<CrewInvitePage> createState() => _CrewInvitePageState();
}

class _CrewInvitePageState extends State<CrewInvitePage> {
  CrewStore get _store => widget.store ?? CrewStore.instance;

  final Set<String> _selected = {};
  Set<String> _invited = const {};
  bool _sending = false;

  /// 초대하지 못한 이유. 초대하기 버튼 바로 아래에 빨간 글씨로 보여 줍니다.
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(widget.friends.refresh());
    unawaited(_loadInvited());
  }

  Future<void> _loadInvited() async {
    try {
      final invited = await _store.invited(widget.crew.id);
      if (mounted) setState(() => _invited = invited);
    } on FriendException {
      // 못 불러오면 모두 고를 수 있게 둡니다(이미 보낸 초대는 서버가 막습니다).
    }
  }

  Future<void> _send() async {
    if (_sending || _selected.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    var sent = 0;
    String? failed;
    for (final f in widget.friends.friends) {
      if (!_selected.contains(f.uid)) continue;
      try {
        await _store.invite(widget.crew, f);
        sent++;
      } on FriendException catch (e) {
        failed = e.message;
      }
    }
    if (!mounted) return;
    if (sent > 0) {
      // 화면이 닫히는 것으로 보냈다는 걸 알 수 있어 따로 알리지 않습니다.
      Navigator.pop(context);
    } else {
      setState(() {
        _sending = false;
        _error = failed ?? '초대하지 못했어요';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: friendAppBar(context, '멤버 초대'),
    body: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: widget.friends,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Text(
              '${widget.crew.name}에 초대할 친구를 골라 주세요',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '친구가 알림에서 수락하면 크루에 들어와요. 흐린 친구는 이미 초대했어요.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            CrewFriendPicker(
              friends: widget.friends,
              selected: _selected,
              members: widget.crew.members.toSet(),
              invited: _invited,
              onToggle: (uid) =>
                  setState(() => _selected.remove(uid) || _selected.add(uid)),
            ),
            const SizedBox(height: 32),
            FriendSheetButton(
              label: _sending
                  ? '보내는 중…'
                  : _selected.isEmpty
                  ? '초대하기'
                  : '${_selected.length}명 초대하기',
              filled: true,
              onPressed: _selected.isEmpty || _sending ? null : _send,
            ),
            InlineNotice(_error, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
