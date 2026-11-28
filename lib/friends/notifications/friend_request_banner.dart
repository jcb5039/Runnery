import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../home/running/running_home_page.dart' show runningLocationActive;
import '../crew/crew_room_page.dart';
import '../data/crew_store.dart';
import '../data/friend_store.dart';
import '../widgets/friend_widgets.dart';
import 'friend_notifications_page.dart';

/// 앱을 켜 둔 동안 새 친구 요청이나 크루 초대가 오면 화면 위에서 띠를 내려 알려 줍니다(꺼진 폰을 깨우는 알림은 없음).
/// 알림이 켜진 크루에 새 채팅이 오면, 그 채팅방을 보고 있지 않을 때 '보낸 사람: 내용'을 띠로 보여 주고 누르면 채팅방이 열립니다
/// (달리는 중에는 띄우지 않음).
/// 요청·초대 띠를 누르면 알림 화면이 열리고, 4초 뒤나 위로 밀면 사라집니다.
/// 앱을 켤 때 이미 와 있던 요청·초대는 띠 없이 알림 종의 빨간 점으로만 알려 주고, 달리는 중에는 띠를 미뤘다가
/// 러닝이 끝나면 보여 줍니다.
class FriendRequestListener extends StatefulWidget {
  const FriendRequestListener({
    super.key,
    required this.child,
    this.store,
    this.crew,
  });

  final Widget child;

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final FriendStore? store;
  final CrewStore? crew;

  /// 띠가 보이는 시간.
  static const showFor = Duration(seconds: 4);

  @override
  State<FriendRequestListener> createState() => _FriendRequestListenerState();
}

class _FriendRequestListenerState extends State<FriendRequestListener> {
  FriendStore get _store => widget.store ?? FriendStore.instance;
  CrewStore get _crew => widget.crew ?? CrewStore.instance;

  StreamSubscription<List<PublicProfile>>? _sub;
  StreamSubscription<List<CrewInvite>>? _crewSub;

  /// 이미 알린(또는 앱을 켤 때 와 있던) 요청을 보낸 사람.
  Set<String>? _seen;

  /// 달리는 동안 와서 아직 띠로 알리지 못한 요청.
  final List<PublicProfile> _waiting = [];

  /// 이미 알린(또는 앱을 켤 때 와 있던) 크루 초대 번호.
  Set<String>? _seenCrew;

  /// 아직 띠로 알리지 못한 크루 초대.
  final List<CrewInvite> _waitingCrew = [];

