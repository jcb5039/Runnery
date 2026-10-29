import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_component_metrics.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_spacing.dart';
import '../../home/running/running_home_page.dart';
import '../../home/running/running_start_page.dart';
import '../../profile/setting/profile_setting.dart';
import '../../record/models/running_record.dart' show clockText;
import '../data/friend_store.dart';
import '../data/together_store.dart';
import '../widgets/friend_widgets.dart';
import 'together_done_page.dart';

/// 함께 달리기 대기실. 들어와 있는 동안 '준비됐어요'를 알리고, 누구든 시작을 누르면
/// 대기실에 있는 모두의 폰에서 카운트다운 뒤 러닝이 함께 시작됩니다. 멈추고 끝내는 건 각자 합니다.
/// 늦게 들어온 사람은 '지금 합류'로 바로 시작합니다.
class TogetherLobbyPage extends StatefulWidget {
  const TogetherLobbyPage({
    super.key,
    required this.id,
    this.store,
    this.friends,
    this.checkLocation,
    this.startRun,
  });

  final String id;

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소·위치 확인·러닝 화면을 씁니다.
  final TogetherStore? store;
  final FriendStore? friends;
  final Future<bool> Function()? checkLocation;
  final Future<void> Function(BuildContext context, Together together)?
  startRun;

  /// 시작을 누른 뒤 모두가 함께 세는 초.
  static const countdownSeconds = 5;

  /// 대기실에 있다고 다시 알리는 간격.
  static const heartbeat = Duration(seconds: 20);

  @override
  State<TogetherLobbyPage> createState() => _TogetherLobbyPageState();
}

class _TogetherLobbyPageState extends State<TogetherLobbyPage> {
  TogetherStore get _store => widget.store ?? TogetherStore.instance;

  StreamSubscription<Together?>? _sub;
  Timer? _beat, _tick;
  Together? _together;
  bool _first = true, _launched = false, _starting = false;
  bool? _locationOk;
  int? _count;
  String? _error;

  @override
  void initState() {
    super.initState();
    _together = _store.byId(widget.id);
    _sub = _store
        .watch(widget.id)
        .listen(
          _onUpdate,
          onError: (Object _) {
            if (mounted) setState(() => _error = '대기실 정보를 받지 못했어요');
          },
        );
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _beat?.cancel();
    _tick?.cancel();
    if (!_launched && _locationOk == true) _leave();
    super.dispose();
  }

  void _leave() {
    unawaited(
      _store.setReady(widget.id, ready: false).catchError((Object _) {}),
    );
  }

  /// 위치 권한을 확인한 뒤 대기실에 들어왔다고 알립니다.
  Future<void> _prepare() async {
    final ok = await (widget.checkLocation ?? _defaultLocation)();
    if (!mounted) return;
    setState(() => _locationOk = ok);
    if (!ok) return;
    await _announce();
    _beat = Timer.periodic(TogetherLobbyPage.heartbeat, (_) => _announce());
  }

  static Future<bool> _defaultLocation() async =>
      await checkRunningLocation() == RunningLocationState.ready;

