import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../home/running/running_home_page.dart' show runningLocationActive;
import '../data/friend_store.dart';
import '../widgets/friend_widgets.dart';
import 'friend_notifications_page.dart';

/// 앱을 켜 둔 동안 새 친구 요청이 오면 화면 위에서 띠를 내려 알려 줍니다(꺼진 폰을 깨우는 알림은 없음).
/// 띠를 누르면 알림 화면이 열리고, 4초 뒤나 위로 밀면 사라집니다.
/// 앱을 켤 때 이미 와 있던 요청은 띠 없이 알림 종의 빨간 점으로만 알려 주고, 달리는 중에는 띠를 미뤘다가
/// 러닝이 끝나면 보여 줍니다.
class FriendRequestListener extends StatefulWidget {
  const FriendRequestListener({super.key, required this.child, this.store});

  final Widget child;

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final FriendStore? store;

  /// 띠가 보이는 시간.
  static const showFor = Duration(seconds: 4);

  @override
  State<FriendRequestListener> createState() => _FriendRequestListenerState();
}

class _FriendRequestListenerState extends State<FriendRequestListener> {
  FriendStore get _store => widget.store ?? FriendStore.instance;

  StreamSubscription<List<PublicProfile>>? _sub;

  /// 이미 알린(또는 앱을 켤 때 와 있던) 요청을 보낸 사람.
  Set<String>? _seen;

  /// 달리는 동안 와서 아직 띠로 알리지 못한 요청.
  final List<PublicProfile> _waiting = [];
  OverlayEntry? _banner;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _sub = _store.watchIncoming().listen(_onIncoming, onError: (Object _) {});
    runningLocationActive.addListener(_showWaiting);
  }

  @override
  void dispose() {
    _sub?.cancel();
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

  void _showWaiting() {
    if (!mounted || runningLocationActive.value || _waiting.isEmpty) return;
    final first = _waiting.first, more = _waiting.length - 1;
    _waiting.clear();
    _show(
      more > 0
          ? '${first.name} 님 외 $more명이 친구 요청을 보냈어요'
          : '${first.name} 님이 친구 요청을 보냈어요',
      first.initial,
    );
  }

  void _show(String message, String initial) {
    _remove();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _banner = OverlayEntry(
      builder: (_) => _Banner(
        message: message,
        initial: initial,
        onTap: () {
          _remove();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FriendNotificationsPage(friends: widget.store),
            ),
          );
        },
        onDismiss: _remove,
      ),
    );
    overlay.insert(_banner!);
    _hide = Timer(FriendRequestListener.showFor, _remove);
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
