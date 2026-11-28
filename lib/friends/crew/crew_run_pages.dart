import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:geolocator/geolocator.dart' show Geolocator, Position;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../../design_system/app_colors.dart';
import '../../design_system/inline_notice.dart';
import '../../home/running/running_home_page.dart'
    show
        GpsStatusChip,
        MapCircleButton,
        MapUserLocation,
        MapZoom,
        RunneryMap,
        RunneryMapController,
        RunningLocationState,
        RunningMode,
        RunningStartOptions,
        StatusChip,
        checkRunningLocation,
        runningLocationActive;
import '../../record/list/detail/record_detail_page.dart' show RecordRouteMap;
import '../../home/running/running_start_page.dart';
import '../../profile/setting/profile_setting.dart';
import '../../record/models/running_record.dart' show clockText;
import '../data/crew_store.dart';
import '../data/friend_store.dart';
import '../widgets/friend_widgets.dart';

/// 대기실 이름표 색 16가지(시안 17-12-1). 번호는 서버의 색 번호와 같습니다.
/// 두 화면 모드에서 같은 색을 씁니다(이름표는 사람을 구분하는 표시라서).
const crewRunColors = [
  Color(0xFFFF7A00), // 주황
  Color(0xFFFF9A52), // 살구
  Color(0xFFF5C400), // 노랑
  Color(0xFFDCCB2E), // 레몬
  Color(0xFFCFA86E), // 모래
  Color(0xFFB9822E), // 갈색
  Color(0xFF8E5B3B), // 밤색
  Color(0xFFC4573A), // 벽돌
  Color(0xFFA33456), // 와인
  Color(0xFFF27BB6), // 분홍
  Color(0xFFFF4F8B), // 핫핑크
  Color(0xFFFF9EC8), // 연분홍
  Color(0xFFA05CF0), // 보라
  Color(0xFFB994FF), // 라벤더
  Color(0xFF7342CF), // 진보라
  Color(0xFFD13FC2), // 자홍
];

/// 색 이름(시안 17-12-1). 화면 읽기 기능이 읽어 줍니다.
const crewRunColorNames = [
  '주황',
  '살구',
  '노랑',
  '레몬',
  '모래',
  '갈색',
  '밤색',
  '벽돌',
  '와인',
  '분홍',
  '핫핑크',
  '연분홍',
  '보라',
  '라벤더',
  '진보라',
  '자홍',
];

Color crewRunColor(int i) =>
    crewRunColors[i.clamp(0, crewRunColors.length - 1)];

/// 이름표 색 위에 올릴 글자 색(밝은 색이면 검정).
Color _onColor(Color c) =>
    c.computeLuminance() > .45 ? const Color(0xFF0B0B0B) : Colors.white;

/// 이름표 동그라미: 고른 색 바탕에 이름 첫 글자.
class CrewRunTag extends StatelessWidget {
  const CrewRunTag({
    super.key,
    required this.initial,
    required this.color,
    this.size = 40,
  });

  final String initial;
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = crewRunColor(color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * .4,
          fontWeight: FontWeight.w700,
          color: _onColor(c),
        ),
      ),
    );
  }
}

