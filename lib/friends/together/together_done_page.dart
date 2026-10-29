import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_spacing.dart';
import '../../home/running/running_start_page.dart' show runningNumberStyle;
import '../../record/data/running_record_store.dart';
import '../../record/models/running_record.dart'
    show clockText, durationWords, paceText;
import '../data/friend_store.dart';
import '../data/record_share.dart';
import '../data/together_store.dart';
import '../widgets/friend_widgets.dart';
import 'together_new_page.dart';

/// 17-6 함께 달린 기록: 함께 달린 거리·칼로리 합계와 각자 달린 기록(끝난 순서).
class TogetherDonePage extends StatefulWidget {
  const TogetherDonePage({
    super.key,
    required this.id,
    required this.friends,
    this.store,
    this.share,
  });

  final String id;
  final FriendStore friends;

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final TogetherStore? store;
  final RecordShare? share;

  @override
  State<TogetherDonePage> createState() => _TogetherDonePageState();
}

class _TogetherDonePageState extends State<TogetherDonePage> {
  TogetherStore get _store => widget.store ?? TogetherStore.instance;
  RecordShare get _share => widget.share ?? RecordShare.instance;

  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_store.refresh());
  }

  /// 내 기록을 친구 피드에 올립니다. 폰에 있는 기록을 찾아 씁니다.
  Future<void> _post(TogetherResult mine) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final record = await RunningRecordStore.instance.find(mine.recordId);
      if (record == null) {
        throw const FriendException('이 폰에서 기록을 찾지 못했어요');
      }
      await _share.share(record);
      if (mounted) showFriendMessage(context, '친구 피드에 올렸어요');
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _again(Together t) => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => TogetherNewPage(
        friends: widget.friends,
        preselected: t.others(_store.me?.uid ?? ''),
        store: widget.store,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) {
      final t = _store.byId(widget.id);
      final me = _store.me;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: friendAppBar(context, '함께 달린 기록'),
        body: t == null || me == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _body(t, me),
      );
    },
  );

  Widget _body(Together t, PublicProfile me) {
    final results = t.results.entries.toList()
      ..sort((a, b) => a.value.finishedAt.compareTo(b.value.finishedAt));
    final accepted = [
      for (final m in t.members)
        if (t.statusOf(m) == TogetherStatus.accepted) m,
    ];
    final missing = [
      for (final m in accepted)
        if (!t.results.containsKey(m)) m,
    ];
    final finished = results.where((e) => e.value.distanceKm >= t.goalKm);
    final mine = t.results[me.uid];
    final hetbahn = t.totalKcal / 315;
    final badge = finished.isEmpty
        ? null
        : finished.length == accepted.length
        ? (accepted.length == 2 ? '둘 다 목표 달성' : '모두 목표 달성')
        : '${finished.length}명 목표 달성';
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.space4,
          AppSpacing.screenHorizontal,
          AppSpacing.space6,
        ),
        children: [
          Text(
            '${t.startsAt.month}월 ${t.startsAt.day}일 '
            '(${weekdayLetter(t.startsAt)}) ${clockText(t.startsAt)} · 목표 ${t.goalKm} km',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            results.isEmpty
                ? '함께 달린 기록이 없어요'
                : '${_store.names(t)} 님과 함께\n${t.goalKm} km를 달렸어요',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FriendChip(label: badge, filled: true, icon: Icons.check),
            ),
          ],
          if (results.isNotEmpty) ...[
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: _total('함께 달린 거리', t.totalKm.toStringAsFixed(2), 'km'),
                ),
                const SizedBox(width: 16),
                Expanded(child: _total('함께 태운 칼로리', '${t.totalKcal}', 'kcal')),
              ],
            ),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                text: '햇반 약 ',
                children: [
                  TextSpan(
                    text: '${hetbahn.toStringAsFixed(1)}개',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                  const TextSpan(
                    text: '  1개 = 315 kcal · 함께 합친 칼로리',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 30),
          const FriendSectionHeader(title: '각자 달린 기록', meta: '끝난 순서'),
          const SizedBox(height: 6),
          for (final (i, MapEntry(key: uid, value: r)) in results.indexed)
            _PersonResult(
              person:
                  _store.person(uid) ??
                  PublicProfile(uid: uid, name: '친구', id: ''),
              result: r,
              goalKm: t.goalKm,
              me: uid == me.uid,
              divider: i > 0,
            ),
          for (final (i, uid) in missing.indexed)
            FriendRow(
              person:
                  _store.person(uid) ??
                  PublicProfile(uid: uid, name: '친구', id: ''),
              divider: results.isNotEmpty || i > 0,
              trailing: const FriendChip(label: '기록이 없어요', muted: true),
            ),
          const SizedBox(height: 28),
          if (mine != null) ...[
            FriendSheetButton(
              label: _sharing ? '올리는 중이에요' : '친구 피드에 올리기',
              filled: true,
              onPressed: () => _post(mine),
            ),
            const SizedBox(height: 10),
          ],
          FriendSheetButton(label: '다시 약속 잡기', onPressed: () => _again(t)),
        ],
      ),
    );
  }

  Widget _total(String label, String value, String unit) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 10),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: runningNumberStyle(40, weight: FontWeight.w600)),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// 한 사람의 결과: 이름, 도착 시각, 완주 표시, 거리·시간·페이스·칼로리.
class _PersonResult extends StatelessWidget {
  const _PersonResult({
    required this.person,
    required this.result,
    required this.goalKm,
    required this.me,
    required this.divider,
  });

  final PublicProfile person;
  final TogetherResult result;
  final int goalKm;
  final bool me, divider;

  @override
  Widget build(BuildContext context) {
    final pace = result.paceSeconds;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: divider ? AppColors.divider : Colors.transparent,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FriendAvatar(
                initial: person.initial,
                borderColor: me ? AppColors.primary : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (me) ...[
                          const SizedBox(width: 6),
                          const FriendChip(label: '나'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${clockText(result.finishedAt)} 도착',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (result.distanceKm >= goalKm)
                const FriendChip(label: '완주', filled: true, icon: Icons.check),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _cell('거리', result.distanceKm.toStringAsFixed(2), 'km'),
              _cell('시간', durationWords(result.movingSeconds), ''),
              _cell('페이스', pace == null ? '—' : paceText(pace), ''),
              _cell('칼로리', '${result.kcal}', 'kcal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value, String unit) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: value,
              children: [
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
