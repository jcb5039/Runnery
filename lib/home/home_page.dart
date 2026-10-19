import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../account/account_store.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_motion.dart';
import '../design_system/app_text_styles.dart';
import '../profile/profile_mail_page.dart';
import '../record/data/running_record_store.dart';
import '../record/list/detail/record_detail_page.dart';
import '../record/list/record_list_page.dart';
import 'running/running_home_page.dart';

/// 저장된 러닝 기록(RunningRecordStore)을 읽는 홈. 기록 탭과 같은 데이터를 사용합니다.
class HomePageV2 extends StatefulWidget {
  const HomePageV2({
    super.key,
    this.onStartRun,
    this.onRecords,
    this.onProfile,
    this.store,
    this.records,
    this.now,
    this.liveMap,
    this.showNavigation = true,
  });

  /// 하단 탭을 이 화면이 직접 그릴지. 탭 묶음(MainTabs) 안에서는 false.
  final bool showNavigation;

  /// 카드에 현재 GPS 위치 지도를 쓸지. 기본값은 records가 없을 때(실제 앱)만 true.
  final bool? liveMap;

  final VoidCallback? onStartRun;
  final VoidCallback? onRecords;
  final VoidCallback? onProfile;

  /// 기본값은 기록 탭과 같은 RunningRecordStore.instance.
  final RunningRecordStore? store;

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
  List<RunningRecord> _records = const [];
  Object? _error;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_reload);
    super.dispose();
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

  List<RunningRecord> get _today => [
    for (final r in _records)
      if (_sameDay(r.startedAt.toLocal(), _now)) r,
  ];

  /// 가장 최근에 시작한 러닝 중 GPS 좌표가 있는 기록.
  RunningRecord? get _latestWithRoute {
    RunningRecord? latest;
    for (final r in _records) {
      if (r.route.isEmpty) continue;
      if (latest == null || r.startedAt.isAfter(latest.startedAt)) latest = r;
    }
    return latest;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  static String _dateLabel(DateTime d) =>
      '${d.month}월 ${d.day}일 ${const ['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1]}요일';

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final distanceKm = today.fold<double>(0, (sum, r) => sum + r.distanceKm);
    final movingSeconds = today.fold<int>(0, (sum, r) => sum + r.movingSeconds);
    final kcal = today.fold<double>(0, (sum, r) => sum + r.energyKcal).round();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
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
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const CustomPaint(
                          size: Size(24, 24),
                          painter: _LogoPainter(),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          '러너리',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => _open('내 정보'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: AppColors.borderControl,
                              ),
                              shape: const CircleBorder(),
                            ),
                            child: Text(
                              AccountStore.instance.current?.initial ?? '러',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    // 글자를 크게 키운 좁은 화면에서도 제목과 날짜가 한 줄에 들어오도록 배율을 제한합니다.
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.1,
                      child: Row(
                        children: [
                          const Text(
                            '오늘의 러닝',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Divider(color: AppColors.borderDefault),
                          ),
                          const SizedBox(width: 12),
                          // '12월 31일 수요일'처럼 날짜가 길어도 넘치지 않게, 화면 폭의 40%를 넘으면 글자를 줄입니다.
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * .4,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _dateLabel(_now),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _RunSummary(
                      distanceKm: distanceKm,
                      movingSeconds: movingSeconds,
                      kcal: kcal,
                    ),
                    const SizedBox(height: 14),
                    // 지도는 남은 높이를 사용해 버튼까지 한 화면에 표시합니다.
                    Expanded(
                      child: _RouteCard(
                        record: _latestWithRoute,
                        error: _error != null,
                        liveMap: widget.liveMap ?? widget.records == null,
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
                              const CircleAvatar(
                                radius: 28,
                                backgroundColor: AppColors.background,
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
    decoration: const BoxDecoration(
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

class _RunSummary extends StatelessWidget {
  const _RunSummary({
    required this.distanceKm,
    required this.movingSeconds,
    required this.kcal,
  });
  final double distanceKm;
  final int movingSeconds;
  final int kcal;

  @override
  Widget build(BuildContext context) {
    final hours = movingSeconds ~/ 3600;
    final minutes = movingSeconds ~/ 60 % 60;
    final seconds = movingSeconds % 60;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(right: 18),
            child: FittedBox(
              alignment: Alignment.bottomLeft,
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: distanceKm.toStringAsFixed(2),
                      style: AppTextStyles.statHero.copyWith(
                        fontSize: 88,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -4,
                      ),
                    ),
                    const TextSpan(
                      text: ' km',
                      style: TextStyle(
                        fontSize: 20,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.only(left: 16),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '운동 시간',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                FittedBox(
                  child: _value([
                    if (hours > 0) ...[('$hours', '시간 ')],
                    ('$minutes', '분 '),
                    (seconds.toString().padLeft(2, '0'), '초'),
                  ]),
                ),
                const SizedBox(height: 8),
                const Text(
                  '소모 칼로리',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                FittedBox(child: _value([('$kcal', ' kcal')])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _value(List<(String, String)> parts) => Text.rich(
    TextSpan(
      style: AppTextStyles.statValue.copyWith(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w800,
      ),
      children: [
        for (final (number, unit) in parts) ...[
          TextSpan(text: number),
          TextSpan(
            text: unit,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    ),
  );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.record,
    required this.error,
    required this.onTap,
    required this.liveMap,
  });

  /// true면 배경에 현재 GPS 위치 지도를 보여줍니다.
  final bool liveMap;

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
    return Semantics(
      label: r == null ? '최근 러닝 경로 없음' : '최근 러닝 경로, ${_caption(r)}',
      button: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 기록 탭과 같은 RecordRouteMap(342×200 비율)을 가운데에 둡니다.
            if (liveMap)
              const _LiveLocationMap()
            else
              ColoredBox(
                color: r == null ? AppColors.mapLand : const Color(0xFF1E2633),
                child: r == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.route,
                                size: 28,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                error ? '기록을 불러오지 못했어요' : '아직 러닝 기록이 없어요',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                error ? '눌러서 다시 시도해요' : '첫 러닝을 시작해 보세요',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: AspectRatio(
                          aspectRatio: 342 / 200,
                          child: RecordRouteMap(record: r, borderRadius: 0),
                        ),
                      ),
              ),
            // 지도 드래그를 막지 않도록 장식 레이어는 터치를 통과시킵니다.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [.65, 1],
                    colors: [Colors.transparent, Color(0xEE0B0B0B)],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
            if (!liveMap)
              Positioned(
                top: 14,
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
                    ),
                    child: Row(
                      children: [
                        Icon(
                          liveMap ? Icons.my_location : Icons.route,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          liveMap ? '현재 위치' : '최근 러닝 경로',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 8,
              left: 16,
              right: 8,
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
                      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
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
            // 실시간 지도는 직접 움직일 수 있으므로 카드 전체 탭은 쓰지 않습니다.
            if (!liveMap)
              Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
          ],
        ),
      ),
    );
  }
}

/// 현재 GPS 위치를 가운데에 둔 지도.
class _LiveLocationMap extends StatefulWidget {
  const _LiveLocationMap();

  @override
  State<_LiveLocationMap> createState() => _LiveLocationMapState();
}

class _LiveLocationMapState extends State<_LiveLocationMap> {
  final _map = RunneryMapController();
  StreamSubscription<Position>? _sub;
  Position? _position;
  bool _denied = false;
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    runningLocationActive.addListener(_onRunningChanged);
    if (!runningLocationActive.value) _start();
  }

  @override
  void dispose() {
    runningLocationActive.removeListener(_onRunningChanged);
    _sub?.cancel();
    _map.dispose();
    super.dispose();
  }

  /// 러닝 중에는 위치를 받지 않습니다([runningLocationActive] 참고). 러닝이 끝나면 다시 받습니다.
  void _onRunningChanged() {
    if (runningLocationActive.value) {
      _sub?.cancel();
      _sub = null;
    } else if (_sub == null) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      final last = await Geolocator.getLastKnownPosition();
      // 권한을 확인하는 사이 러닝이 시작됐으면 위치 통로를 열지 않습니다.
      if (!mounted || runningLocationActive.value || _sub != null) return;
      if (last != null) setState(() => _position = last);
      _sub = Geolocator.getPositionStream(
        locationSettings: runningLocationSettings(),
      ).listen(_onPosition, onError: (_) {});
    } catch (_) {
      if (mounted) setState(() => _denied = true);
    }
  }

  void _onPosition(Position p) {
    final first = _position == null;
    setState(() => _position = p);
    if (!first && _follow) _map.follow(LatLng(p.latitude, p.longitude));
  }

  bool _locating = false;

  /// 현재 GPS 위치를 다시 읽어 마커와 카메라를 그 위치로 옮깁니다.
  Future<void> _recenter() async {
    if (_locating) return;
    _locating = true;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: runningLocationSettings(),
      );
      if (!mounted) return;
      _follow = true;
      setState(() => _position = p);
      await _map.moveTo(LatLng(p.latitude, p.longitude), zoom: MapZoom.basic);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('현재 위치를 가져오지 못했어요')));
      }
    } finally {
      _locating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _position;
    if (p == null) {
      return ColoredBox(
        color: AppColors.mapLand,
        child: Center(
          child: _denied
              ? const Text(
                  '위치 권한을 허용하면 내 주변 지도가 보여요',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                )
              : const Icon(
                  Icons.location_searching,
                  size: 24,
                  color: AppColors.textTertiary,
                ),
        ),
      );
    }
    final point = LatLng(p.latitude, p.longitude);
    return Stack(
      fit: StackFit.expand,
      children: [
        RunneryMap(
          controller: _map,
          initialCenter: point,
          initialZoom: MapZoom.basic,
          // 손으로 움직이면 내 위치 따라가기를 멈춥니다.
          onUserGesture: () => _follow = false,
          userLocation: MapUserLocation(point, p.accuracy.clamp(5, 60)),
        ),
        Positioned(
          top: 14,
          left: 14,
          child: Material(
            color: AppColors.mapButtonBase.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _recenter,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location, size: 14),
                    SizedBox(width: 6),
                    Text(
                      '현재 위치',
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
        ),
      ],
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
              color: selected ? Colors.white : Colors.transparent,
            ),
            const SizedBox(height: 8),
            Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : AppColors.textTertiary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? Colors.white : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(4, 19)
      ..lineTo(10, 16)
      ..lineTo(14, 8)
      ..lineTo(21, 5);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    for (final p in [const Offset(4, 19), const Offset(21, 5)]) {
      canvas.drawCircle(p, 3, Paint()..color = Colors.white);
      canvas.drawCircle(p, 1.3, Paint()..color = AppColors.background);
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => false;
}
