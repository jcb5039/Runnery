import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../account/account_store.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_text_styles.dart';
import '../home/home_page.dart';
import '../home/running/running_home_page.dart'
    show MapZoom, RouteWidth, RunneryMap, RunneryMapController;
import '../login/login.dart';
import '../record/data/running_record_store.dart';
import '../record/models/running_record.dart';
import '../record/list/record_list_page.dart';
import '../record/list/detail/record_detail_page.dart' show RecordRouteMap;
import 'edit/profile_edit_page.dart';
import 'setting/change_password_page.dart';
import 'setting/profile_setting.dart';

/// 로그인한 계정(AccountStore)과 저장된 러닝 기록(RunningRecordStore)을 보여주는 내 정보.
class ProfileMailPage extends StatefulWidget {
  const ProfileMailPage({
    super.key,
    this.onHome,
    this.onRecords,
    this.onEditProfile,
    this.onLogout,
    this.account,
    this.records,
    this.showNavigation = true,
  });

  /// 하단 탭을 이 화면이 직접 그릴지. 탭 묶음(MainTabs) 안에서는 false.
  final bool showNavigation;

  /// 기본값은 AccountStore.instance / RunningRecordStore.instance.
  final AccountStore? account;
  final RunningRecordStore? records;
  final VoidCallback? onHome;
  final VoidCallback? onRecords;
  final VoidCallback? onEditProfile;
  final VoidCallback? onLogout;
  @override
  State<ProfileMailPage> createState() => _ProfileMailPageState();
}

class _ProfileMailPageState extends State<ProfileMailPage> {
  final settings = ProfileSettings.instance;
  late final AccountStore _account = widget.account ?? AccountStore.instance;
  late final RunningRecordStore _store =
      widget.records ?? RunningRecordStore.instance;
  List<RunningRecord> _records = const [];

  @override
  void initState() {
    super.initState();
    _store.addListener(_reload);
    settings.load();
    // 프로필 수정에서 저장하면 이름·아이디·사진을 바로 다시 그립니다.
    _account.addListener(_onAccountChanged);
    _reload();
  }

  @override
  void dispose() {
    _store.removeListener(_reload);
    _account.removeListener(_onAccountChanged);
    super.dispose();
  }

  void _onAccountChanged() {
    if (mounted) setState(() {});
  }

