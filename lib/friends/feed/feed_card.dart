import 'dart:io';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../home/running/running_start_page.dart' show runningNumberStyle;
import '../../record/data/route_thumbnails.dart';
import '../../record/list/detail/record_detail_page.dart' show RecordRouteMap;
import '../../record/models/running_record.dart' show durationWords, paceText;
import '../data/friend_models.dart';
import '../widgets/friend_widgets.dart';

/// 17 친구 피드 카드: 친구, 달린 시각·장소, 경로 모양, 거리와 고른 항목, 응원 버튼.
/// 내가 공유한 기록은 [onCheer] 없이 받은 응원 수와 응원한 친구만 보여 줍니다(내 기록에는 응원할 수 없음).
class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.item,
    required this.onCheer,
    this.divider = true,
    this.now,
  });

  final FeedItem item;
  final ValueChanged<CheerType>? onCheer;
  final bool divider;

  /// 테스트에서만 넣습니다. '오늘·어제'를 정하는 기준 시각.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final post = item.post;
    final meta = [
      feedTimeLabel(post.startedAt, now ?? DateTime.now()),
      ?post.placeLabel,
    ].join(' · ');
    return Semantics(
      container: true,
      label: '${item.friend.name} 님의 러닝',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: divider ? AppColors.divider : Colors.transparent,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FriendAvatar(initial: item.friend.initial),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.friend.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
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
            Row(
              children: [
                FeedRouteThumbnail(post: post),
                const SizedBox(width: 16),
                Expanded(child: PostStats(post: post)),
              ],
            ),
            // 내 피드에서만, 지도가 왜 안 나오는지 알려 줍니다.
            if (onCheer == null && post.route.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '지도는 \'경로 지도 공개\'를 켜고 공유한 기록 중 출발·도착 200m를 빼고 남는 길이 있을 때만 나와요.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in CheerType.values)
                  _CheerButton(
                    type: type,
                    count: item.count(type),
                    on: item.mine.contains(type),
                    label: onCheer == null
                        ? '받은 ${type.word} 응원 ${item.count(type)}개'
                        : '${item.friend.name} 님에게 ${type.word} 응원 ${item.count(type)}개'
                              '${item.mine.contains(type) ? ' · 내가 보냄' : ''}',
                    onPressed: switch (onCheer) {
                      final cheer? => () => cheer(type),
                      null => null,
                    },
                  ),
              ],
            ),
            if (onCheer == null && item.cheeredBy.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${item.cheeredBy.join(', ')} 님이 응원했어요',
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
    );
  }
}

/// 거리(항상), 고른 항목(시간·페이스·칼로리), 햇반 환산. 공유 미리 보기도 씁니다.
class PostStats extends StatelessWidget {
  const PostStats({super.key, required this.post, this.distanceSize = 30});

