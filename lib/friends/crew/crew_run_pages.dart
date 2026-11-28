import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../home/running/running_home_page.dart'
    show
        RunningCountdownView,
        RunningLocationState,
        RunningMode,
        RunningStartOptions,
        checkRunningLocation,
        runningLocationActive;
import '../../home/running/running_start_page.dart';
import '../../profile/setting/profile_setting.dart';
import '../../record/models/running_record.dart' show clockText;
import '../data/crew_store.dart';
import '../data/friend_store.dart';
import '../widgets/friend_widgets.dart';

/// 대기실 이름표 색 16가지(시안 17-12-1). 번호는 서버의 색 번호와 같습니다.
/// 두 화면 모드에서 같은 색을 씁니다(이름표는 사람을 구분하는 표시라서).
const crewRunColors = [
  Color(0xFFF2F2F2),
  Color(0xFFFF7A00),
  Color(0xFFFF9A52),
  Color(0xFFF5C400),
  Color(0xFFDCCB2E),
  Color(0xFF4CC38A),
  Color(0xFF2FA4FF),
  Color(0xFF8E5B3B),
  Color(0xFFC4573A),
  Color(0xFFA33456),
  Color(0xFFD13FC2),
  Color(0xFFFF4F8B),
  Color(0xFFFF9EC8),
  Color(0xFFA05CF0),
  Color(0xFFB994FF),
  Color(0xFF7342CF),
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

/// 17-9 함께 달리기 만들기: 제목을 정하면 크루 채팅방에 모집 카드가 올라가고 대기실로 갑니다.
class CrewRunTitlePage extends StatefulWidget {
  const CrewRunTitlePage({
    super.key,
    required this.crewId,
    required this.friends,
    this.store,
  });

  final String crewId;
  final FriendStore friends;
  final CrewStore? store;

  @override
  State<CrewRunTitlePage> createState() => _CrewRunTitlePageState();
}

class _CrewRunTitlePageState extends State<CrewRunTitlePage> {
  CrewStore get _store => widget.store ?? CrewStore.instance;
  final _title = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_sending || _title.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final id = await _store.openRun(widget.crewId, _title.text);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CrewLobbyPage(
            crewId: widget.crewId,
            runId: id,
            friends: widget.friends,
            store: widget.store,
          ),
        ),
      );
    } on FriendException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showFriendMessage(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: friendAppBar(context, '함께 달리기 만들기'),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Text(
            '제목을 정하면 크루 채팅방에 올라가고, 크루원들이 보고 참여해요.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '제목',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: CrewRun.maxTitle,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            cursorColor: AppColors.textPrimary,
            decoration: InputDecoration(
              hintText: '예: 물빛광장 5 km 같이 뛰어요',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              helperText: '20자까지 쓸 수 있어요',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.borderControl),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.groups_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '최대 ${CrewRun.maxRunners}명까지 함께 달릴 수 있어요',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FriendSheetButton(
            label: _sending ? '만드는 중…' : '만들기',
            filled: true,
            onPressed: _title.text.trim().isEmpty || _sending ? null : _create,
          ),
        ],
      ),
    ),
  );
}