  void _editProfile() {
    if (widget.onEditProfile != null) return widget.onEditProfile!();
    if (_account.current == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ProfileEditPage(store: _account)),
    );
  }

  void _changePassword() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ChangePasswordPage(store: _account)),
    );
  }

  Future<void> _reload() async {
    try {
      final loaded = await _store.load();
      if (mounted) setState(() => _records = loaded);
    } catch (_) {
      // 기록을 못 읽으면 누적 기록은 0으로 둡니다.
    }
  }

  /// 서버에 못 올린 기록을 올려 보는 동안 진행 표시를 띄우고, 그래도 못 올린 기록 수를 돌려줍니다.
  Future<int> _unsyncedWithSpinner() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
    try {
      return await _account.unsyncedRecordCount();
    } finally {
      navigator.pop();
    }
  }

  /// 실수로 눌러도 바로 로그아웃되지 않게 한 번 더 묻습니다.
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('로그아웃하면 다시 이메일로 로그인해야 해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // 서버에 아직 못 올린 러닝 기록이 있으면 먼저 올려 보고, 그래도 남으면 한 번 더 묻습니다.
    if (_store.syncActive) {
      final unsynced = await _unsyncedWithSpinner();
      if (!mounted) return;
      if (unsynced > 0) {
        final force = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('서버에 올리지 못한 기록이 있어요'),
            content: Text(
              '러닝 기록 $unsynced개를 서버에 올리지 못했어요. 지금 로그아웃하면 이 기록은 사라져요. 인터넷에 연결한 뒤에 로그아웃하는 걸 추천해요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('그래도 로그아웃'),
              ),
            ],
          ),
        );
        if (force != true || !mounted) return;
      }
    }
    await _account.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute(builder: (_) => LoginPageV2(store: _account)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    bottomNavigationBar: !widget.showNavigation
        ? null
        : Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    _tab('홈', Icons.home_outlined, false, () {
                      if (widget.onHome != null) {
                        widget.onHome!();
                      } else {
                        Navigator.of(context).pushReplacement<void, void>(
                          MaterialPageRoute(builder: (_) => const HomePageV2()),
                        );
                      }
                    }),
                    _tab('기록', Icons.format_align_left, false, () {
                      if (widget.onRecords != null) {
                        widget.onRecords!();
                      } else {
                        Navigator.of(context).pushReplacement<void, void>(
                          MaterialPageRoute(
                            builder: (_) => const RecordListPageV2(),
                          ),
                        );
                      }
                    }),
                    _tab('내 정보', Icons.person_outline, true, () {}),
                  ],
                ),
              ),
            ),
          ),
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '내 정보',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '설정',
                    icon: const Icon(Icons.tune, size: 20),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => ProfileSettingPage(
                          settings: settings,
                          onEditProfile: _editProfile,
                          onChangePassword: _changePassword,
                          onLogout: widget.onLogout ?? _logout,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderControl),
                      image: _account.photoFile == null
                          ? null
                          : DecorationImage(
                              image: FileImage(_account.photoFile!),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: _account.photoFile != null
                        ? null
                        : Text(
                            _account.current?.initial ?? '러',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _account.current?.name ?? '러너',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _account.current == null
                              ? ''
                              : '@${_account.current!.id}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _editProfile,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.borderDefault),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      '프로필 수정',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _heading(
                '나의 러닝 지도',
                _mainPlace == null ? null : '$_mainPlace 주변',
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 230,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _RunningRoutesMap(records: _records),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.background.withAlpha(0),
                              AppColors.background.withAlpha(0xEE),
                            ],
                            stops: [0.48, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '지금까지 달린 길',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  _value('$_routeCount', ' 개의 경로', size: 28),
                                ],
                              ),
                            ),
                            Text(
                              '겹쳐 달린 길일수록\n더 밝게 보여요',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _heading('누적 기록'),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _stat(
                        '총 거리',
                        _value(_totalKm.toStringAsFixed(1), ' km'),
                      ),
                    ),
                    VerticalDivider(width: 1, color: AppColors.divider),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: _stat(
                          '총 러닝',
                          _value('${_records.length}', ' 회'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.divider),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _stat(
                        '총 운동 시간',
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${_totalSeconds ~/ 3600}',
                                style: _numberStyle(30),
                              ),
                              TextSpan(
                                text: ' 시간 ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              TextSpan(
                                text: '${_totalSeconds ~/ 60 % 60}',
                                style: _numberStyle(30),
                              ),
                              TextSpan(
                                text: ' 분',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    VerticalDivider(width: 1, color: AppColors.divider),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: _stat(
                          '소모 햇반',
                          _value(_totalHetbahn.toStringAsFixed(1), ' 개'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _heading('신체 정보', '칼로리 계산에 사용돼요'),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _stat(
                        '체중',
                        _value(
                          _account.current?.weightKg.toStringAsFixed(1) ?? '-',
                          ' kg',
                          size: 24,
                        ),
                        compact: true,
                      ),
                    ),
                    VerticalDivider(width: 24, color: AppColors.divider),
                    Expanded(
                      child: _stat(
                        '나이',
                        _value(
                          '${_account.current?.age ?? '-'}',
                          ' 세',
                          size: 24,
                        ),
                        compact: true,
                      ),
                    ),
                    VerticalDivider(width: 24, color: AppColors.divider),
                    Expanded(
                      child: _stat(
                        '성별',
                        Text(
                          _account.current?.gender ?? '-',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onLogout ?? _logout,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.textSecondary,
                  ),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('로그아웃'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  int get _routeCount => _records.where((r) => r.route.length >= 2).length;

  /// 가장 자주 달린 장소. 장소 정보가 없으면 캡션을 숨깁니다.
  String? get _mainPlace {
    final counts = <String, int>{};
    for (final r in _records) {
      if (r.place == '위치 정보 없음' || r.place.isEmpty) continue;
      counts[r.place] = (counts[r.place] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  double get _totalKm =>
      _records.fold<double>(0, (sum, r) => sum + r.distanceKm);
  int get _totalSeconds =>
      _records.fold<int>(0, (sum, r) => sum + r.movingSeconds);
  double get _totalHetbahn =>
      _records.fold<double>(0, (sum, r) => sum + r.hetbahnCount);

  TextStyle _numberStyle(double size) => AppTextStyles.statValue.copyWith(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.15,
  );
  Widget _value(String value, String unit, {double size = 30}) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: value, style: _numberStyle(size)),
        TextSpan(
          text: unit,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
  Widget _stat(String label, Widget value, {bool compact = false}) => Padding(
    padding: EdgeInsets.symmetric(vertical: compact ? 0 : 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: value,
        ),
      ],
    ),
  );
  Widget _heading(String title, [String? caption]) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: AppColors.borderDefault)),
      if (caption != null) ...[
        const SizedBox(width: 12),
        Text(
          caption,
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    ],
  );
  Widget _tab(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) => Expanded(
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
            size: 23,
            color: selected ? AppColors.textPrimary : AppColors.textTertiary,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 저장된 모든 러닝 경로를 반투명하게 겹쳐 그립니다. 여러 번 달린 길일수록 밝아집니다.
class _RunningRoutesMap extends StatefulWidget {
  const _RunningRoutesMap({required this.records});
  final List<RunningRecord> records;

  @override
  State<_RunningRoutesMap> createState() => _RunningRoutesMapState();
}

class _RunningRoutesMapState extends State<_RunningRoutesMap> {
  final _controller = RunneryMapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 일시정지로 끊긴 구간은 따로 나눕니다.
  List<List<LatLng>> get _segments {
    final segments = <List<LatLng>>[];
    for (final r in widget.records) {
      if (r.route.length < 2) continue;
      for (var i = 0; i < r.route.length; i++) {
        if (i == 0 || r.route[i].startsSegment) segments.add([]);
        segments.last.add(LatLng(r.route[i].latitude, r.route[i].longitude));
      }
    }
    return segments.where((s) => s.length >= 2).toList();
  }

  /// 가장 최근 러닝 근처(15km 이내)의 경로만 화면에 맞춥니다.
  /// 멀리 떨어진 곳에서 한 번 달린 기록 때문에 지도가 너무 작아지지 않게 합니다.
  List<LatLng> _fitPoints(List<List<LatLng>> segments) {
    final anchor = segments.first.first;
    final cosLat = math.cos(anchor.latitude * math.pi / 180);
    bool near(LatLng p) {
      final dy = (p.latitude - anchor.latitude) * 111.0;
      final dx = (p.longitude - anchor.longitude) * 111.0 * cosLat;
      return dx * dx + dy * dy < 15 * 15;
    }

    return [
      for (final s in segments)
        if (near(s.first)) ...s,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final segments = _segments;
    if (segments.isEmpty) {
      return ColoredBox(
        color: AppColors.mapLand,
        child: Align(
          alignment: Alignment(0, -0.25),
          child: Text(
            '러닝을 기록하면\n달린 길이 이곳에 쌓여요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ),
      );
    }
    final fit = _fitPoints(segments);
    // 프로필 수정·설정 화면이 덮으면 지도 엔진을 내려 잔상이 남지 않게 합니다(RecordRouteMap과 같은 이유).
    final covered = !(ModalRoute.isCurrentOf(context) ?? true);
    if (!RecordRouteMap.basemapEnabled || covered) {
      return CustomPaint(painter: _RoutesPainter(segments, fit));
    }
    // 기록이 바뀌면 지도를 새로 만들어 다시 맞춥니다(fitPoints는 처음 한 번만 적용).
    return RunneryMap(
      key: ValueKey(widget.records.map((r) => r.id).join(',')),
      controller: _controller,
      initialCenter: fit.first,
      initialZoom: MapZoom.basic,
      interactive: false,
      routeWidth: RouteWidth.preview,
      routeOpacity: 0.45,
      route: segments,
      fitPoints: fit,
      // 아래쪽 글자 영역만큼 여백을 더 둡니다.
      fitPadding: const EdgeInsets.fromLTRB(28, 24, 28, 64),
    );
  }
}

/// 지도 엔진이 없는 위젯 테스트용 대체 그림.
class _RoutesPainter extends CustomPainter {
  const _RoutesPainter(this.segments, this.fit);
  final List<List<LatLng>> segments;
  final List<LatLng> fit;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.mapLand);
    final cosLat = math.cos(fit.first.latitude * math.pi / 180);
    Offset raw(LatLng p) => Offset(p.longitude * cosLat, -p.latitude);
    final pts = fit.map(raw).toList();
    final minX = pts.map((p) => p.dx).reduce(math.min);
    final maxX = pts.map((p) => p.dx).reduce(math.max);
    final minY = pts.map((p) => p.dy).reduce(math.min);
    final maxY = pts.map((p) => p.dy).reduce(math.max);
    final area = Rect.fromLTRB(28, 24, size.width - 28, size.height - 64);
    final scale = math.min(
      area.width / math.max(maxX - minX, 1e-9),
      area.height / math.max(maxY - minY, 1e-9),
    );
    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in segments) {
      final path = Path();
      for (var i = 0; i < s.length; i++) {
        final p = area.center + (raw(s[i]) - center) * scale;
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutesPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
