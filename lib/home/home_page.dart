import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account/account_store.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_motion.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_text_styles.dart';
import '../profile/profile_mail_page.dart';
import '../profile/setting/profile_setting.dart';
import '../record/data/running_record_store.dart';
import '../record/list/detail/record_detail_page.dart';
import '../record/list/record_list_page.dart';
import 'running/calorie_quest.dart';
import 'running/running_home_page.dart';

/// 저장된 러닝 기록(RunningRecordStore)을 읽는 홈. 기록 탭과 같은 데이터를 사용합니다.
/// 위에는 칼로리 퀘스트(설정의 일간·주간 주기 동안 누적), 가운데에는 최근 러닝 경로 지도가 있습니다.
class HomePageV2 extends StatefulWidget {
  const HomePageV2({
    super.key,
    this.onStartRun,
    this.onRecords,
    this.onProfile,
    this.store,
    this.settings,
    this.records,
    this.now,
    this.showNavigation = true,
  });

  /// 하단 탭을 이 화면이 직접 그릴지. 탭 묶음(MainTabs) 안에서는 false.
  final bool showNavigation;

  final VoidCallback? onStartRun;
  final VoidCallback? onRecords;
  final VoidCallback? onProfile;

  /// 기본값은 기록 탭과 같은 RunningRecordStore.instance.
  final RunningRecordStore? store;

  /// 칼로리 퀘스트 주기(일간·주간)를 읽을 설정. 기본값은 ProfileSettings.instance.
  final ProfileSettings? settings;

  /// 테스트용 고정 기록. 지정하면 저장소를 읽지 않습니다.
  final List<RunningRecord>? records;

  /// 테스트용 현재 시각.
  final DateTime Function()? now;

  @override
  State<HomePageV2> createState() => _HomePageV2State();
}