/// 17-10 채팅방의 모집 카드: 제목, 연 사람·시각, 참여한 사람, 인원, 참여 버튼. 모집 문서를 지켜봅니다.
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
  });

  final String crewId, runId, title;
  final DateTime at;
  final CrewStore store;

  /// 참여 버튼(아직 참여하지 않았을 때).
  final ValueChanged<CrewRun> onJoin;

  /// 대기실로 가기(이미 참여했을 때).
  final ValueChanged<CrewRun> onOpen;

  @override
  Widget build(BuildContext context) => StreamBuilder<CrewRun?>(
    stream: store.watchRun(crewId, runId),
    builder: (context, snapshot) {
      final run = snapshot.data;
      final me = store.me?.uid ?? '';
      final joined = run != null && run.members.contains(me);
      final (status, action) = switch (run) {
        null => ('불러오는 중', null),
        _ when run.status == CrewRunStatus.closed => ('모집이 닫혔어요', null),
        _ when run.status == CrewRunStatus.started => ('출발했어요', null),
        _ when joined => ('모으는 중', '대기실로 가기'),
        _ when run.isFull => ('자리가 다 찼어요', null),
        _ => ('모으는 중', '참여'),
      };
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_run,
                  size: 16,
                  color: AppColors.primaryText,
                ),
                const SizedBox(width: 6),
                Text(
                  '함께 달리기',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${run == null ? '' : '${store.nameOf(run.host)} 님이 열었어요 · '}${clockText(at)}',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            if (run != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final (i, uid) in run.members.take(5).indexed)
                    Transform.translate(
                      offset: Offset(-6.0 * i, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                        child: CrewRunTag(
                          initial: store.person(uid)?.initial ?? '·',
                          color: run.colorOf(uid),
                          size: 26,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${run.members.length}/${CrewRun.maxRunners}명 참여',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FriendChip(label: status, muted: action == null),
                ],
              ),
            ],
            if (run != null && action != null) ...[
              const SizedBox(height: 14),
              FriendSheetButton(
                label: action,
                filled: true,
                height: 44,
                onPressed: () => joined ? onOpen(run) : onJoin(run),
              ),
              if (!joined) ...[
                const SizedBox(height: 10),
                Text(
                  '참여하면 대기실로 들어가요. ${store.nameOf(run.host)} 님이 러닝 시작을 누르면 다 같이 카운트다운해요.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textTertiary,
                  ),
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
  });

  final String crewId, runId;
  final FriendStore friends;
  final CrewStore? store;

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
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onRun(CrewRun? run) {
    if (!mounted) return;
    setState(() => _run = run);
    if (run != null) unawaited(_store.loadPeople(run.members));
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

  Future<void> _act(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
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
      showFriendMessage(context, '준비 취소를 누른 뒤 나갈 수 있어요');
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
      if (mounted) showFriendMessage(context, e.message);
    }
  }

  /// 17-12-1 색 고르기. 팀원은 '준비 완료'로 색을 정하며 준비하고, 팀장은 '확인'으로 색만 정합니다.
  Future<void> _pickColor() async {
    final run = _run;
    if (run == null || !run.isOpen) return;
    final host = run.host == _me;
    if (!host && run.ready.contains(_me)) {
      showFriendMessage(context, '준비 취소를 누른 뒤 색을 바꿀 수 있어요');
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.sheet,
      showDragHandle: true,
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    // 함께 세는 동안은 누구도 먼저 출발하거나 나가지 않게, 눌러 건너뛸 수 없는 카운트다운을 띄웁니다.
    if (_counting) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: RunningCountdownView(
            seconds: CrewLobbyPage.countdownSeconds,
            title: '함께 출발해요',
            subtitle: '같은 모집 사람들이 다 같이 시작해요',
            skippable: false,
            onFinished: _launch,
          ),
        ),
      );
    }
    final locked =
        run != null && run.isOpen && run.host != _me && run.ready.contains(_me);
    return PopScope(
      // 직접 나가기를 처리합니다(준비 완료면 막고, 팀장이면 확인).
      canPop: run == null || !run.isOpen || !run.members.contains(_me),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_tryLeave());
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: locked ? '준비 취소를 누른 뒤 나갈 수 있어요' : '대기실 나가기',
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: locked ? AppColors.textTertiary : null,
            ),
            onPressed: _tryLeave,
          ),
          title: const Text(
            '대기실',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          top: false,
          child: run == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _content(run),
        ),
      ),
    );
  }

  Widget _content(CrewRun run) {
    final host = run.host == _me;
    final ready = run.ready.contains(_me);
    final order = [run.host, ...run.members.where((m) => m != run.host)];
    final hostName = host ? '내가' : '${_store.nameOf(run.host)} 님이';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${run.readyCount}',
                        style: runningNumberStyle(64, weight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: ' /${run.members.length}',
                        style: runningNumberStyle(
                          28,
                          weight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Text(
                  '준비 완료',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                run.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$hostName 열었어요 · ${run.members.length}/${CrewRun.maxRunners}명',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              for (final (i, uid) in order.indexed)
                _MemberRow(
                  run: run,
                  uid: uid,
                  me: _me,
                  store: _store,
                  divider: i > 0,
                  onTap: uid == _me && run.isOpen && !_busy ? _pickColor : null,
                ),
              const SizedBox(height: 12),
              if (run.isOpen && !(ready && !host))
                Text(
                  '내 이름을 눌러 색을 고를 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              const SizedBox(height: 20),
              Text(
                host
                    ? (run.canStart
                          ? '${run.members.length}명 모두 준비됐어요. 러닝 시작을 누르면 다 같이 카운트돼요'
                          : '모두 준비하면 러닝 시작을 누를 수 있어요')
                    : '$hostName 러닝 시작을 누르면 다 같이 카운트가 시작돼요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '카운트가 끝나면 모두 함께 기록이 시작돼요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              if (_locationOk == false) ...[
                const SizedBox(height: 16),
                Text(
                  '위치 권한을 켜야 함께 출발할 수 있어요. 설정에서 위치를 허용해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: host
              ? FriendSheetButton(
                  label: '러닝 시작',
                  filled: true,
                  onPressed: run.canStart && !_busy && _locationOk == true
                      ? () => _act(() => _store.startRun(run))
                      : null,
                )
              : ready
              ? FriendSheetButton(
                  label: '준비 취소',
                  onPressed: _busy
                      ? null
                      : () => _act(() => _store.setRunReady(run, ready: false)),
                )
              : FriendSheetButton(
                  label: '준비 완료',
                  filled: true,
                  onPressed: _busy || _locationOk != true ? null : _pickColor,
                ),
        ),
      ],
    );
  }
}

/// 대기실의 한 사람: 이름표 색, 이름(나·팀장 표시), 준비 상태.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.run,
    required this.uid,
    required this.me,
    required this.store,
    required this.divider,
    required this.onTap,
  });

  final CrewRun run;
  final String uid, me;
  final CrewStore store;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isMe = uid == me, isHost = uid == run.host;
    final ready = run.isReady(uid);
    return Semantics(
      button: onTap != null,
      label:
          '${isMe ? '나' : store.nameOf(uid)}${isHost ? ', 팀장' : ''}, '
          '${ready ? '준비 완료' : '준비 중'}${onTap != null ? ', 눌러서 색 고르기' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: divider ? AppColors.divider : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            children: [
              CrewRunTag(
                initial: store.person(uid)?.initial ?? '·',
                color: run.colorOf(uid),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? '나' : store.nameOf(uid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 6),
                      const FriendChip(label: '팀장'),
                    ],
                    if (onTap != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.palette_outlined,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ],
                ),
              ),
              if (ready)
                const FriendChip(
                  label: '준비 완료',
                  filled: true,
                  icon: Icons.check,
                )
              else
                const FriendChip(label: '준비 중', muted: true),
            ],
          ),
        ),
      ),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CrewRunTag(
                  initial: widget.store.me?.initial ?? '나',
                  color: _color,
                  size: 44,
                ),
                const SizedBox(width: 12),
                const Text(
                  '내 색상',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '함께 달리는 사람들에게 내 이름표가 이 색으로 보여요.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var i = 0; i < CrewRun.colorCount; i++)
                  _swatch(i, taken[i]),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '이니셜이 있는 색은 다른 사람이 골랐어요',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 22),
            FriendSheetButton(
              label: widget.actionLabel,
              filled: true,
              onPressed: () => Navigator.pop(context, _color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(int i, String? takenBy) {
    final c = crewRunColor(i);
    final selected = _color == i;
    return Semantics(
      button: takenBy == null,
      selected: selected,
      label: takenBy == null
          ? '색 ${i + 1}${selected ? ', 고름' : ''}'
          : '색 ${i + 1}, ${widget.store.nameOf(takenBy)} 님이 고름',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: takenBy == null ? () => setState(() => _color = i) : null,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c,
            border: Border.all(
              color: selected ? AppColors.textPrimary : Colors.transparent,
              width: 3,
            ),
          ),
          child: takenBy != null
              ? Text(
                  widget.store.person(takenBy)?.initial ?? '·',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _onColor(c),
                  ),
                )
              : selected
              ? Icon(Icons.check, size: 16, color: _onColor(c))
              : null,
        ),
      ),
    );
  }
}

/// 결과 화면의 크루 팀 기록 안내. 팀장은 아직 달리는 사람이 있으면 '팀 끝내기'를 누를 수 있습니다.
class CrewTeamBanner extends StatelessWidget {
  const CrewTeamBanner({super.key, required this.link, this.store});

  final CrewRunLink link;
  final CrewStore? store;

  CrewStore get _store => store ?? CrewStore.instance;

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
    if (ok != true || !context.mounted) return;
    try {
      await _store.endTeam(run.crewId, run.id);
    } on FriendException catch (e) {
      if (context.mounted) showFriendMessage(context, e.message);
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
        child: Row(
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
    final end = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.sheet,
      showDragHandle: true,
      // 글이 길어 작은 화면에서도 잘리지 않게 내용 높이만큼 엽니다.
      isScrollControlled: true,
      builder: (context) => SafeArea(
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
              FriendSheetButton(
                label: '종료',
                filled: true,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 10),
              FriendSheetButton(
                label: '끝내지 않기',
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
    _open = false;
    if (end == null) return;
    try {
      await _store.voteRun(run.crewId, run.id, end: end);
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