/// 17-9 함께 달리기 만들기(채팅방 위로 올라오는 창): 제목을 정하면 크루 채팅방에 모집 카드가 올라갑니다.
/// 만들면 모집 번호를 돌려주며 닫히고, 채팅방이 대기실을 엽니다.
Future<String?> showCrewRunTitleSheet(
  BuildContext context, {
  required String crewId,
  CrewStore? store,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.card,
  barrierColor: const Color(0xA8000000),
  shape: RoundedRectangleBorder(
    side: BorderSide(color: AppColors.borderDefault),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => _CrewRunTitleSheet(crewId: crewId, store: store),
);

class _CrewRunTitleSheet extends StatefulWidget {
  const _CrewRunTitleSheet({required this.crewId, this.store});

  final String crewId;
  final CrewStore? store;

  @override
  State<_CrewRunTitleSheet> createState() => _CrewRunTitleSheetState();
}

class _CrewRunTitleSheetState extends State<_CrewRunTitleSheet> {
  CrewStore get _store => widget.store ?? CrewStore.instance;
  final _title = TextEditingController();
  bool _sending = false;

  /// 열지 못한 이유. 만들기 버튼 바로 아래에 빨간 글씨로 보여 줍니다.
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_sending || _title.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final id = await _store.openRun(widget.crewId, _title.text);
      if (mounted) Navigator.pop(context, id);
    } on FriendException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              '함께 달리기 만들기',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: -0.44,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '제목을 정하면 크루 채팅방에 올라가고, 크루원들이 보고 참여해요.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                letterSpacing: -0.15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              '제목',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: CrewRun.maxTitle,
              buildCounter: (
                _, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _create(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.17,
              ),
              cursorColor: AppColors.textPrimary,
              decoration: InputDecoration(
                hintText: '제목을 입력해 주세요',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.textPrimary,
                    width: 2,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.textPrimary,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '20자까지 쓸 수 있어요',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  FriendIcon(
                    FriendIconKind.people,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '최대 ${CrewRun.maxRunners}명까지 함께 달릴 수 있어요',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        letterSpacing: -0.14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FriendSheetButton(
              label: _sending ? '만드는 중…' : '만들기',
              filled: true,
              height: 56,
              onPressed: _title.text.trim().isEmpty || _sending
                  ? null
                  : _create,
            ),
            InlineNotice(_error, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

/// 17-10 채팅방의 모집 카드: 제목, 연 사람·시각, 참여한 사람, 인원, 참여 버튼. 모집 문서를 지켜봅니다.
/// 출발하면 '러닝 진행 중'(버튼 없음), 팀 달리기가 끝나면 '기록 보기'를 보여 줍니다.
class CrewRunCard extends StatelessWidget {
  const CrewRunCard({
    super.key,
    required this.crewId,
    required this.runId,
    required this.title,
    required this.at,
    required this.store,
    required this.onJoin,
    required this.onOpen,
    this.onRecord,
    this.mine = false,
  });

  final String crewId, runId, title;
  final DateTime at;
  final CrewStore store;

  /// 참여 버튼(아직 참여하지 않았을 때).
  final ValueChanged<CrewRun> onJoin;

  /// 대기실로 가기(이미 참여했을 때).
  final ValueChanged<CrewRun> onOpen;

  /// 기록 보기(팀 달리기가 끝났을 때). 없으면 버튼을 숨깁니다.
  final ValueChanged<CrewRun>? onRecord;

  /// 내가 연 모집이면 true(오른쪽 말풍선 모양).
  final bool mine;

  @override
  Widget build(BuildContext context) => StreamBuilder<CrewRun?>(
    stream: store.watchRun(crewId, runId),
    builder: (context, snapshot) {
      final run = snapshot.data;
      final me = store.me?.uid ?? '';
      final joined = run != null && run.members.contains(me);
      // (상태 글자, 버튼, 상태 점이 주황인지)
      final (status, action, live) = switch (run) {
        null => ('불러오는 중', null, false),
        _ when run.status == CrewRunStatus.closed => ('모집이 닫혔어요', null, false),
        // 출발한 뒤에는 누구도 새로 들어갈 수 없어 버튼을 두지 않습니다.
        _ when run.isStarted => ('러닝 진행 중', null, true),
        _ when run.isEnded => (
          '함께 달렸어요',
          onRecord == null ? null : '기록 보기',
          false,
        ),
        _ when joined => ('모으는 중', '대기실로 가기', true),
        _ when run.isFull => ('자리가 다 찼어요', null, false),
        _ => ('모으는 중', '참여', true),
      };
      final running = run == null || !run.isStarted
          ? 0
          : run.stillRunning.length;
      final caption = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.45,
        letterSpacing: -0.06,
        color: AppColors.textTertiary,
      );
      // 17-10: 폭 260의 말풍선 카드(연 사람 쪽 모서리만 4).
      return Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.divider),
          borderRadius: mine
              ? const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                )
              : const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FriendIcon(
                  FriendIconKind.people,
                  size: 16,
                  color: AppColors.primaryText,
                ),
                const SizedBox(width: 6),
                Text(
                  '함께 달리기',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: -0.06,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: -0.36,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${run == null ? '' : '${store.nameOf(run.host)} 님이 열었어요 · '}${clockText(at)}',
              style: caption.copyWith(height: 1.4),
            ),
            if (run != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final (i, uid) in run.members.take(5).indexed)
                    Transform.translate(
                      offset: Offset(-8.0 * i, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: AppColors.card, spreadRadius: 2),
                          ],
                        ),
                        child: FriendAvatar(
                          initial: store.person(uid)?.initial ?? '·',
                          size: 28,
                        ),
                      ),
                    ),
                  SizedBox(width: 8 - 8.0 * (run.members.take(5).length - 1)),
                  Expanded(
                    child: Text(
                      '${run.members.length}/${CrewRun.maxRunners}명 참여',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: -0.13,
                      ),
                    ),
                  ),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: live ? AppColors.primary : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: live
                          ? AppColors.primaryText
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              if (running > 0) ...[
                const SizedBox(height: 10),
                Text('$running명이 함께 달리고 있어요', style: caption),
              ],
            ],
            if (run != null && action != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: run.isEnded
                    ? OutlinedButton(
                        onPressed: () => onRecord?.call(run),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.borderDefault),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.15,
                          ),
                        ),
                        child: Text(action),
                      )
                    : FilledButton(
                        onPressed: () => joined ? onOpen(run) : onJoin(run),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: const Color(0xFF0B0B0B),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.15,
                          ),
                        ),
                        child: Text(action),
                      ),
              ),
              if (!joined && run.isOpen) ...[
                const SizedBox(height: 10),
                Text(
                  '참여하면 대기실로 들어가요. ${store.nameOf(run.host)} 님이 러닝 시작을 누르면 다 같이 카운트다운해요.',
                  style: caption,
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
}

/// 17-9-1·17-12 크루 대기실. 팀장은 모두 준비되면 러닝 시작을 누르고, 팀원은 이름을 눌러 색을 고른 뒤
/// 준비 완료를 누릅니다. 준비 완료 뒤에는 '준비 취소'를 눌러야 나갈 수 있고, 팀장이 나가면 모집이 없어집니다.
class CrewLobbyPage extends StatefulWidget {
  const CrewLobbyPage({
    super.key,
    required this.crewId,
    required this.runId,
    required this.friends,
    this.store,
    this.checkLocation,
    this.startRun,
    this.pickColorOnOpen = false,
  });

  final String crewId, runId;
  final FriendStore friends;
  final CrewStore? store;

  /// 팀을 막 만들었거나 막 참여했으면 true. 대기실에 들어오자마자 색 고르는 화면을 띄웁니다
  /// (팀장은 '확인', 팀원은 '준비 완료'). 이미 들어가 있던 대기실을 다시 열 때는 false입니다.
  final bool pickColorOnOpen;

  /// 테스트에서만 넣습니다. 없으면 위치 권한을 확인하고 진짜 러닝 화면을 엽니다.
  final Future<bool> Function()? checkLocation;
  final Future<void> Function(BuildContext context, CrewRunLink link)? startRun;

  /// 러닝 시작을 누른 뒤 모두가 함께 세는 초.
  static const countdownSeconds = 3;

  /// [checkLocation]을 넣지 않았을 때 쓰는 위치 확인. 채팅방에서 연 대기실을 시험할 때만 바꿉니다.
  static Future<bool> Function() defaultCheckLocation = () async =>
      await checkRunningLocation() == RunningLocationState.ready;

  @override
  State<CrewLobbyPage> createState() => _CrewLobbyPageState();
}

class _CrewLobbyPageState extends State<CrewLobbyPage> {
  CrewStore get _store => widget.store ?? CrewStore.instance;

  StreamSubscription<CrewRun?>? _sub;
  CrewRun? _run;
  bool _busy = false, _leaving = false, _closedShown = false;
  bool _counting = false, _launched = false;
  bool? _locationOk;

  /// 들어오자마자 색 고르는 화면을 이미 띄웠으면 true(한 번만 띄웁니다).
  bool _autoPicked = false;

  /// 지도 바탕에 쓸 마지막 위치(위치 권한이 있을 때).
  Position? _position;
  final _map = RunneryMapController();

  /// 안 되면 누른 곳 가까이에 빨간 글씨로 알립니다.
  /// 자리: 'top' 뒤로 가기가 있는 제목 줄 아래, 'me' 내 이름 줄 아래, 'actions' 맨 아래 버튼 바로 위.
  final _notices = Notices();

  String get _me => _store.me?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _sub = _store
        .watchRun(widget.crewId, widget.runId)
        .listen(_onRun, onError: (Object _) {});
    unawaited(_checkLocation());
  }

  Future<void> _checkLocation() async {
    final check = widget.checkLocation ?? CrewLobbyPage.defaultCheckLocation;
    bool ok;
    try {
      ok = await check();
    } catch (_) {
      ok = false;
    }
    if (mounted) setState(() => _locationOk = ok);
    _autoPickColor();
    if (ok) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (mounted && last != null) setState(() => _position = last);
      } catch (_) {
        // 위치를 못 받으면 지도는 기본 자리에서 보여 줍니다.
      }
    }
  }

  /// [CrewLobbyPage.pickColorOnOpen]이면 모집 정보와 위치 권한을 확인한 뒤 색 고르는 화면을 한 번 띄웁니다.
  /// 위치 권한이 없으면 준비 완료를 할 수 없어 띄우지 않습니다(화면에 위치 안내가 보입니다).
  void _autoPickColor() {
    final run = _run;
    if (!widget.pickColorOnOpen || _autoPicked || !mounted) return;
    if (run == null || _locationOk == null) return;
    _autoPicked = true;
    if (_locationOk != true || !run.isOpen || !run.members.contains(_me)) {
      return;
    }
    if (run.host != _me && run.ready.contains(_me)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_counting) unawaited(_pickColor());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _notices.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onRun(CrewRun? run) {
    if (!mounted) return;
    // 모집이 닫히면 서버에서 지워져 null이 옵니다. 안내를 띄우는 동안 마지막 모습을 그대로 둡니다.
    setState(() => _run = run ?? _run);
    if (run != null) unawaited(_store.loadPeople(run.members));
    _autoPickColor();
    // 팀장이 러닝 시작을 누르면 대기실의 모두가 함께 셉니다.
    if (run != null &&
        run.isStarted &&
        run.members.contains(_me) &&
        !run.results.containsKey(_me) &&
        !_counting &&
        !_launched) {
      setState(() => _counting = true);
      return;
    }
    // 팀장이 나가 모집이 닫혔거나, 내가 빠졌으면 채팅방으로 돌아갑니다.
    final gone =
        run == null ||
        run.status == CrewRunStatus.closed ||
        !run.members.contains(_me);
    if (gone && !_leaving && !_closedShown && run?.host != _me) {
      _closedShown = true;
      unawaited(_showClosed());
    }
  }

  Future<void> _showClosed() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheet,
      showDragHandle: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '모집이 닫혔어요',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                '팀장이 대기실을 나가 이 모집이 없어졌어요. 채팅방으로 돌아갈게요.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 26),
              FriendSheetButton(
                label: '확인',
                filled: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  /// 카운트다운이 끝나면 러닝 화면을 엽니다. 달리기가 끝나면 결과 화면을 거쳐 처음 화면으로 돌아갑니다.
  Future<void> _launch() async {
    if (_launched) return;
    _launched = true;
    setState(() => _counting = false);
    final link = CrewRunLink(
      crewId: widget.crewId,
      runId: widget.runId,
      crewName: _store.byId(widget.crewId)?.name ?? '크루',
    );
    await (widget.startRun ?? _defaultStartRun)(context, link);
  }

  static Future<void> _defaultStartRun(
    BuildContext context,
    CrewRunLink link,
  ) async {
    final settings = ProfileSettings.instance;
    await settings.load();
    if (!context.mounted) return;
    runningLocationActive.value = true;
    try {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RunningStartPage(
            crewRun: link,
            options: RunningStartOptions(
              mode: RunningMode.free,
              voiceGuide: settings.voice,
              autoPause: settings.autoPause,
              calorieQuest: settings.calorieQuest,
              calorieQuestPeriod: settings.calorieQuestPeriod,
            ),
          ),
        ),
      );
    } finally {
      runningLocationActive.value = false;
    }
  }

  Future<void> _act(
    Future<void> Function() task, {
    String at = 'actions',
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    _notices.clear(at);
    try {
      await task();
    } on FriendException catch (e) {
      if (mounted) _notices.show(at, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 뒤로 가기: 준비 완료면 막고, 팀장이면 확인한 뒤 모집을 닫고 나갑니다.
  Future<void> _tryLeave() async {
    final run = _run;
    if (run == null || !run.isOpen || !run.members.contains(_me)) {
      Navigator.pop(context);
      return;
    }
    if (run.host != _me && run.ready.contains(_me)) {
      _notices.show('top', '준비 취소를 누른 뒤 나갈 수 있어요');
      return;
    }
    if (run.host == _me) {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: AppColors.sheet,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '대기실을 나갈까요?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  '팀장이 나가면 이 모집이 없어지고, 들어와 있던 사람들도 채팅방으로 돌아가요.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 26),
                FriendSheetButton(
                  label: '나가기',
                  filled: true,
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 10),
                FriendSheetButton(
                  label: '머무르기',
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        ),
      );
      if (ok != true || !mounted) return;
    }
    _leaving = true;
    try {
      await _store.leaveRun(run);
      if (mounted) Navigator.pop(context);
    } on FriendException catch (e) {
      _leaving = false;
      if (mounted) _notices.show('top', e.message);
    }
  }

  /// 17-12-1 색 고르기. 팀원은 '준비 완료'로 색을 정하며 준비하고, 팀장은 '확인'으로 색만 정합니다.
  /// [at]은 누른 곳('me' 내 이름 줄, 'actions' 맨 아래 준비 완료 버튼)입니다.
  Future<void> _pickColor({String at = 'actions'}) async {
    final run = _run;
    if (run == null || !run.isOpen) return;
    final host = run.host == _me;
    if (!host && run.ready.contains(_me)) {
      _notices.show(at, '준비 취소를 누른 뒤 색을 바꿀 수 있어요');
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      barrierColor: const Color(0xA8000000),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.borderDefault),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _ColorSheet(
        run: run,
        me: _me,
        store: _store,
        actionLabel: host ? '확인' : '준비 완료',
      ),
    );
    if (picked == null) return;
    await _act(() async {
      if (picked != run.colorOf(_me)) await _store.setRunColor(run, picked);
      if (!host) await _store.setRunReady(run, ready: true);
    }, at: at);
  }

  /// 지도 바탕(시안 17-9-1). 테스트처럼 지도를 끈 곳에서는 바탕색만 둡니다.
  Widget _mapBackground() {
    if (!RecordRouteMap.basemapEnabled) {
      return ColoredBox(color: AppColors.mapLand);
    }
    final p = _position;
    final point = p == null ? null : LatLng(p.latitude, p.longitude);
    return IgnorePointer(
      child: RunneryMap(
        controller: _map,
        initialCenter: point ?? const LatLng(37.5665, 126.9780),
        initialZoom: MapZoom.basic,
        interactive: false,
        userLocation: point == null
            ? null
            : MapUserLocation(point, p!.accuracy.clamp(8, 80)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    final voice = ProfileSettings.instance.voice;
    final locked =
        run != null && run.isOpen && run.host != _me && run.ready.contains(_me);
    return PopScope(
      // 직접 나가기를 처리합니다(준비 완료면 막고, 팀장이면 확인).
      // 함께 세는 동안(17-12-3)은 누구도 먼저 나가지 않게 막습니다.
      canPop:
          !_counting &&
          (run == null || !run.isOpen || !run.members.contains(_me)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_counting) unawaited(_tryLeave());
      },
      child: Scaffold(
        backgroundColor: AppColors.mapLand,
        body: Stack(
          children: [
            Positioned.fill(child: _mapBackground()),
            // 지도 위 글자가 잘 읽히도록 바탕색을 반쯤 덮습니다(카운트다운 화면과 같음).
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.background.withValues(alpha: 0.55),
              ),
            ),
            SafeArea(
              child: run == null
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _content(run, voice: voice, locked: locked),
            ),
          ],
        ),
      ),
    );
  }

  /// 17-9-1·17-12-2 대기실: 위쪽 나가기·음성·GPS, 가운데 '준비 완료 N/M' 고리, 제목·이름표, 아래 버튼.
  Widget _content(CrewRun run, {required bool voice, required bool locked}) {
    final host = run.host == _me;
    final ready = run.ready.contains(_me);
    final order = [run.host, ...run.members.where((m) => m != run.host)];
    final hostName = host ? '내가' : '${_store.nameOf(run.host)} 님이';
    final note = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: AppColors.textTertiary,
    );
    final ringSize = math.min(MediaQuery.sizeOf(context).width * 0.7, 272.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(
            children: [
              MapCircleButton(
                icon: Icons.arrow_back_ios_new,
                tooltip: locked ? '준비 취소를 누른 뒤 나갈 수 있어요' : '대기실 나가기',
                onPressed: () {
                  if (!_counting) unawaited(_tryLeave());
                },
              ),
              const SizedBox(width: 8),
              // 화면이 좁으면 칩을 통째로 줄입니다.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: StatusChip(
                    label: voice ? '음성 안내 켜짐' : '음성 안내 꺼짐',
                    icon: voice
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: GpsStatusChip(
                    locationState: _locationOk == false
                        ? RunningLocationState.denied
                        : RunningLocationState.ready,
                    position: _position,
                    compact: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        NoticeSlot(
          notices: _notices,
          id: 'top',
          textAlign: TextAlign.center,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            children: [
              Center(
                child: SizedBox.square(
                  dimension: ringSize,
                  child: _counting
                      // 17-12-3: 같은 고리 안에서 3·2·1을 세고, 끝나면 모두 함께 러닝을 시작합니다.
                      ? _LobbyCountdown(
                          seconds: CrewLobbyPage.countdownSeconds,
                          size: ringSize,
                          onFinished: _launch,
                        )
                      : CustomPaint(
                          painter: _LobbyRing(AppColors.divider),
                          child: Semantics(
                            label:
                                '${run.members.length}명 중 ${run.readyCount}명 준비 완료',
                            excludeSemantics: true,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${run.readyCount}',
                                        style: runningNumberStyle(
                                          ringSize * 0.47,
                                          weight: FontWeight.w600,
                                        ).copyWith(height: 0.8),
                                      ),
                                      TextSpan(
                                        text: '/${run.members.length}',
                                        style: runningNumberStyle(
                                          ringSize * 0.22,
                                          weight: FontWeight.w600,
                                          color: AppColors.textTertiary,
                                        ).copyWith(height: 0.8),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  '준비 완료',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1,
                                    letterSpacing: -0.15,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                run.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: -0.44,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$hostName 열었어요 · ${run.members.length}/${CrewRun.maxRunners}명',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1,
                  letterSpacing: -0.065,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final uid in order)
                    _MemberChip(
                      run: run,
                      uid: uid,
                      me: _me,
                      store: _store,
                      onTap: uid == _me && run.isOpen && !_busy
                          ? () => _pickColor(at: 'me')
                          : null,
                    ),
                ],
              ),
              NoticeSlot(
                notices: _notices,
                id: 'me',
                textAlign: TextAlign.center,
              ),
              if (run.isOpen && !(ready && !host)) ...[
                const SizedBox(height: 14),
                Text(
                  '내 이름을 눌러 색을 고를 수 있어요',
                  textAlign: TextAlign.center,
                  style: note,
                ),
              ],
              const SizedBox(height: 14),
              Text(
                host
                    ? (run.canStart
                          ? '${run.members.length}명 모두 준비됐어요. 러닝 시작을 누르면 다 같이 카운트돼요'
                          : '모두 준비하면 러닝 시작을 누를 수 있어요')
                    : '$hostName 러닝 시작을 누르면 다 같이 카운트가 시작돼요',
                textAlign: TextAlign.center,
                style: note,
              ),
              const SizedBox(height: 6),
              Text(
                '카운트가 끝나면 모두 함께 기록이 시작돼요',
                textAlign: TextAlign.center,
                style: note,
              ),
              if (_locationOk == false) ...[
                const SizedBox(height: 16),
                Text(
                  '위치 권한을 켜야 함께 출발할 수 있어요. 설정에서 위치를 허용해 주세요.',
                  textAlign: TextAlign.center,
                  style: note.copyWith(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
        NoticeSlot(
          notices: _notices,
          id: 'actions',
          textAlign: TextAlign.center,
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
        ),
        // 세는 동안에는 버튼을 숨깁니다(높이는 그대로 둬 화면이 흔들리지 않게).
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _counting
              ? const SizedBox(height: 56)
              : host
              ? FilledButton.icon(
                  onPressed: run.canStart && !_busy && _locationOk == true
                      ? () => _act(() => _store.startRun(run))
                      : null,
                  icon: const FriendIcon(
                    FriendIconKind.play,
                    size: 18,
                    color: Color(0xFF0B0B0B),
                  ),
                  label: const Text('러닝 시작'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF0B0B0B),
                    disabledBackgroundColor: AppColors.borderDefault,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.19,
                    ),
                  ),
                )
              : ready
              ? FriendSheetButton(
                  label: '준비 취소',
                  height: 56,
                  onPressed: _busy
                      ? null
                      : () => _act(() => _store.setRunReady(run, ready: false)),
                )
              : FriendSheetButton(
                  label: '준비 완료',
                  filled: true,
                  height: 56,
                  onPressed: _busy || _locationOk != true
                      ? null
                      : () => _pickColor(),
                ),
        ),
      ],
    );
  }
}

/// 17-12-3 함께 세기: 고리가 매 초 12시 방향부터 주황으로 한 바퀴 차고, 가운데 숫자가 3·2·1로 바뀝니다.
/// 건너뛸 수 없고, 다 세면 [onFinished]를 부릅니다.
class _LobbyCountdown extends StatefulWidget {
  const _LobbyCountdown({
    required this.seconds,
    required this.size,
    required this.onFinished,
  });

  final int seconds;
  final double size;
  final VoidCallback onFinished;

  @override
  State<_LobbyCountdown> createState() => _LobbyCountdownState();
}

class _LobbyCountdownState extends State<_LobbyCountdown>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.seconds),
  )..forward().whenComplete(_finish);
  bool _done = false;

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    HapticFeedback.mediumImpact();
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = _controller.value * widget.seconds;
      final number = (widget.seconds - t.floor()).clamp(1, widget.seconds);
      final progress = _controller.isCompleted ? 1.0 : t % 1;
      return Semantics(
        liveRegion: true,
        label: '$number',
        excludeSemantics: true,
        child: CustomPaint(
          painter: _LobbyRing(AppColors.divider, progress: progress),
          child: Center(
            child: Text(
              '$number',
              style: runningNumberStyle(
                widget.size * 0.8,
                weight: FontWeight.w600,
              ).copyWith(height: 0.8),
            ),
          ),
        ),
      );
    },
  );
}

