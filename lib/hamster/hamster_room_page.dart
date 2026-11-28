import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account/account_store.dart';
import '../design_system/app_colors.dart';
import '../design_system/inline_notice.dart';
import '../record/data/running_record_store.dart';
import 'hamster_level.dart';

/// 캐릭터 탭('룸메이트') 미리보기. 폰에서 어떻게 보이는지 보려고 시안 그림을 잘라
/// 그대로 보여 줍니다(맨 위 제목은 그림에서 지웠습니다). Lv은 그림에 들어 있어 바뀌지 않고, EXP 막대는
/// 그림 속 막대 위에 코드로 같은 모양을 덮어 그립니다. 'Lv. 1' 부분도 코드로 덮어 진짜 레벨을 보여 줍니다.
/// 레벨·경험치는 저장된 러닝 기록의 총 거리로 계산합니다([HamsterLevel]).
/// 닉네임 카드의 이름(처음은 '룸메이트')은 카드 오른쪽 바깥의 연필 버튼을 눌러 바꾸고, 서버 프로필에 저장합니다.
/// 이름은 처음 한 번만 무료로 바꿀 수 있어서, 한 번 바꾸면 연필 버튼이 사라집니다(나중에 상점의 닉네임 변경권으로). 진짜 화면은 배경·캐릭터 그림을 따로 받아 다시 만듭니다.
///
/// 햄스터는 시안에서 떼어 낸 그림을 배경 속 햄스터 자리에 겹쳐, 천천히 부풀었다 가라앉으며 숨 쉬게 합니다.
class HamsterRoomPage extends StatefulWidget {
  const HamsterRoomPage({super.key, this.records, this.account});

  /// 기본값은 RunningRecordStore.instance.
  final RunningRecordStore? records;

  /// 기본값은 AccountStore.instance.
  final AccountStore? account;

  @override
  State<HamsterRoomPage> createState() => _HamsterRoomPageState();
}

