import 'dart:async';

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 방금 한 행동 바로 아래(화면 맨 아래 버튼이면 바로 위)에 보여 주는 짧은 안내.
/// 화면 아래에서 올라오는 알림(SnackBar)은 하단 탭·버튼을 가려서 쓰지 않고, 이것을 씁니다.
/// 실패·안 되는 이유는 빨간 글씨, 잘 됐지만 화면에 변화가 없는 일(메일 보냄 등)은 회색 글씨입니다.
///
/// 한 화면에 [Notices]를 하나 두고, 안내를 보여 줄 자리마다 [NoticeSlot]을 이름([id])과 함께 놓습니다.
/// `notices.show('줄 이름', '인터넷 연결을 확인해주세요')`처럼 부르면 그 자리에 [showFor] 동안 보입니다.
class Notices extends ChangeNotifier {
  /// 안내가 보이는 시간.
  static const showFor = Duration(seconds: 5);

  final Map<String, (String, bool)> _shown = {};
  final Map<String, Timer> _timers = {};
  bool _disposed = false;

  /// [id] 자리에 보일 안내(글자, 잘 된 일인지). 없으면 null.
  (String, bool)? of(String id) => _shown[id];

  /// [id] 자리에 [message]를 보여 줍니다. [success]면 회색, 아니면 빨간 글씨입니다.
  /// 같은 자리에 새 안내가 오면 바꿔 보여 줍니다.
  void show(String id, String message, {bool success = false}) {
    if (_disposed) return;
    _timers.remove(id)?.cancel();
    _shown[id] = (message, success);
    _timers[id] = Timer(showFor, () => clear(id));
    notifyListeners();
  }

  /// [id] 자리의 안내를 지웁니다(다시 누를 때 등).
  void clear(String id) {
    if (_disposed) return;
    _timers.remove(id)?.cancel();
    if (_shown.remove(id) != null) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

/// [Notices]의 [id] 자리. 안내가 없으면 자리를 차지하지 않습니다.
class NoticeSlot extends StatelessWidget {
  const NoticeSlot({
    super.key,
    required this.notices,
    required this.id,
    this.padding = const EdgeInsets.only(top: 6, bottom: 2),
    this.textAlign = TextAlign.start,
  });

  final Notices notices;
  final String id;
  final EdgeInsetsGeometry padding;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: notices,
    builder: (context, _) {
      final shown = notices.of(id);
      if (shown == null) return const SizedBox.shrink();
      return InlineNotice(
        shown.$1,
        success: shown.$2,
        padding: padding,
        textAlign: textAlign,
      );
    },
  );
}

/// 안내 글씨 한 줄(또는 몇 줄). [message]가 null이면 자리를 차지하지 않습니다.
/// 화면이 스스로 상태를 들고 있을 때(입력 창 안의 실패 등) 바로 씁니다.
class InlineNotice extends StatelessWidget {
  const InlineNotice(
    this.message, {
    super.key,
    this.success = false,
    this.padding = const EdgeInsets.only(top: 6, bottom: 2),
    this.textAlign = TextAlign.start,
  });

  final String? message;
  final bool success;
  final EdgeInsetsGeometry padding;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: success ? AppColors.textSecondary : AppColors.error,
          ),
        ),
      ),
    );
  }
}

/// 상태가 없는 화면에서 [Notices]를 쓰게 해 줍니다. 화면이 사라지면 함께 정리합니다.
class NoticeHost extends StatefulWidget {
  const NoticeHost({super.key, required this.builder});

  final Widget Function(BuildContext context, Notices notices) builder;

  @override
  State<NoticeHost> createState() => _NoticeHostState();
}

class _NoticeHostState extends State<NoticeHost> {
  final _notices = Notices();

  @override
  void dispose() {
    _notices.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _notices);
}