  /// 크루 번호 → 이미 본 마지막 채팅 시각. 처음 목록을 받기 전이면 null입니다.
  Map<String, DateTime?>? _lastChat;
  OverlayEntry? _banner;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _sub = _store.watchIncoming().listen(_onIncoming, onError: (Object _) {});
    _crewSub = _crew.watchInvites().listen(
      _onCrewInvites,
      onError: (Object _) {},
    );
    runningLocationActive.addListener(_showWaiting);
    // 친구 탭을 열지 않아도 새 채팅·초대를 알 수 있게 크루 소식을 바로 받기 시작합니다.
    _crew
      ..addListener(_onCrews)
      ..start();
    // 이미 받아 둔 목록이 있으면 지금 것을 '본 것'으로 적어 둡니다.
    _onCrews();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _crewSub?.cancel();
    _crew.removeListener(_onCrews);
    runningLocationActive.removeListener(_showWaiting);
    _remove();
    super.dispose();
  }

  void _onIncoming(List<PublicProfile> people) {
    final seen = _seen;
    if (seen == null) {
      // 처음 받은 목록은 앱을 켜기 전에 와 있던 요청이라 띠를 띄우지 않습니다.
      _seen = {for (final p in people) p.uid};
      return;
    }
    final fresh = [
      for (final p in people)
        if (seen.add(p.uid)) p,
    ];
    // 취소된 요청은 잊어서, 다시 보내면 또 알려 줍니다.
    seen.retainAll({for (final p in people) p.uid});
    _waiting
      ..removeWhere((w) => !people.any((p) => p.uid == w.uid))
      ..addAll(fresh);
    _showWaiting();
  }

  Future<void> _onCrewInvites(List<CrewInvite> invites) async {
    final seen = _seenCrew;
    if (seen == null) {
      // 처음 받은 목록은 앱을 켜기 전에 와 있던 초대라 띠를 띄우지 않습니다.
      _seenCrew = {for (final i in invites) i.id};
      return;
    }
    final fresh = [
      for (final i in invites)
        if (seen.add(i.id)) i,
    ];
    // 거절·취소된 초대는 잊어서, 다시 초대하면 또 알려 줍니다.
    seen.retainAll({for (final i in invites) i.id});
    _waitingCrew
      ..removeWhere((w) => !invites.any((i) => i.id == w.id))
      ..addAll(fresh);
    if (fresh.isEmpty) return;
    // 띠에 보낸 사람 이름을 쓰려고 먼저 불러옵니다.
    await _crew.loadPeople({for (final i in fresh) i.from});
    _showWaiting();
  }

  /// 크루 목록이 바뀔 때마다 새 채팅이 왔는지 봅니다.
  void _onCrews() {
    if (!_crew.loaded) return;
    final seen = _lastChat;
    final crews = _crew.crews;
    if (seen == null) {
      // 앱을 켤 때 이미 와 있던 채팅은 띠를 띄우지 않습니다.
      _lastChat = {for (final c in crews) c.id: c.lastMessage?.at};
      return;
    }
    final me = _crew.me?.uid;
    final blocked = {for (final p in _store.blocked) p.uid};
    (Crew, CrewLastMessage)? fresh;
    for (final c in crews) {
      final last = c.lastMessage;
      final known = seen.containsKey(c.id);
      final before = seen[c.id];
      seen[c.id] = last?.at ?? before;
      // 새로 들어간 크루의 예전 채팅은 알리지 않습니다.
      if (!known || last == null) continue;
      if (before != null && !last.at.isAfter(before)) continue;
      if (last.uid == me || blocked.contains(last.uid)) continue;
      if (_crew.muted(c.id) || _crew.viewing(c.id)) continue;
      fresh = (c, last);
    }
    seen.removeWhere((id, _) => !crews.any((c) => c.id == id));
    if (fresh == null || !mounted || runningLocationActive.value) return;
    final (crew, last) = fresh;
    unawaited(_showChat(crew, last));
  }

  Future<void> _showChat(Crew crew, CrewLastMessage last) async {
    await _crew.loadPeople({last.uid});
    if (!mounted || _crew.viewing(crew.id)) return;
    _show(
      '${_crew.nameOf(last.uid)}: ${last.text}',
      _crew.person(last.uid)?.initial ?? '크',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              CrewRoomPage(id: crew.id, friends: _store, store: widget.crew),
        ),
      ),
    );
  }

  void _showWaiting() {
    if (!mounted || runningLocationActive.value) return;
    if (_waiting.isEmpty) {
      _showWaitingCrew();
      return;
    }
    final first = _waiting.first, more = _waiting.length - 1;
    _waiting.clear();
    _show(
      more > 0
          ? '${first.name} 님 외 $more명이 친구 요청을 보냈어요'
          : '${first.name} 님이 친구 요청을 보냈어요',
      first.initial,
    );
  }

  void _showWaitingCrew() {
    if (_waitingCrew.isEmpty) return;
    final first = _waitingCrew.first, more = _waitingCrew.length - 1;
    _waitingCrew.clear();
    final name = _crew.nameOf(first.from);
    _show(
      more > 0
          ? "'${first.crewName}' 외 크루 $more곳에서 초대가 왔어요"
          : "$name 님이 '${first.crewName}' 크루에 초대했어요",
      _crew.person(first.from)?.initial ?? '크',
    );
  }

  /// [onTap]이 없으면 띠를 눌렀을 때 알림 화면을 엽니다.
  void _show(String message, String initial, {VoidCallback? onTap}) {
    _remove();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _banner = OverlayEntry(
      builder: (_) => _Banner(
        message: message,
        initial: initial,
        onTap: () {
          if (onTap != null) {
            _next();
            onTap();
            return;
          }
          // 알림 화면에서 모두 보이니, 기다리던 띠도 함께 지웁니다.
          _waiting.clear();
          _waitingCrew.clear();
          _remove();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FriendNotificationsPage(
                friends: widget.store,
                crew: widget.crew,
              ),
            ),
          );
        },
        onDismiss: _next,
      ),
    );
    overlay.insert(_banner!);
    _hide = Timer(FriendRequestListener.showFor, _next);
  }

  /// 띠를 닫고, 기다리던 알림이 있으면 이어서 보여 줍니다.
  void _next() {
    _remove();
    _showWaiting();
  }

  void _remove() {
    _hide?.cancel();
    _hide = null;
    _banner?.remove();
    _banner = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 화면 위의 띠: 보낸 사람 첫 글자, 안내, '보기'.
class _Banner extends StatefulWidget {
  const _Banner({
    required this.message,
    required this.initial,
    required this.onTap,
    required this.onDismiss,
  });

  final String message, initial;
  final VoidCallback onTap, onDismiss;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 12,
    right: 12,
    top: 0,
    child: SafeArea(
      bottom: false,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, -1.4),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic)),
        child: GestureDetector(
          // 위로 밀면 닫습니다.
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < 0) widget.onDismiss();
          },
          child: Semantics(
            liveRegion: true,
            button: true,
            label: '${widget.message}, 눌러서 보기',
            excludeSemantics: true,
            child: Material(
              color: AppColors.sheet,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.thumbnailBorder,
                side: BorderSide(color: AppColors.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                  child: Row(
                    children: [
                      FriendAvatar(initial: widget.initial, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '보기',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
