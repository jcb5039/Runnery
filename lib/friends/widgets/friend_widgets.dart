import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_component_metrics.dart';
import '../../design_system/app_radius.dart';
import '../data/friend_models.dart';

/// 이름 첫 글자를 담은 동그라미.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({
    super.key,
    required this.initial,
    this.size = 40,
    this.borderColor,
    this.textColor,
  });

  final String initial;
  final double size;

  /// 테두리 색. 없으면 기본 회색이고, 나를 표시할 때 주황을 씁니다.
  final Color? borderColor;

  /// 글자 색. 흰 바탕 위에 놓을 때 바꿉니다.
  final Color? textColor;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: borderColor ?? AppColors.borderControl),
    ),
    child: Text(
      initial,
      style: TextStyle(
        fontSize: size * 0.375,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    ),
  );
}

/// 친구 한 사람의 줄: 아바타, 이름, @아이디, 오른쪽 버튼.
class FriendRow extends StatelessWidget {
  const FriendRow({
    super.key,
    required this.person,
    this.trailing,
    this.divider = true,
  });

  final PublicProfile person;
  final Widget? trailing;

  /// 위에 구분선을 그을지. 목록의 첫 줄은 긋지 않습니다.
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: divider ? AppColors.divider : Colors.transparent,
        ),
      ),
    ),
    child: Row(
      children: [
        FriendAvatar(initial: person.initial),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '@${person.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (trailing case final trailing?) ...[
          const SizedBox(width: 12),
          trailing,
        ],
      ],
    ),
  );
}

/// 이름 옆 작은 표시('나', '달성'). [filled]면 흰 바탕, [muted]면 흐린 회색입니다.
class FriendChip extends StatelessWidget {
  const FriendChip({
    super.key,
    required this.label,
    this.filled = false,
    this.muted = false,
    this.icon,
  });

  final String label;
  final bool filled, muted;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = filled
        ? AppColors.background
        : muted
        ? AppColors.textTertiary
        : AppColors.textPrimary;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: filled ? AppColors.textPrimary : Colors.transparent,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(
          color: filled
              ? AppColors.textPrimary
              : muted
              ? AppColors.divider
              : AppColors.borderDefault,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final icon?) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 가는 진행 막대. [fraction]은 0~1이고 넘치면 1로 그립니다.
class FriendProgressBar extends StatelessWidget {
  const FriendProgressBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 4,
  });

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: AppRadius.pillBorder,
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.divider),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction.clamp(0.0, 1.0),
            child: ColoredBox(color: color),
          ),
        ],
      ),
    ),
  );
}

/// 섹션 제목 줄: 제목, 가로선, 오른쪽 작은 설명.
class FriendSectionHeader extends StatelessWidget {
  const FriendSectionHeader({super.key, required this.title, this.meta});

  final String title;
  final String? meta;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Divider(height: 1, thickness: 1, color: AppColors.borderDefault),
      ),
      if (meta case final meta?) ...[
        const SizedBox(width: 12),
        Text(
          meta,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    ],
  );
}

/// 줄 오른쪽의 작은 둥근 버튼. [filled]면 흰 바탕, 아니면 테두리만 있습니다.
class FriendPillButton extends StatelessWidget {
  const FriendPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final style = filled
        ? FilledButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.background,
            disabledBackgroundColor: AppColors.borderDefault,
          )
        : OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.borderDefault),
          );
    final sized = style.copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      fixedSize: const WidgetStatePropertyAll(Size.fromHeight(36)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
    final text = Text(label);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      button: true,
      child: filled
          ? FilledButton(onPressed: onPressed, style: sized, child: text)
          : OutlinedButton(onPressed: onPressed, style: sized, child: text),
    );
  }
}

/// 바텀 시트 아래쪽의 큰 버튼. [filled]면 흰 바탕, 아니면 테두리만 있습니다.
class FriendSheetButton extends StatelessWidget {
  const FriendSheetButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.height = AppComponentMetrics.whiteButtonMediumHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final size = Size.fromHeight(height);
    const shape = RoundedRectangleBorder(borderRadius: AppRadius.pillBorder);
    const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: size,
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.background,
              shape: shape,
              textStyle: textStyle,
            ),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderDefault),
              shape: shape,
              textStyle: textStyle,
            ),
            child: Text(label),
          );
  }
}

/// 친구 화면들의 위쪽 막대: 뒤로 가기, 가운데 제목, 오른쪽 버튼.
AppBar friendAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
}) => AppBar(
  backgroundColor: AppColors.background,
  surfaceTintColor: Colors.transparent,
  leading: IconButton(
    tooltip: '뒤로',
    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
    onPressed: () => Navigator.pop(context),
  ),
  title: Text(
    title,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  ),
  centerTitle: true,
  actions: actions,
);

/// 화면 아래에 짧은 안내를 띄웁니다.
void showFriendMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
