import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_component_metrics.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_spacing.dart';
import 'running_start_page.dart';

// ═════════════════════════════════════════════════════
// 칼로리 퀘스트: 러닝 중 태운 칼로리를 간식 10단계로 보여 줍니다.
// 러닝을 시작할 때마다 1단계부터 다시 시작하고, 기록 파일에는 저장하지 않습니다.
// ═════════════════════════════════════════════════════

/// 퀘스트 한 단계.
class CalorieQuestStage {
  const CalorieQuestStage({
    required this.name,
    required this.item,
    required this.fullName,
    required this.detail,
    required this.kcal,
    required this.icon,
  });

  /// 목록 제목. 예: 바나나맛우유
  final String name;

  /// 러닝 카드 제목. 예: 바나나맛우유 1개
  final String item;

  /// 달성 창 제목. 예: 빙그레 바나나맛우유 1개
  final String fullName;

  /// 목록 설명. 예: 빙그레 · 1개 240 ml
  final String detail;

  /// 이 칼로리를 넘기면 달성입니다(러닝 시작부터 누적).
  final int kcal;
  final IconData icon;
}

abstract final class CalorieQuest {
  /// 칼로리는 제품 영양 표시를 바탕으로 한 대략적인 값입니다. 값 조정은 여기서만 합니다.
  static const stages = [
    CalorieQuestStage(
      name: '박카스 F',
      item: '박카스 F 1병',
      fullName: '동아제약 박카스 F 1병',
      detail: '동아제약 · 1병 120 ml',
      kcal: 50,
      icon: Icons.bolt_outlined,
    ),
    CalorieQuestStage(
      name: '코카콜라',
      item: '코카콜라 1캔',
      fullName: '코카콜라 오리지널 1캔',
      detail: '오리지널 · 1캔 250 ml',
      kcal: 108,
      icon: Icons.local_drink_outlined,
    ),
    CalorieQuestStage(
      name: '짱구',
      item: '짱구 1봉지',
      fullName: '삼양 짱구 1봉지',
      detail: '삼양 · 1봉지 30 g',
      kcal: 160,
      icon: Icons.cookie_outlined,
    ),
    CalorieQuestStage(
      name: '바나나맛우유',
      item: '바나나맛우유 1개',
      fullName: '빙그레 바나나맛우유 1개',
      detail: '빙그레 · 1개 240 ml',
      kcal: 208,
      icon: Icons.emoji_food_beverage_outlined,
    ),
    CalorieQuestStage(
      name: '빼빼로',
      item: '빼빼로 1갑',
      fullName: '롯데 빼빼로 1갑',
      detail: '롯데 · 오리지널 1갑 54 g',
      kcal: 270,
      icon: Icons.bakery_dining_outlined,
    ),
    CalorieQuestStage(
      name: '햇반',
      item: '햇반 1개',
      fullName: 'CJ 햇반 백미밥 1개',
      detail: 'CJ · 백미밥 1개 210 g',
      kcal: 315,
      icon: Icons.rice_bowl_outlined,
    ),
    CalorieQuestStage(
      name: '불고기버거',
      item: '불고기버거 1개',
      fullName: '롯데리아 불고기버거 1개',
      detail: '롯데리아 · 단품 1개',
      kcal: 476,
      icon: Icons.lunch_dining_outlined,
    ),
    CalorieQuestStage(
      name: '신라면',
      item: '신라면 1개',
      fullName: '농심 신라면 1개',
      detail: '농심 · 봉지면 1개 120 g',
      kcal: 500,
      icon: Icons.ramen_dining_outlined,
    ),
    CalorieQuestStage(
      name: '신라면 2개',
      item: '신라면 2개',
      fullName: '농심 신라면 2개',
      detail: '농심 · 봉지면 2개 240 g',
      kcal: 1000,
      icon: Icons.ramen_dining_outlined,
    ),
    CalorieQuestStage(
      name: '신라면 2개 + 바나나맛우유',
      item: '신라면 2개 + 바나나맛우유',
      fullName: '신라면 2개와 바나나맛우유',
      detail: '마지막 단계',
      kcal: 1208,
      icon: Icons.ramen_dining_outlined,
    ),
  ];

  /// 달성한 단계 수(0~10). 화면에 보이는 반올림한 칼로리로 판단해 숫자와 어긋나지 않게 합니다.
  static int completed(double kcal) {
    final shown = kcal.round();
    var count = 0;
    for (final stage in stages) {
      if (shown < stage.kcal) break;
      count++;
    }
    return count;
  }

  /// 진행 중인 단계. 모두 달성했으면 null.
  static CalorieQuestStage? current(double kcal) =>
      stages.elementAtOrNull(completed(kcal));

  /// 진행 중인 단계까지 남은 칼로리.
  static int remaining(double kcal) {
    final stage = current(kcal);
    return stage == null ? 0 : stage.kcal - kcal.round();
  }