  Future<void> _announce() async {
    try {
      await _store.setReady(widget.id, ready: true);
    } on FriendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _onUpdate(Together? t) {
    if (!mounted) return;
    if (t == null) {
      showFriendMessage(context, '약속이 취소됐어요');
      Navigator.pop(context);
      return;
    }
    final before = _together?.startedAt;
    final first = _first;
    _first = false;
    _store.replace(t);
    setState(() {
      _together = t;
      _error = null;
    });
    // 대기실에 있는 동안 누군가 시작을 눌렀으면 함께 셉니다.
    final me = _store.me?.uid;
    if (!first &&
        before == null &&
        t.startedAt != null &&
        me != null &&
        t.statusOf(me) == TogetherStatus.accepted &&
        !t.results.containsKey(me) &&
        _locationOk == true) {
      _beginCountdown();
    }
  }

  void _beginCountdown() {
    if (_count != null || _launched) return;
    setState(() => _count = TogetherLobbyPage.countdownSeconds);
    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_count! <= 1) {
        timer.cancel();
        _launch();
      } else {
        setState(() => _count = _count! - 1);
      }
    });
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await _store.start(widget.id);
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _launch() async {
    final t = _together;
    if (t == null || _launched) return;
    _launched = true;
    _beat?.cancel();
    _leave();
    setState(() => _count = null);
    await (widget.startRun ?? _defaultStartRun)(context, t);
  }

  /// 목표 거리를 정한 러닝 화면을 엽니다. 달리기가 끝나면 결과 화면을 거쳐 처음 화면으로 돌아갑니다.
  static Future<void> _defaultStartRun(BuildContext context, Together t) async {
    final settings = ProfileSettings.instance;
    await settings.load();
    if (!context.mounted) return;
    runningLocationActive.value = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RunningStartPage(
            togetherId: t.id,
            options: RunningStartOptions(
              mode: RunningMode.distanceGoal,
              voiceGuide: settings.voice,
              autoPause: settings.autoPause,
              goalKm: t.goalKm.toDouble(),
            ),
          ),
        ),
      );
    } finally {
      runningLocationActive.value = false;
    }
  }

  Future<void> _cancel(Together t, bool host) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                host ? '약속을 취소할까요?' : '약속에서 빠질까요?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                host ? '함께하기로 한 친구들의 약속도 사라져요.' : '다른 친구들은 그대로 함께 달릴 수 있어요.',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 26),
              FriendSheetButton(
                label: host ? '약속 취소' : '빠지기',
                filled: true,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 10),
              FriendSheetButton(
                label: '돌아가기',
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      host
          ? await _store.cancel(t)
          : await _store.answer(t, TogetherStatus.declined);
      if (mounted) Navigator.pop(context);
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _together;
    final me = _store.me;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: friendAppBar(context, '함께 달리기 대기실'),
      body: t == null || me == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Text(
                      _error!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
            )
          : Stack(
              children: [
                _content(t, me),
                if (_count case final count?) _countdown(count),
              ],
            ),
    );
  }

  Widget _content(Together t, PublicProfile me) {
    final now = _store.now;
    final host = t.host == me.uid;
    final others = t.others(me.uid);
    final someoneReady = others.any(
      (m) => t.statusOf(m) == TogetherStatus.accepted && t.isReady(m, now),
    );
    final mine = t.results[me.uid];
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
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
                  '(${weekdayLetter(t.startsAt)}) ${clockText(t.startsAt)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '목표 ${t.goalKm} km · 시작을 누르면 대기실에 있는 모두가 함께 출발해요',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 26),
                FriendSectionHeader(
                  title: '함께하는 사람',
                  meta: '${t.members.length}명',
                ),
                const SizedBox(height: 6),
                for (final (i, uid) in [me.uid, ...others].indexed)
                  FriendRow(
                    person:
                        _store.person(uid) ??
                        PublicProfile(uid: uid, name: '친구', id: ''),
                    divider: i > 0,
                    trailing: _status(t, uid, now, isMe: uid == me.uid),
                  ),
                if (_locationOk == false) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '위치 권한을 허용해야 함께 달릴 수 있어요. 설정에서 위치 권한을 켜 주세요.',
                    style: TextStyle(fontSize: 13, color: AppColors.error),
                  ),
                ],
                if (_error case final error?) ...[
                  const SizedBox(height: 16),
                  Text(
                    error,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mine != null)
                  FriendSheetButton(
                    label: '함께 달린 기록 보기',
                    filled: true,
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => TogetherDonePage(
                          id: t.id,
                          friends: widget.friends ?? FriendStore.instance,
                          store: widget.store,
                        ),
                      ),
                    ),
                  )
                else if (t.startedAt != null) ...[
                  const Text(
                    '함께 달리기가 이미 시작됐어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StartButton(
                    label: '지금 합류',
                    onPressed: _locationOk == true && !_launched
                        ? _launch
                        : null,
                  ),
                ] else ...[
                  Text(
                    someoneReady
                        ? '누구든 시작을 누르면 ${TogetherLobbyPage.countdownSeconds}초 뒤에 함께 출발해요'
                        : '친구가 대기실에 들어오면 시작할 수 있어요',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StartButton(
                    label: _starting ? '시작하는 중이에요' : '함께 시작',
                    onPressed: someoneReady && _locationOk == true && !_starting
                        ? _start
                        : null,
                  ),
                ],
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => _cancel(t, host),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textTertiary,
                  ),
                  child: Text(host ? '약속 취소' : '약속에서 빠지기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _status(Together t, String uid, DateTime now, {required bool isMe}) {
    if (t.results[uid] case final r?) {
      return FriendChip(label: '완주 · ${r.distanceKm.toStringAsFixed(2)} km');
    }
    return switch (t.statusOf(uid)) {
      TogetherStatus.declined => const FriendChip(label: '빠졌어요', muted: true),
      TogetherStatus.pending => const FriendChip(label: '수락 전이에요', muted: true),
      TogetherStatus.accepted
          when isMe && _locationOk == true || t.isReady(uid, now) =>
        const FriendChip(label: '준비됐어요', filled: true, icon: Icons.check),
      TogetherStatus.accepted => const FriendChip(
        label: '대기실에 없어요',
        muted: true,
      ),
    };
  }

  Widget _countdown(int count) => Positioned.fill(
    child: ColoredBox(
      color: AppColors.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '함께 출발해요',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$count',
            style: runningNumberStyle(
              140,
              weight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 러닝 시작 버튼(주황).
class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(
        AppComponentMetrics.primaryButtonMediumHeight,
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.background,
      disabledBackgroundColor: AppColors.card,
      disabledForegroundColor: AppColors.borderControl,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
    ),
    child: Text(label),
  );
}
