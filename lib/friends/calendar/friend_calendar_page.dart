import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../record/list/detail/record_detail_page.dart'
    show
        MiniRunningRoute,
        RecordCoordinate,
        clockText,
        recordLine,
        recordMuted,
        recordNumber,
        recordOrange,
        recordSecondary,
        recordText;
import '../../record/models/running_record.dart' show paceText;
import '../data/friend_store.dart';
import '../feed/feed_card.dart' show FeedRouteThumbnail;
import '../widgets/friend_widgets.dart';

/// 17-13~15 친구 달력: 친구가 한 달 동안 공유한 러닝을 기록 탭 달력처럼 보여 줍니다.
/// 공유하지 않은 기록은 서버에 없어 보이지 않습니다.
class FriendCalendarPage extends StatefulWidget {
  const FriendCalendarPage({
    super.key,
    required this.friend,
    this.store,
    this.month,
  });

  final PublicProfile friend;

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final FriendStore? store;

  /// 처음 보여 줄 달. 없으면 이번 달.
  final DateTime? month;

  @override
  State<FriendCalendarPage> createState() => _FriendCalendarPageState();
}

class _FriendCalendarPageState extends State<FriendCalendarPage> {
  FriendStore get _store => widget.store ?? FriendStore.instance;

  late DateTime _month;
  DateTime? _selected;
  List<FeedPost> _posts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final start = widget.month ?? _store.now;
    _month = DateTime(start.year, start.month);
    _load();
  }

  Future<void> _load() async {
    final month = _month;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _store.monthPosts(widget.friend.uid, month);
      if (!mounted || month != _month) return;
      setState(() {
        _posts = posts;
        _loading = false;
        // 처음에는 그 달에 가장 최근에 달린 날을 고릅니다.
        _selected = posts.isEmpty ? null : _day(posts.first.startedAt);
      });
    } on FriendException catch (e) {
      if (!mounted || month != _month) return;
      setState(() {
        _posts = const [];
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _move(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months);
      _selected = null;
    });
    _load();
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  List<FeedPost> _on(DateTime day) => [
    for (final p in _posts)
      if (DateUtils.isSameDay(p.startedAt, day)) p,
  ];

  bool get _isThisMonth {
    final now = _store.now;
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final km = _posts.fold<double>(0, (sum, p) => sum + p.distanceKm);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: friendAppBar(context, '${widget.friend.name} 님의 러닝'),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  FriendAvatar(initial: widget.friend.initial, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.friend.name,
                          style: recordText(18, weight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _loading
                              ? '불러오는 중…'
                              : '${_month.month}월에 ${_posts.length}번 달렸어요 · '
                                    '${km.toStringAsFixed(2)} km',
                          style: recordText(13, color: recordSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    tooltip: '이전 달',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _move(-1),
                  ),
                  Expanded(
                    child: Text(
                      '${_month.year}년 ${_month.month}월',
                      textAlign: TextAlign.center,
                      style: recordText(16, weight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 달',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _isThisMonth ? null : () => _move(1),
                  ),
                ],
              ),
              _grid(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.route, size: 18, color: recordOrange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '달린 날엔 그날의 경로가 그려져요 · 친구가 공유한 기록만 보여요',
                      style: recordText(12, color: recordMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Divider(height: 1, color: recordLine),
              ..._details(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid() {
    final first = DateTime(_month.year, _month.month);
    final offset = first.weekday % 7;
    final count = DateUtils.getDaysInMonth(_month.year, _month.month);
    final cells = ((offset + count) / 7).ceil() * 7;
    final today = _store.now;
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            for (final day in ['일', '월', '화', '수', '목', '금', '토'])
              Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: recordText(12, color: recordMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 66,
          ),
          itemBuilder: (context, index) {
            final number = index - offset + 1;
            if (number < 1 || number > count) return const SizedBox.shrink();
            final day = DateTime(_month.year, _month.month, number);
            final entries = _on(day);
            final active =
                _selected != null && DateUtils.isSameDay(_selected, day);
            final isToday = DateUtils.isSameDay(day, today);
            return Semantics(
              label: '${_month.month}월 $number일, 러닝 ${entries.length}건',
              selected: active,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(17),
                onTap: () => setState(() => _selected = day),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 1,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.pick(
                            const Color(0xFF151616),
                            AppColors.card,
                          )
                        : Colors.transparent,
                    border: active
                        ? Border.all(color: AppColors.textPrimary)
                        : null,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        '$number',
                        style: recordNumber(
                          16,
                          color: entries.isEmpty
                              ? recordMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 15,
                        height: 2,
                        color: isToday
                            ? AppColors.textPrimary
                            : Colors.transparent,
                      ),
                      const SizedBox(height: 5),
                      // 그날 여러 번 달렸다면 가장 긴 거리의 경로 모양만 그립니다.
                      if (entries.isNotEmpty)
                        SizedBox(
                          width: 30,
                          height: 18,
                          child: MiniRunningRoute(
                            coordinates: _shapeCoordinates(
                              entries.reduce(
                                (a, b) => b.distanceKm > a.distanceKm ? b : a,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 0~1로 줄인 경로 모양을 작은 경로 그림이 받는 좌표로 바꿉니다(아래로 갈수록 y가 커짐).
  static List<RecordCoordinate> _shapeCoordinates(FeedPost post) => [
    for (final (x, y) in post.shape) RecordCoordinate(-y, x),
  ];

  List<Widget> _details() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 44),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ];
    }
    final selected = _selected;
    final runs = selected == null ? const <FeedPost>[] : _on(selected);
    if (runs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 44),
          child: Text(
            _error ??
                (_posts.isEmpty ? '이번 달에 공유한 러닝이 없어요' : '선택한 날짜에는 러닝 기록이 없어요'),
            textAlign: TextAlign.center,
            style: recordText(14, color: recordMuted),
          ),
        ),
      ];
    }
    return [for (final p in runs) _card(p)];
  }

  Widget _card(FeedPost p) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final t = p.startedAt;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${t.month}월 ${t.day}일 ${weekdays[t.weekday - 1]}요일',
                  style: recordText(17, weight: FontWeight.w800),
                ),
              ),
              Flexible(
                child: Text(
                  [clockText(t), ?p.placeLabel].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: recordText(11, color: recordSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(child: FeedRouteThumbnail(post: p)),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _metric('거리', p.distanceKm.toStringAsFixed(2), 'km'),
                VerticalDivider(width: 24, color: recordLine),
                _metric('운동 시간', switch (p.movingSeconds) {
                  final s? =>
                    '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
                  null => '–',
                }, ''),
                VerticalDivider(width: 24, color: recordLine),
                _metric('페이스', switch (p.paceSeconds) {
                  final s? => paceText(s),
                  null => '–',
                }, ''),
                VerticalDivider(width: 24, color: recordLine),
                _metric(
                  '칼로리',
                  p.kcal?.toString() ?? '–',
                  p.kcal == null ? '' : 'kcal',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, String unit) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: recordText(11, color: recordSecondary)),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: recordNumber(23)),
                TextSpan(
                  text: unit,
                  style: recordText(10, color: recordSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