/// 대기실 가운데 고리(두께 2, 구분선 색). [progress]가 있으면 그만큼 주황(두께 3)으로 채웁니다.
class _LobbyRing extends CustomPainter {
  _LobbyRing(this.color, {this.progress});

  final Color color;
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final p = progress;
    if (p == null || p <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      2 * math.pi * p,
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LobbyRing old) =>
      old.color != color || old.progress != progress;
}

/// 17-9-1 이름표: 고른 색 테두리의 둥근 칩(높이 32). 나는 '나 · 팀장'과 ⌄(눌러서 색 고르기),
/// 다른 사람은 준비하면 ✓가 붙습니다.
class _MemberChip extends StatelessWidget {
  const _MemberChip({
    required this.run,
    required this.uid,
    required this.me,
    required this.store,
    required this.onTap,
  });

  final CrewRun run;
  final String uid, me;
  final CrewStore store;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isMe = uid == me, isHost = uid == run.host;
    final ready = run.isReady(uid);
    final color = crewRunColor(run.colorOf(uid));
    final name = isMe ? (store.me?.name ?? '나') : store.nameOf(uid);
    final chip = Container(
      height: 32,
      padding: const EdgeInsets.fromLTRB(3, 0, 10, 0),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.78),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
              border: Border.all(color: color, width: 2),
            ),
            child: Text(
              store.person(uid)?.initial ?? (isMe ? '나' : '·'),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: -0.13,
            ),
          ),
          if (isMe || isHost) ...[
            const SizedBox(width: 4),
            Text(
              [if (isMe) '나', if (isHost) '팀장'].join(' · '),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1,
                color: AppColors.textTertiary,
              ),
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ] else if (ready && !isHost) ...[
            const SizedBox(width: 6),
            Icon(Icons.check_rounded, size: 14, color: AppColors.textPrimary),
          ],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label:
          '$name${isMe ? ', 나' : ''}${isHost ? ', 팀장' : ''}, '
          '${ready ? '준비 완료' : '준비 중'}${onTap != null ? ', 눌러서 색 고르기' : ''}',
      excludeSemantics: true,
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }
}