  final FeedPost post;
  final double distanceSize;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (post.movingSeconds case final s?) durationWords(s),
      if (post.paceSeconds case final p?) '${paceText(p)}/km',
      if (post.kcal case final k?) '$k kcal',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              post.distanceKm.toStringAsFixed(2),
              style: runningNumberStyle(distanceSize, weight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Text(
              'km',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            details.join(' · '),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (post.hetbahn case final count?) ...[
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              text: '햇반 약 ',
              children: [
                TextSpan(
                  text: '${count.toStringAsFixed(1)}개',
                  style: TextStyle(color: AppColors.primaryText),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

/// 경로 지도를 공개한 기록은 지도 사진, 아니면 경로 모양만 그린 그림.
class FeedRouteThumbnail extends StatefulWidget {
  const FeedRouteThumbnail({super.key, required this.post});

  final FeedPost post;

  @override
  State<FeedRouteThumbnail> createState() => _FeedRouteThumbnailState();
}

class _FeedRouteThumbnailState extends State<FeedRouteThumbnail> {
  Future<File?>? _photo;
  Brightness? _loadedFor;
  List<(double, double)>? _loadedRoute;

  void _load() {
    final post = widget.post;
    _loadedFor = AppColors.current.brightness;
    _loadedRoute = post.route;
    // 위젯 테스트처럼 지도 엔진이 없으면 경로 모양만 그립니다.
    _photo = RecordRouteMap.basemapEnabled && post.route.isNotEmpty
        ? RouteThumbnails.instance.forRoute(
            '${post.ownerUid}_${post.recordId}',
            post.route,
          )
        : null;
  }

  @override
  Widget build(BuildContext context) {
    // 화면 모드가 바뀌거나 다시 올린 기록이면 사진을 다시 고릅니다.
    if (_loadedFor != AppColors.current.brightness ||
        !identical(_loadedRoute, widget.post.route)) {
      _load();
    }
    return FutureBuilder<File?>(
      future: _photo,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return RouteShapeThumbnail(
            shape: widget.post.shape,
            caption: widget.post.route.isEmpty ? '경로 없음' : null,
          );
        }
        return Semantics(
          label: '경로 지도',
          child: ClipRRect(
            borderRadius: AppRadius.thumbnailBorder,
            child: Image.file(
              file,
              width: RouteThumbnails.size,
              height: RouteThumbnails.size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }
}

/// 지도 없이 경로 모양만 그린 작은 그림.
class RouteShapeThumbnail extends StatelessWidget {
  const RouteShapeThumbnail({
    super.key,
    required this.shape,
    this.size = 88,
    this.caption,
  });

  final List<(double, double)> shape;
  final double size;

  /// 그림 아래쪽에 붙이는 작은 글자(지도 없이 모양만 보낸 기록이면 '경로 없음').
  final String? caption;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.mapLand,
      borderRadius: AppRadius.thumbnailBorder,
      border: Border.all(color: AppColors.divider),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        shape.length < 2
            ? Icon(
                Icons.directions_run,
                color: AppColors.textTertiary,
                size: 28,
              )
            : CustomPaint(painter: _ShapePainter(shape)),
        if (caption case final text?)
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    ),
  );
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape);

  final List<(double, double)> shape;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 14.0;
    final side = size.shortestSide - inset * 2;
    Offset at((double, double) p) =>
        Offset(inset + p.$1 * side, inset + p.$2 * side);
    final path = Path()..moveTo(at(shape.first).dx, at(shape.first).dy);
    for (final p in shape.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) => oldDelegate.shape != shape;
}

class _CheerButton extends StatelessWidget {
  const _CheerButton({
    required this.type,
    required this.count,
    required this.on,
    required this.label,
    required this.onPressed,
  });

  final CheerType type;
  final int count;
  final bool on;
  final String label;

  /// null이면 누를 수 없고 수만 보여 줍니다(내 피드).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onPressed != null,
    toggled: on,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: on ? AppColors.textPrimary : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: on ? AppColors.textPrimary : AppColors.borderDefault,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(type.emoji, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: runningNumberStyle(
                  17,
                  weight: FontWeight.w600,
                  color: on ? AppColors.background : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 피드 카드 묶음(최신순). 비어 있을 때와 불러오지 못했을 때 안내를 보여 줍니다.
/// [onCheer]가 없으면 내가 공유한 기록(내 피드)입니다.
class FeedSection extends StatelessWidget {
  const FeedSection({
    super.key,
    required this.items,
    required this.onCheer,
    this.error,
  });

  final List<FeedItem> items;
  final void Function(FeedItem, CheerType)? onCheer;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            error ??
                (onCheer == null
                    ? '아직 공유한 러닝이 없어요\n러닝 결과 화면에서 친구에게 공유할 수 있어요'
                    : '아직 친구들이 공유한 러닝이 없어요'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        )
      else
        for (final (i, item) in items.indexed)
          FeedCard(
            key: ValueKey(item.key),
            item: item,
            divider: i > 0,
            onCheer: switch (onCheer) {
              final cheer? => (type) => cheer(item, type),
              null => null,
            },
          ),
    ],
  );
}