class _HomePageV2State extends State<HomePageV2> with WidgetsBindingObserver {
  late final RunningRecordStore _store =
      widget.store ?? RunningRecordStore.instance;
  late final ProfileSettings _settings =
      widget.settings ?? ProfileSettings.instance;
  List<RunningRecord> _records = const [];
  Object? _error;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_reload);
    _settings.addListener(_settingsChanged);
    _settings.load();
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_reload);
    _settings.removeListener(_settingsChanged);
    super.dispose();
  }

  void _settingsChanged() {
    if (mounted) setState(() {});
  }

  /// 날짜가 바뀐 뒤 앱으로 돌아와도 오늘 기준으로 다시 계산합니다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    try {
      final loaded = widget.records ?? await _store.load();
      if (mounted) {
        setState(() {
          _records = loaded;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// 이번 퀘스트 기간(오늘 0시 또는 이번 주 월요일 0시부터)에 태운 칼로리.
  /// 러닝 중 화면의 칼로리 퀘스트와 같은 방식으로 저장된 기록을 더합니다.
  double _questKcal(CalorieQuestPeriod period) {
    final since = period.start(_now);
    var sum = 0.0;
    for (final r in _records) {
      if (!r.startedAt.toLocal().isBefore(since)) sum += r.energyKcal;
    }
    return sum;
  }

  /// 가장 최근에 시작한 러닝 중 GPS 좌표가 있는 기록.
  RunningRecord? get _latestWithRoute {
    RunningRecord? latest;
    for (final r in _records) {
      if (r.route.isEmpty) continue;
      if (latest == null || r.startedAt.isAfter(latest.startedAt)) latest = r;
    }
    return latest;
  }

  void _open(String label) {
    final action = switch (label) {
      '러닝' => widget.onStartRun,
      '기록' => widget.onRecords,
      '내 정보' => widget.onProfile,
      _ => null,
    };
    if (action != null) {
      action();
    } else if (label == '내 정보') {
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => ProfileMailPage(onRecords: widget.onRecords),
        ),
      );
    } else if (label == '기록') {
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(builder: (_) => const RecordListPageV2()),
      );
    } else if (label == '러닝') {
      // 홈→러닝 시작: 애니메이션 없이 바로 전환.
      Navigator.of(context).push<void>(
        PageRouteBuilder(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => const RunningHomePage(),
          transitionsBuilder: (_, animation, _, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: AppMotion.pushSlideCurve,
                  ),
                ),
            child: child,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = _settings.calorieQuestPeriod;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (AppColors.isDark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: AppColors.background,
              ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: widget.showNavigation ? _navigation() : null,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _QuestSummary(
                      kcal: _questKcal(period),
                      period: period,
                      onProfile: () => _open('내 정보'),
                    ),
                    // 지도는 남은 높이를 사용해 버튼까지 한 화면에 표시합니다.
                    Expanded(
                      child: _RouteCard(
                        record: _latestWithRoute,
                        error: _error != null,
                        onTap: _error != null ? _reload : () => _open('기록'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(30),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _open('러닝'),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '러닝 시작',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.signal_cellular_alt,
                                          color: Colors.black,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            '바로 시작할 수 있어요',
                                            style: TextStyle(
                                              color: Colors.black.withValues(
                                                alpha: .85,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              CircleAvatar(
                                radius: 28,
                                // 주황 버튼 안 검정 원은 두 모드에서 같습니다.
                                backgroundColor: const Color(0xFF0B0B0B),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 28,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navigation() => Container(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            _NavItem(
              label: '홈',
              icon: Icons.home_outlined,
              selected: true,
              onTap: () {},
            ),
            _NavItem(
              label: '기록',
              icon: Icons.format_align_left,
              onTap: () => _open('기록'),
            ),
            _NavItem(
              label: '내 정보',
              icon: Icons.person_outline,
              onTap: () => _open('내 정보'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 홈 맨 위 칼로리 퀘스트: 다음 단계까지 남은 칼로리, 단계 이름, 단계 안 진행률.
/// 단계 목록과 계산은 러닝 중 화면과 같은 CalorieQuest를 씁니다.
class _QuestSummary extends StatelessWidget {
  const _QuestSummary({
    required this.kcal,
    required this.period,
    required this.onProfile,
  });

  final double kcal;
  final CalorieQuestPeriod period;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final stage = CalorieQuest.current(kcal, period: period);
    final progress = CalorieQuest.stageProgress(kcal, period: period);
    final allDone = stage == null;
    final number = allDone
        ? kcal.round()
        : CalorieQuest.remaining(kcal, period: period);
    final title = allDone
        ? (period == CalorieQuestPeriod.daily
              ? '오늘 퀘스트를 모두 달성했어요'
              : '이번 주 퀘스트를 모두 달성했어요')
        : '${period.stages.indexOf(stage) + 1}단계 · ${stage.item}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              // 주황 원 위 아이콘은 두 모드에서 같습니다.
              child: const Icon(Icons.bolt, size: 15, color: Colors.black),
            ),
            const SizedBox(width: 8),
            Text(
              allDone ? '오늘 태운 칼로리' : '다음 퀘스트까지',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 36,
              height: 36,
              child: OutlinedButton(
                onPressed: onProfile,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.borderControl),
                  shape: const CircleBorder(),
                ),
                child: Text(
                  AccountStore.instance.current?.initial ?? '러',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$number',
                  style: AppTextStyles.statHero.copyWith(
                    fontSize: 64,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: allDone ? ' kcal 태웠어요' : ' kcal 남았어요',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(progress * 100).floor()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: AppRadius.pillBorder,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: AppColors.primary,
            backgroundColor: AppColors.divider,
          ),
        ),
      ],
    );
  }
}

/// 최근 러닝 경로 지도. 위·아래 가장자리는 바탕색으로 흐려져 퀘스트·버튼과 이어집니다.
class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.record,
    required this.error,
    required this.onTap,
  });

  /// 가장 최근 러닝. null이면 표시할 GPS 경로가 없습니다.
  final RunningRecord? record;
  final bool error;
  final VoidCallback onTap;

  static const _unknownPlace = '위치 정보 없음';

  String _caption(RunningRecord r) {
    if (r.startPlace != _unknownPlace && r.endPlace != _unknownPlace) {
      return '${r.startPlace} → ${r.endPlace}';
    }
    return '${r.dateLabel} · ${r.distanceKm.toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    final r = record;
    final fade = AppColors.background;
    return Semantics(
      label: r == null ? '최근 러닝 경로 없음' : '최근 러닝 경로, ${_caption(r)}',
      button: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (r == null)
            ColoredBox(
              color: AppColors.background,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.route,
                        size: 28,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        error ? '기록을 불러오지 못했어요' : '아직 러닝 기록이 없어요',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        error ? '눌러서 다시 시도해요' : '첫 러닝을 시작해 보세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // 기록 상세와 같은 지도(베이스맵 + 경로)를 카드 전체에 채웁니다.
            ColoredBox(
              color: AppColors.mapLand,
              child: RecordRouteMap(record: r, borderRadius: 0, basemap: true),
            ),
          // 위·아래 가장자리 흐림. 지도 드래그를 막지 않도록 터치를 통과시킵니다.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .12, .78, 1],
                  colors: [
                    fade,
                    fade.withAlpha(0),
                    fade.withAlpha(0),
                    fade.withAlpha(0xEE),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          if (r != null)
            Positioned(
              top: 28,
              left: 14,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mapButtonBase.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.mapButtonBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.route, size: 14),
                      SizedBox(width: 6),
                      Text(
                        '최근 러닝 경로',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 카드 아무 곳이나 누르면 기록으로 갑니다.
          Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Row(
              children: [
                Expanded(
                  child: IgnorePointer(
                    child: Text(
                      r == null ? '' : _caption(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
                    minimumSize: const Size(48, 40),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('기록 보기', style: TextStyle(fontSize: 12)),
                      Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 2,
              width: 28,
              color: selected ? AppColors.textPrimary : Colors.transparent,
            ),
            const SizedBox(height: 8),
            Icon(
              icon,
              size: 22,
              color: selected ? AppColors.textPrimary : AppColors.textTertiary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