/// 17-12-1 색 고르기: 16가지 중 하나. 다른 사람이 고른 색은 그 사람 첫 글자가 있고 고를 수 없습니다.
class _ColorSheet extends StatefulWidget {
  const _ColorSheet({
    required this.run,
    required this.me,
    required this.store,
    required this.actionLabel,
  });

  final CrewRun run;
  final String me;
  final CrewStore store;
  final String actionLabel;

  @override
  State<_ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends State<_ColorSheet> {
  late int _color = widget.run.colorOf(widget.me);

  @override
  Widget build(BuildContext context) {
    final taken = {
      for (final MapEntry(:key, :value) in widget.run.colors.entries)
        if (key != widget.me && widget.run.members.contains(key)) value: key,
    };
    final mine = crewRunColor(_color);
    final host = widget.run.host == widget.me;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '내 색상',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      letterSpacing: -0.44,
                    ),
                  ),
                ),
                // 고르는 색이 내 이름표에 어떻게 보이는지 미리 보여 줍니다.
                Container(
                  height: 32,
                  padding: const EdgeInsets.fromLTRB(3, 0, 10, 0),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.78),
                    border: Border.all(color: mine),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.background,
                          border: Border.all(color: mine, width: 2),
                        ),
                        child: Text(
                          widget.store.me?.initial ?? '나',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.store.me?.name ?? '나',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          letterSpacing: -0.13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        host ? '나 · 팀장' : '나',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '함께 달리는 사람들에게 내 이름표가 이 색으로 보여요.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                letterSpacing: -0.15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < CrewRun.colorCount; i++)
                  _swatch(i, taken[i]),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '흐리게 보이는 색은 다른 사람이 골라서 고를 수 없어요',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.45,
                letterSpacing: -0.06,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 22),
            FriendSheetButton(
              label: widget.actionLabel,
              filled: true,
              height: 56,
              onPressed: () => Navigator.pop(context, _color),
            ),
          ],
        ),
      ),
    );
  }

  /// 색 하나(누르는 자리 56, 동그라미 40). 고른 색은 ✓, 다른 사람이 고른 색은 테두리와 흐린 바탕에 그 사람 첫 글자.
  Widget _swatch(int i, String? takenBy) {
    final c = crewRunColor(i);
    final selected = _color == i;
    final name = crewRunColorNames[i % crewRunColorNames.length];
    return Semantics(
      button: takenBy == null,
      selected: selected,
      label: takenBy == null
          ? '$name${selected ? ', 고름' : ''}'
          : '$name · ${widget.store.nameOf(takenBy)} 님이 골랐어요',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: takenBy == null ? () => setState(() => _color = i) : null,
        child: SizedBox.square(
          dimension: 56,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: takenBy == null ? c : c.withValues(alpha: 0.28),
                border: takenBy == null ? null : Border.all(color: c, width: 2),
              ),
              child: takenBy != null
                  ? Text(
                      widget.store.person(takenBy)?.initial ?? '·',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : selected
                  ? Icon(Icons.check_rounded, size: 20, color: _onColor(c))
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 결과 화면의 크루 팀 기록 안내. 팀장은 아직 달리는 사람이 있으면 '팀 끝내기'를 누를 수 있습니다.
class CrewTeamBanner extends StatefulWidget {
  const CrewTeamBanner({super.key, required this.link, this.store});

  final CrewRunLink link;
  final CrewStore? store;

  @override
  State<CrewTeamBanner> createState() => _CrewTeamBannerState();
}

class _CrewTeamBannerState extends State<CrewTeamBanner> {
  CrewRunLink get link => widget.link;
  CrewStore get _store => widget.store ?? CrewStore.instance;

  /// 팀을 끝내지 못한 이유. '팀 끝내기' 버튼이 있는 안내 칸 안 아래쪽에 빨간 글씨로 보여 줍니다.
  String? _error;

  Future<void> _end(BuildContext context, CrewRun run, int running) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.sheet,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '팀을 끝낼까요?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                '팀 기록은 지금까지의 기록으로 남아요. 아직 달리는 $running명은 각자 계속 달리고, 원할 때 끝낼 수 있어요.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 26),
              FriendSheetButton(
                label: '팀 끝내기',
                filled: true,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 10),
              FriendSheetButton(
                label: '취소',
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _error = null);
    try {
      await _store.endTeam(run.crewId, run.id);
    } on FriendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<CrewRun?>(
    stream: _store.watchRun(link.crewId, link.runId),
    builder: (context, snapshot) {
      final run = snapshot.data;
      if (run == null) return const SizedBox.shrink();
      final me = _store.me?.uid ?? '';
      final running = [
        for (final m in run.stillRunning)
          if (m != me) m,
      ];
      final host = run.host == me;
      final String text;
      Widget? action;
      if (run.isEnded) {
        text =
            '${link.crewName} 팀 기록이 끝났어요 · 함께 ${run.teamKm.toStringAsFixed(2)} km. '
            '크루방 서랍에서 볼 수 있어요';
      } else if (running.isEmpty) {
        text = '${link.crewName} 크루와 함께 달렸어요';
      } else if (host) {
        text = '팀원 ${running.length}명이 아직 달리고 있어요';
        action = FriendPillButton(
          label: '팀 끝내기',
          onPressed: () => _end(context, run, running.length),
        );
      } else {
        text = '${_store.nameOf(run.host)} 님이 팀을 끝내면 팀 기록이 정리돼요';
      }
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.sheet,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 8), action],
              ],
            ),
            if (action != null) InlineNotice(_error, textAlign: TextAlign.end),
          ],
        ),
      );
    },
  );
}