class _HamsterRoomPageState extends State<HamsterRoomPage>
    with SingleTickerProviderStateMixin {
  /// 시안 맨 위(제목 칸) 색. 상태 표시줄 뒤를 같은 색으로 채웁니다.
  static const _topColor = Color(0xFFFCF2EA);

  /// 닉네임 글자 색(시안의 검은 글자).
  static const _nameColor = Color(0xFF1E1E1E);

  /// 배경 그림(room_preview.png) 크기와, 그 안에서 햄스터 그림(hamster_preview.png)을 잘라 낸 자리.
  static const _roomSize = Size(816, 1450);
  static const _hamsterRect = Rect.fromLTWH(260, 655, 295, 330);

  /// 배경 그림 속 EXP 막대(바깥 둥근 칸) 자리. 코드로 그린 막대를 정확히 겹칩니다.
  static const _expRect = Rect.fromLTRB(36, 1368, 778, 1432);

  /// 배경 그림 속 'Lv. 1' 진한 칸 자리. 코드로 그린 레벨 칸을 겹칩니다.
  static const _lvRect = Rect.fromLTRB(272, 558, 383, 603);

  /// 닉네임 카드 안의 이름 자리('Lv' 칸 오른쪽부터 카드 안쪽 끝까지, 가운데 정렬).
  static const _nameRect = Rect.fromLTRB(388, 558, 548, 603);

  /// 연필 버튼: 카드 오른쪽(바깥 끝 558) 옆 정사각형 자리(바탕 없음). 한 변이 카드 높이(위 547 ~ 아래 613, 67px)와 같습니다.
  /// 칸 안 여백(12px)과 연필 그림 가장자리 여백이 있어서, 칸을 카드 끝보다 6px 안쪽에서 시작해야
  /// 연필이 카드와 약 8px 떨어져 보입니다.
  static const _pencilRect = Rect.fromLTWH(552, 547, 67, 67);

  /// 이름이나 연필을 누를 수 있는 자리. 손가락으로 누르기 쉽게 카드보다 위아래로 넓습니다.
  static const _nameTapRect = Rect.fromLTRB(386, 536, 640, 626);

  late final AccountStore _account = widget.account ?? AccountStore.instance;

  /// 아직 이름을 한 번도 바꾸지 않았는지. 한 번 바꾸면 연필 버튼을 숨깁니다.
  bool get _canRename =>
      _account.current != null && _account.current!.mateName == null;

  void _onAccountChanged() {
    if (mounted) setState(() {});
  }

  late final RunningRecordStore _records =
      widget.records ?? RunningRecordStore.instance;
  HamsterLevel _level = HamsterLevel.fromExp(0);

  @override
  void initState() {
    super.initState();
    // 러닝을 저장하거나 기록을 지우면 다시 계산합니다.
    _records.addListener(_reload);
    // 이름을 바꾸면 연필 버튼을 숨깁니다.
    _account.addListener(_onAccountChanged);
    _reload();
  }

  Future<void> _reload() async {
    try {
      final records = await _records.load();
      final km = records.fold<double>(0, (sum, r) => sum + r.distanceKm);
      if (mounted) setState(() => _level = HamsterLevel.fromKm(km));
    } catch (_) {
      // 기록을 못 읽으면 지금 레벨을 그대로 둡니다.
    }
  }

  /// 숨 한 번(들이쉬기 → 내쉬기 → 잠깐 멈춤)에 걸리는 시간.
  static const _breath = Duration(milliseconds: 3200);

  /// 숨 한 번 안에서 들이쉬기가 끝나는 지점과 내쉬기가 끝나는 지점(나머지는 멈춤).
  /// 실제 숨처럼 들이쉬기가 내쉬기보다 조금 빠릅니다.
  static const _inhaleEnd = 0.38, _exhaleEnd = 0.85;

  /// 지금 얼마나 들이쉬었는지(0 = 평소, 1 = 다 들이쉼). 들이쉬기·내쉬기 모두 천천히 시작해 천천히 끝납니다.
  static double _breathAmount(double t) {
    if (t < _inhaleEnd) return Curves.easeInOut.transform(t / _inhaleEnd);
    if (t < _exhaleEnd) {
      return 1 -
          Curves.easeInOut.transform(
            (t - _inhaleEnd) / (_exhaleEnd - _inhaleEnd),
          );
    }
    return 0;
  }

  /// 들이쉴 때 커지는 정도. 픽셀 한 칸(그림에서 약 9.5px) 만큼 키가 커지고 옆으로 조금 넓어집니다.
  /// 배경에 원래 햄스터가 있어서 줄어들지는 않고 커지기만 합니다(줄면 뒤의 햄스터가 비칩니다).
  /// [_breathSize]로 크기를 조절합니다(1 = 픽셀 한 칸, 사용자 요청으로 70%).
  static const _breathSize = 0.7;
  static const _inhaleScaleY = 1 + 9.5 / 300 * _breathSize;
  static const _inhaleScaleX = 1 + 4.75 / 280 * _breathSize;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _breath,
  )..repeat();

  /// 이름 바꾸기 창을 띄우고, 저장을 누르면 서버 프로필에 저장합니다.
  Future<void> _editName() async {
    final current =
        _account.current?.mateNameOrDefault ?? Account.defaultMateName;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _MateNameDialog(initial: current),
    );
    if (name == null || name == current || !mounted) return;
    // 안 되면 이름 바로 아래에 빨간 글씨로 알립니다(잘 되면 이름이 바뀌어 보임).
    _notices.clear('name');
    try {
      await _account.updateMateName(name);
    } on AuthException catch (e) {
      if (mounted) _notices.show('name', e.message);
    } catch (_) {
      if (mounted) _notices.show('name', '이름을 저장하지 못했어요. 다시 시도해주세요');
    }
  }

  @override
  void dispose() {
    _records.removeListener(_reload);
    _account.removeListener(_onAccountChanged);
    _clock.dispose();
    _notices.dispose();
    super.dispose();
  }

  /// 이름을 저장하지 못한 이유('name'). 그림 위에서도 읽히도록 바탕을 깔아 이름 바로 아래에 보여 줍니다.
  final _notices = Notices();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _topColor,
    child: SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, box) {
          // 배경을 BoxFit.cover·가운데 맞춤으로 그릴 때의 배율과 위치를 그대로 계산해 햄스터를 겹칩니다.
          final scale = [
            box.maxWidth / _roomSize.width,
            box.maxHeight / _roomSize.height,
          ].reduce((a, b) => a > b ? a : b);
          final dx = (box.maxWidth - _roomSize.width * scale) / 2;
          final dy = (box.maxHeight - _roomSize.height * scale) / 2;
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/hamster/room_preview.png',
                  fit: BoxFit.cover,
                  // 픽셀 그림이 뭉개지지 않게 가장 가까운 픽셀로 늘립니다.
                  filterQuality: FilterQuality.none,
                ),
              ),
              Positioned(
                left: dx + _hamsterRect.left * scale,
                top: dy + _hamsterRect.top * scale,
                width: _hamsterRect.width * scale,
                height: _hamsterRect.height * scale,
                child: AnimatedBuilder(
                  animation: _clock,
                  builder: (context, child) {
                    final a = _breathAmount(_clock.value);
                    return Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.diagonal3Values(
                        1 + (_inhaleScaleX - 1) * a,
                        1 + (_inhaleScaleY - 1) * a,
                        1,
                      ),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/hamster/hamster_preview.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
              Positioned(
                left: dx + _expRect.left * scale,
                top: dy + _expRect.top * scale,
                width: _expRect.width * scale,
                height: _expRect.height * scale,
                child: _ExpBar(level: _level, scale: scale),
              ),
              Positioned(
                left: dx + _lvRect.left * scale,
                top: dy + _lvRect.top * scale,
                width: _lvRect.width * scale,
                height: _lvRect.height * scale,
                child: _LevelChip(level: _level.level, scale: scale),
              ),
              Positioned(
                left: dx + _nameRect.left * scale,
                top: dy + _nameRect.top * scale,
                width: _nameRect.width * scale,
                height: _nameRect.height * scale,
                child: Center(
                  child: ListenableBuilder(
                    listenable: _account,
                    builder: (context, _) => FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _account.current?.mateNameOrDefault ??
                            Account.defaultMateName,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28 * scale,
                          fontWeight: FontWeight.w800,
                          color: _nameColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: dx,
                right: dx,
                top: dy + _nameRect.bottom * scale + 4,
                child: ListenableBuilder(
                  listenable: _notices,
                  builder: (context, _) => _notices.of('name') == null
                      ? const SizedBox.shrink()
                      : Center(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                            decoration: BoxDecoration(
                              color: AppColors.sheet,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: NoticeSlot(
                              notices: _notices,
                              id: 'name',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),
              ),
              if (_canRename) ...[
                Positioned(
                  left: dx + _pencilRect.left * scale,
                  top: dy + _pencilRect.top * scale,
                  width: _pencilRect.width * scale,
                  height: _pencilRect.height * scale,
                  child: Padding(
                    padding: EdgeInsets.all(12 * scale),
                    child: Image.asset(
                      'assets/hamster/pencil.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
                Positioned(
                  left: dx + _nameTapRect.left * scale,
                  top: dy + _nameTapRect.top * scale,
                  width: _nameTapRect.width * scale,
                  height: _nameTapRect.height * scale,
                  child: Semantics(
                    button: true,
                    label: '룸메이트 이름 바꾸기',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _editName,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

/// EXP 막대. 시안 막대와 같은 모양(흰 테두리의 연한 살구색 칸, 갈색 글자, 회색 길에 주황 채움)이고,
/// 치수는 배경 그림 픽셀 기준에 [scale]을 곱해 그림과 같은 크기로 그립니다.
class _ExpBar extends StatelessWidget {
  const _ExpBar({required this.level, required this.scale});

  final HamsterLevel level;
  final double scale;

  // 시안에서 잰 색.
  static const _fill = Color(0xFFFCE7D7);
  static const _border = Color(0xFFFFF6F0);
  static const _text = Color(0xFF774015);
  static const _track = Color(0xFFD3D8E1);
  static const _progress = Color(0xFFFFA301);

  @override
  Widget build(BuildContext context) {
    final ratio = level.ratio.clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(32 * scale),
        border: Border.all(color: _border, width: 3 * scale),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(29 * scale, 0, 28 * scale, 0),
        child: Row(
          children: [
            SizedBox(
              width: 200 * scale,
              child: Text(
                level.isMax ? 'EXP MAX' : 'EXP ${level.exp} / ${level.expMax}',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 22 * scale,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13 * scale),
                child: SizedBox(
                  height: 26 * scale,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: ColoredBox(color: _track)),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        heightFactor: 1,
                        child: const ColoredBox(color: _progress),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 'Lv. N' 칸. 1~5레벨은 회색입니다.
class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level, required this.scale});

  final int level;
  final double scale;

  static const _gray = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _gray,
      borderRadius: BorderRadius.circular(22 * scale),
    ),
    child: Center(
      child: Text(
        'Lv. $level',
        maxLines: 1,
        style: TextStyle(
          fontSize: 24 * scale,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
}

/// 닉네임 변경 창(시안 디자인: 크림색 바탕, 굵은 갈색 테두리, 오른쪽 위 닫기, 노란 '변경하기').
/// 입력은 가운데 정렬이고, [Account.mateNameMaxLength]글자가 차면 더 쳐도 입력되지 않습니다. 이모지도 입력되지 않습니다.
/// 변경하기를 누르면 입력한 이름(앞뒤 빈칸 제외)을, 취소·닫기는 null을 돌려줍니다.
class _MateNameDialog extends StatefulWidget {
  const _MateNameDialog({required this.initial});

  /// 지금 이름. 입력 칸은 비워 두고 안내 문구로 새 이름을 받습니다.
  final String initial;

  @override
  State<_MateNameDialog> createState() => _MateNameDialogState();
}

class _MateNameDialogState extends State<_MateNameDialog> {
  final _controller = TextEditingController();

  // 시안에서 잰 색.
  static const _background = Color(0xFFFCF2E3);
  static const _brown = Color(0xFF703403);
  static const _title = Color(0xFF4A2408);
  static const _field = Color(0xFFFFFBF5);
  static const _hint = Color(0xFFB5ACA5);
  static const _counter = Color(0xFFA89F98);
  static const _cancel = Color(0xFFFCE4C5);
  static const _confirm = Color(0xFFFCAF25);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24),
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _brown, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 36),
              const Expanded(
                child: Text(
                  '닉네임 변경',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _title,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: '닫기',
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _brown, width: 2),
                    ),
                    child: const Icon(Icons.close, size: 22, color: _brown),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            // 이모지는 쳐도 입력되지 않습니다.
            inputFormatters: [
              FilteringTextInputFormatter.deny(Account.emojiPattern),
            ],
            maxLength: Account.mateNameMaxLength,
            // 최대 글자 수가 차면 더 입력되지 않습니다(한글은 조합 중인 글자를 끝까지 완성할 수 있습니다).
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            cursorColor: _brown,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _title,
            ),
            decoration: InputDecoration(
              hintText: '새 닉네임을 입력하세요',
              hintStyle: const TextStyle(fontSize: 16, color: _hint),
              // 글자 수는 아래에 따로 그립니다.
              counterText: '',
              filled: true,
              fillColor: _field,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _brown, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _brown, width: 2.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, value, _) => Text(
              '${value.text.characters.length} / ${Account.mateNameMaxLength}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _counter,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _DialogButton(
                  label: '취소',
                  fill: _cancel,
                  textColor: _title,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, value, _) => _DialogButton(
                    label: '변경하기',
                    fill: _confirm,
                    textColor: Colors.white,
                    onPressed: value.text.trim().isEmpty ? null : _save,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 닉네임 변경 창의 둥근 버튼(갈색 테두리). [onPressed]가 없으면 흐리게 보이고 눌리지 않습니다.
class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.fill,
    required this.textColor,
    required this.onPressed,
  });

  final String label;
  final Color fill, textColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? 0.5 : 1,
    child: SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          disabledBackgroundColor: fill,
          foregroundColor: textColor,
          disabledForegroundColor: textColor,
          shape: StadiumBorder(
            side: const BorderSide(
              color: _MateNameDialogState._brown,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    ),
  );
}
