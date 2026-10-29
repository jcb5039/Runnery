import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_spacing.dart';
import '../../home/running/running_start_page.dart' show runningNumberStyle;
import '../../record/models/running_record.dart' show clockText;
import '../data/friend_store.dart';
import '../data/together_store.dart';
import '../widgets/friend_widgets.dart';
import 'together_lobby_page.dart';

/// 17-5 함께 달리기 약속 만들기: 친구(여러 명), 날짜(오늘부터 7일), 시간, 목표 거리를 골라 보냅니다.
/// [quick]이면 '지금 바로 같이 뛰기': 친구만 고르면 목표 없이 지금 시각으로 보내고 바로 대기실로 갑니다.
class TogetherNewPage extends StatefulWidget {
  const TogetherNewPage({
    super.key,
    required this.friends,
    this.preselected = const [],
    this.quick = false,
    this.store,
  });

  final FriendStore friends;

  /// 처음부터 골라 둘 친구 uid(친구 목록·다시 약속 잡기에서 들어올 때).
  final List<String> preselected;
  final bool quick;

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final TogetherStore? store;

  @override
  State<TogetherNewPage> createState() => _TogetherNewPageState();
}

class _TogetherNewPageState extends State<TogetherNewPage> {
  TogetherStore get _store => widget.store ?? TogetherStore.instance;

  late final Set<String> _selected = {...widget.preselected};
  int _day = 0;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  int _km = 5;
  bool _sending = false;

  /// 오늘부터 7일.
  List<DateTime> get _days {
    final now = _store.now;
    final today = DateTime(now.year, now.month, now.day);
    return [for (var i = 0; i < 7; i++) today.add(Duration(days: i))];
  }

  DateTime get _when {
    final day = _days[_day];
    return DateTime(day.year, day.month, day.day, _time.hour, _time.minute);
  }

  @override
  void initState() {
    super.initState();
    // 오늘 오전 8시가 이미 지났으면 내일로 골라 둡니다.
    if (!_when.isAfter(_store.now)) _day = 1;
    unawaited(widget.friends.refresh());
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: '약속 시간',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _toggle(String uid) => setState(() {
    if (!_selected.remove(uid) && _selected.length < Together.maxMembers - 1) {
      _selected.add(uid);
    }
  });

  Future<void> _send(List<PublicProfile> chosen) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      if (widget.quick) {
        final id = await _store.startNow(chosen);
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => TogetherLobbyPage(
              id: id,
              store: widget.store,
              friends: widget.friends,
            ),
          ),
        );
        return;
      }
      await _store.create(chosen, _when, _km);
      if (!mounted) return;
      showFriendMessage(context, '약속을 보냈어요');
      Navigator.pop(context);
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.friends, _store]),
    builder: (context, _) {
      final friends = widget.friends.friends;
      final chosen = [
        for (final f in friends)
          if (_selected.contains(f.uid)) f,
      ];
      final busyDays = {
        for (final t in _store.active)
          DateTime(t.startsAt.year, t.startsAt.month, t.startsAt.day),
      };
      final quick = widget.quick;
      final inPast = !quick && !_when.isAfter(_store.now);
      final canSend = chosen.isNotEmpty && !inPast && !_sending;
      final day = _days[_day];
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: friendAppBar(context, quick ? '지금 바로 같이 뛰기' : '함께 달리기 약속'),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FriendSheetButton(
            label: _sending
                ? '보내는 중이에요'
                : quick
                ? '같이 뛰자고 보내기'
                : '약속 보내기',
            filled: true,
            onPressed: canSend ? () => _send(chosen) : null,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            20,
            AppSpacing.screenHorizontal,
            AppSpacing.space6,
          ),
          children: [
            _title('누구와 달릴까요?'),
            const SizedBox(height: 8),
            const Text(
              '여러 명을 함께 고를 수 있어요',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),
            if (friends.isEmpty)
              Text(
                widget.friends.loading ? '불러오는 중이에요' : '먼저 친구를 추가해 주세요',
                style: const TextStyle(color: AppColors.textSecondary),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in friends)
                    _FriendChoice(
                      person: f,
                      selected: _selected.contains(f.uid),
                      onTap: () => _toggle(f.uid),
                    ),
                ],
              ),
            if (quick) ...[
              const SizedBox(height: 24),
              const Text(
                '보내면 바로 대기실로 가요. 친구가 앱을 열어 두었다면 바로 초대 창이 떠요. '
                '목표 없이 자유롭게 달리고, 멈추고 끝내는 건 각자 해요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ] else ...[
              const SizedBox(height: 28),
              _title('날짜'),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final (i, d) in _days.indexed) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: _DayChoice(
                        day: d,
                        selected: i == _day,
                        busy: busyDays.contains(d),
                        onTap: () => setState(() => _day = i),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '점이 있는 날은 이미 약속이 있어요',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 26),
              _title('시간'),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickTime,
                child: Container(
                  height: 46,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderControl),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          clockText(_when),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.schedule,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (inPast) ...[
                const SizedBox(height: 8),
                const Text(
                  '지난 시간이에요. 다른 시간을 골라 주세요',
                  style: TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],
              const SizedBox(height: 26),
              _title('목표 거리'),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final (i, km) in Together.kmOptions.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: FriendPillButton(
                        label: '$km km',
                        filled: km == _km,
                        onPressed: () => setState(() => _km = km),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${day.month}월 ${day.day}일 (${weekdayLetter(day)}) '
                            '${clockText(_when)} · $_km km',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            chosen.isEmpty
                                ? '함께 달릴 친구를 골라 주세요'
                                : '${chosen.map((f) => f.name).join(', ')} 님에게 약속을 보내요',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '약속 시간이 되면 대기실에서 함께 시작해요. 시작을 누르면 대기실에 있는 모두가 같이 출발하고, 멈추고 끝내는 건 각자 해요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _title(String text) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  );
}

class _FriendChoice extends StatelessWidget {
  const _FriendChoice({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final PublicProfile person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.textPrimary : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.textPrimary : AppColors.borderDefault,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: EdgeInsets.fromLTRB(5, 0, selected ? 12 : 14, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FriendAvatar(
                initial: person.initial,
                size: 28,
                borderColor: selected ? AppColors.background : null,
                textColor: selected ? AppColors.background : null,
              ),
              const SizedBox(width: 8),
              Text(
                person.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.background
                      : AppColors.textSecondary,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check, size: 16, color: AppColors.background),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _DayChoice extends StatelessWidget {
  const _DayChoice({
    required this.day,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final DateTime day;
  final bool selected, busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? AppColors.background : AppColors.textPrimary;
    return Semantics(
      selected: selected,
      button: true,
      label: '${day.month}월 ${day.day}일 ${weekdayLetter(day)}요일',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.textPrimary : Colors.transparent,
        borderRadius: AppRadius.pillBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 66,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdayLetter(day),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.background
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  style: runningNumberStyle(
                    22,
                    weight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !busy
                        ? Colors.transparent
                        : selected
                        ? AppColors.background
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