/// 크루로 함께 달리는 동안, 서버가 종료 투표를 열면 "팀을 종료할까요?"를 묻습니다.
/// 한 번 연 투표마다 한 번만 묻고, 이미 끝낸 사람에게는 묻지 않습니다.
class CrewVoteListener extends StatefulWidget {
  const CrewVoteListener({
    super.key,
    required this.link,
    required this.child,
    this.store,
  });

  final CrewRunLink link;
  final Widget child;
  final CrewStore? store;

  @override
  State<CrewVoteListener> createState() => _CrewVoteListenerState();
}

class _CrewVoteListenerState extends State<CrewVoteListener> {
  CrewStore get _store => widget.store ?? CrewStore.instance;

  StreamSubscription<CrewRun?>? _sub;

  /// 이미 물어본 투표(연 시각).
  DateTime? _asked;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _sub = _store
        .watchRun(widget.link.crewId, widget.link.runId)
        .listen(_onRun, onError: (Object _) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onRun(CrewRun? run) {
    final me = _store.me?.uid;
    final vote = run?.vote;
    if (!mounted || run == null || vote == null || me == null) return;
    if (!run.isStarted || run.results.containsKey(me) || vote.answered(me)) {
      return;
    }
    if (_open || _asked == vote.askedAt) return;
    _asked = vote.askedAt;
    unawaited(_ask(run));
  }

  Future<void> _ask(CrewRun run) async {
    _open = true;
    // 누른 답이 서버에 들어갈 때까지 창을 열어 두고, 안 되면 창 안에 이유를 보여 줍니다.
    await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.sheet,
      showDragHandle: true,
      // 글이 길어 작은 화면에서도 잘리지 않게 내용 높이만큼 엽니다.
      isScrollControlled: true,
      builder: (context) => _VoteSheet(
        onVote: (end) => _store.voteRun(run.crewId, run.id, end: end),
      ),
    );
    _open = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 종료 투표 창: '종료' 또는 '끝내지 않기'. 답이 들어가면 닫히고, 안 되면 버튼 바로 위에 이유를 보여 줍니다.
class _VoteSheet extends StatefulWidget {
  const _VoteSheet({required this.onVote});

  final Future<void> Function(bool end) onVote;

  @override
  State<_VoteSheet> createState() => _VoteSheetState();
}

class _VoteSheetState extends State<_VoteSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _vote(bool end) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onVote(end);
      if (mounted) Navigator.pop(context, end);
    } on FriendException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '팀을 종료할까요?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            '함께 달린 지 2시간이 넘었어요. 참가자 몇 명이 종료를 누르면 팀 기록이 지금까지의 기록으로 끝나요. '
            '30분 동안 아무도 끝내지 않기를 누르지 않아도 끝나요. 내 러닝은 계속돼요.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 26),
          InlineNotice(_error, padding: const EdgeInsets.only(bottom: 10)),
          FriendSheetButton(
            label: '종료',
            filled: true,
            onPressed: _busy ? null : () => _vote(true),
          ),
          const SizedBox(height: 10),
          FriendSheetButton(
            label: '끝내지 않기',
            onPressed: _busy ? null : () => _vote(false),
          ),
        ],
      ),
    ),
  );
}