  /// 진행 중인 단계 안에서의 진행률(0~1). 이전 단계 칼로리부터 셉니다.
  static double stageProgress(double kcal) {
    final done = completed(kcal);
    if (done >= stages.length) return 1;
    final from = done == 0 ? 0 : stages[done - 1].kcal;
    final to = stages[done].kcal;
    return ((kcal.round() - from) / (to - from)).clamp(0.0, 1.0);
  }

  /// 단계 번호(1부터)와 함께 쓴 이름. 예: 4단계 · 바나나맛우유
  static String numbered(CalorieQuestStage stage) =>
      '${stages.indexOf(stage) + 1}단계 · ${stage.name}';
}

/// 10칸 진행 막대. 달성한 칸은 채우고 진행 중인 칸은 진행률만큼 채웁니다.
class CalorieQuestBar extends StatelessWidget {
  const CalorieQuestBar({super.key, required this.kcal, this.height = 4});

  final double kcal;
  final double height;

  @override
  Widget build(BuildContext context) {
    final done = CalorieQuest.completed(kcal);
    final partial = CalorieQuest.stageProgress(kcal);
    return Row(
      children: [
        for (var i = 0; i < CalorieQuest.stages.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.pillBorder,
              child: LinearProgressIndicator(
                value: i < done ? 1 : (i == done ? partial : 0),
                minHeight: height,
                color: AppColors.primary,
                backgroundColor: AppColors.divider,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 단계 아이콘 원.
class CalorieQuestIcon extends StatelessWidget {
  const CalorieQuestIcon({
    super.key,
    required this.icon,
    this.size = 40,
    this.dimmed = false,
  });

  final IconData icon;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Icon(
        icon,
        size: size * 0.48,
        color: dimmed ? AppColors.textTertiary : AppColors.textPrimary,
      ),
    );
  }
}

/// 20 러닝 카드 안의 퀘스트 줄. 누르면 퀘스트 목록을 엽니다.
class CalorieQuestRow extends StatelessWidget {
  const CalorieQuestRow({super.key, required this.kcal, required this.onTap});

  final double kcal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = CalorieQuest.completed(kcal);
    final stage = CalorieQuest.current(kcal);
    final next = CalorieQuest.stages.elementAtOrNull(done + 1);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.thumbnailBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
        child: Column(
          children: [
            Row(
              children: [
                CalorieQuestIcon(
                  icon: (stage ?? CalorieQuest.stages.last).icon,
                  size: 36,
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage == null
                            ? '칼로리 퀘스트 · 완료'
                            : '칼로리 퀘스트 · ${done + 1}단계',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stage?.item ?? '10단계 모두 달성',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          next == null ? '전체 보기' : '다음 ${next.name}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (stage != null)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${CalorieQuest.remaining(kcal)} kcal',
                              style: const TextStyle(color: AppColors.primary),
                            ),
                            const TextSpan(text: ' 남음'),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            CalorieQuestBar(kcal: kcal),
          ],
        ),
      ),
    );
  }
}

/// 20-1 단계 달성 창. 러닝은 계속 기록되고, '계속 달리기'를 누르거나 잠시 뒤 저절로 닫힙니다.
class CalorieQuestAchievedSheet extends StatefulWidget {
  const CalorieQuestAchievedSheet({
    super.key,
    required this.stageIndex,
    required this.listenable,
    required this.calories,
    required this.elapsed,
  });

  /// 달성한 단계 번호(0부터).
  final int stageIndex;

  /// 칼로리·시간이 바뀔 때 다시 그립니다.
  final Listenable listenable;
  final double Function() calories;
  final Duration Function() elapsed;

  /// 이만큼 지나면 저절로 닫힙니다.
  static const autoClose = Duration(seconds: 6);

  @override
  State<CalorieQuestAchievedSheet> createState() =>
      _CalorieQuestAchievedSheetState();
}

class _CalorieQuestAchievedSheetState extends State<CalorieQuestAchievedSheet> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(CalorieQuestAchievedSheet.autoClose, () {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = CalorieQuest.stages[widget.stageIndex];
    final next = CalorieQuest.stages.elementAtOrNull(widget.stageIndex + 1);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: ListenableBuilder(
            listenable: widget.listenable,
            builder: (context, _) {
              final kcal = widget.calories();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: AppSpacing.space6),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CalorieQuestIcon(icon: stage.icon, size: 84),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.card,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 15,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Text(
                      '${widget.stageIndex + 1}단계 달성',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    '${stage.fullName}만큼\n태웠어요',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    '지금까지 ${RunningFormat.kcal(kcal)} kcal · '
                    '${_spokenDuration(widget.elapsed())}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space6),
                  CalorieQuestBar(kcal: kcal, height: 5),
                  const SizedBox(height: AppSpacing.space4),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.space4,
                    ),
                    child: next == null
                        ? const Text(
                            '10단계를 모두 달성했어요',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : Row(
                            children: [
                              CalorieQuestIcon(icon: next.icon, size: 36),
                              const SizedBox(width: AppSpacing.space3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '다음 ${widget.stageIndex + 2}단계',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${next.fullName} · ${next.kcal} kcal',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          '${(next.kcal - kcal.round()).clamp(0, next.kcal)}',
                                      style: runningNumberStyle(20),
                                    ),
                                    const TextSpan(text: ' kcal 남음'),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.space5),
                  SizedBox(
                    width: double.infinity,
                    height: AppComponentMetrics.runningCardButtonHeight,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.directions_run, size: 20),
                      label: const Text(
                        '계속 달리기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 32분 15초, 1시간 2분 3초
String _spokenDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return [if (h > 0) '$h시간', if (h > 0 || m > 0) '$m분', '$s초'].join(' ');
}

/// 20-2 칼로리 퀘스트 목록. 러닝 중에 열어도 숫자가 계속 바뀝니다.
class CalorieQuestPage extends StatelessWidget {
  const CalorieQuestPage({
    super.key,
    required this.listenable,
    required this.calories,
  });

  final Listenable listenable;
  final double Function() calories;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: '뒤로',
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '칼로리 퀘스트',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: listenable,
          builder: (context, _) {
            final kcal = calories();
            final done = CalorieQuest.completed(kcal);
            final total = CalorieQuest.stages.length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              children: [
                const Text(
                  '이번 러닝에서 태운 칼로리',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    UnitValue(
                      value: RunningFormat.kcal(kcal),
                      unit: 'kcal',
                      size: 48,
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          done >= total ? '모두 달성' : '${done + 1}단계 진행 중',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space1),
                        Text(
                          '$total단계 중 $done단계 달성',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space3),
                CalorieQuestBar(kcal: kcal, height: 5),
                const SizedBox(height: AppSpacing.space5),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.thumbnailBorder,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.outlined_flag,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: Text(
                          '퀘스트는 러닝을 시작할 때마다\n1단계부터 다시 시작해요.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space6),
                Row(
                  children: [
                    Text(
                      '$total단계',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    const Expanded(child: Divider(height: 1)),
                    const SizedBox(width: AppSpacing.space3),
                    const Text(
                      '칼로리가 오를 때마다 하나씩 달성',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space3),
                for (var i = 0; i < total; i++)
                  _QuestStageRow(
                    index: i,
                    kcal: kcal,
                    done: done,
                    last: i == total - 1,
                  ),
                const SizedBox(height: AppSpacing.space5),
                const Text(
                  '칼로리는 제품 영양 표시를 바탕으로 한 대략적인 값이에요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuestStageRow extends StatelessWidget {
  const _QuestStageRow({
    required this.index,
    required this.kcal,
    required this.done,
    required this.last,
  });

  final int index;
  final double kcal;
  final int done;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final stage = CalorieQuest.stages[index];
    final achieved = index < done;
    final current = index == done;
    final locked = index > done;

    final Widget marker;
    if (achieved) {
      marker = Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: AppColors.textPrimary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 17, color: Colors.black),
      );
    } else {
      marker = Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(
            color: current ? AppColors.primary : AppColors.borderDefault,
            width: current ? 1.5 : 1,
          ),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: current ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
      );
    }

    // 왼쪽 세로선: 달성한 구간은 주황, 그 뒤는 회색.
    final lineAbove = index == 0
        ? Colors.transparent
        : (index <= done ? AppColors.primary : AppColors.divider);
    final lineBelow = last
        ? Colors.transparent
        : (index < done ? AppColors.primary : AppColors.divider);

    return Container(
      decoration: current
          ? const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.thumbnailBorder,
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 30,
              child: Column(
                children: [
                  Expanded(child: Container(width: 1.5, color: lineAbove)),
                  marker,
                  Expanded(child: Container(width: 1.5, color: lineBelow)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    CalorieQuestIcon(icon: stage.icon, dimmed: locked),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CalorieQuest.numbered(stage),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: locked
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            stage.detail,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (current) ...[
                            const SizedBox(height: AppSpacing.space2),
                            ClipRRect(
                              borderRadius: AppRadius.pillBorder,
                              child: LinearProgressIndicator(
                                value: CalorieQuest.stageProgress(kcal),
                                minHeight: 3,
                                color: AppColors.primary,
                                backgroundColor: AppColors.divider,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${RunningFormat.kcal(kcal)} / ${stage.kcal} kcal',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _thousands(stage.kcal),
                                style: runningNumberStyle(
                                  17,
                                  color: locked
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const TextSpan(
                                text: ' kcal',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (achieved)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.textPrimary,
                              borderRadius: AppRadius.pillBorder,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 12, color: Colors.black),
                                SizedBox(width: 3),
                                Text(
                                  '달성',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (current)
                          Text(
                            '${CalorieQuest.remaining(kcal)} kcal 남음',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          )
                        else
                          const Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1,208
String _thousands(int n) => n >= 1000
    ? '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}'
    : '$n';
