import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../account/account_store.dart';
import '../../design_system/app_colors.dart';

/// 15-1~15-5 프로필 수정. 바뀐 내용은 저장을 눌러야 계정(AccountStore)에 반영됩니다.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, this.store, this.picker});

  /// 기본값은 AccountStore.instance.
  final AccountStore? store;

  /// 테스트에서 사진 고르기를 바꿔 끼웁니다. 기본값은 기기 카메라·앨범.
  final Future<File?> Function(ImageSource source)? picker;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

/// 사진 변경 시트에서 고른 것.
enum _PhotoAction { camera, album, remove }

/// 나가기 확인 시트에서 고른 것.
enum _LeaveAction { save, keepEditing, discard }

class _ProfileEditPageState extends State<ProfileEditPage> {
  static const _genders = ['여성', '남성', '선택 안 함'];
  static const _minWeight = 20.0, _maxWeight = 300.0;

  /// 눈금자 1kg = 34px (0.2kg마다 눈금 하나).
  static const _pxPerKg = 34.0;
  static final _idPattern = RegExp(r'^[a-z0-9_]{4,16}$');

  late final AccountStore _store = widget.store ?? AccountStore.instance;
  late final Account _original = _store.current!;
  late final File? _originalPhoto = _store.photoFile;

  late final _name = TextEditingController(text: _original.name);

  /// 로그인에 쓰는 이메일이라 여기서는 보여 주기만 합니다.
  late final _email = TextEditingController(text: _original.email);
  late final _id = TextEditingController(text: _original.id);
  late final _age = TextEditingController(text: '${_original.age}');
  late String _gender = _original.gender;
  late double _weight = _original.weightKg;
  late final _ruler = ScrollController(
    initialScrollOffset: (_original.weightKg - _minWeight) * _pxPerKg,
  );

  /// 새로 고른 사진. 저장 전까지는 계정에 반영하지 않습니다.
  File? _newPhoto;
  bool _photoRemoved = false;
  bool _saving = false;

  /// 저장했거나 버리기로 해서 나가는 중. 나가기 확인을 다시 띄우지 않습니다.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _id, _age]) {
      c.addListener(() => setState(() {}));
    }
    _ruler.addListener(() {
      final kg = ((_minWeight + _ruler.offset / _pxPerKg) * 10).round() / 10;
      if (kg != _weight) setState(() => _weight = kg);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _id, _age]) {
      c.dispose();
    }
    _ruler.dispose();
    super.dispose();
  }

  // ── 검사 ──────────────────────────────────────────

  String? get _nameError => _name.text.trim().isEmpty ? '이름을 입력해 주세요' : null;

  bool get _idChanged => _id.text.trim() != _original.id;

  /// 원래 아이디는 가입 때 규칙이 달랐을 수 있어, 바꿨을 때만 검사합니다.
  String? get _idError => !_idChanged || _idPattern.hasMatch(_id.text.trim())
      ? null
      : '영문 소문자, 숫자, _ 로 4~16자를 입력해 주세요';

  int? get _ageValue => int.tryParse(_age.text.trim());

  String? get _ageError {
    final age = _ageValue;
    return age != null && age >= 1 && age <= 120 ? null : '나이를 숫자로 입력해 주세요';
  }

  bool get _valid =>
      _nameError == null && _idError == null && _ageError == null;

  // ── 바뀐 내용 ─────────────────────────────────────

  bool get _photoChanged => _newPhoto != null || _photoRemoved;

  /// 나가기 확인 시트에 보여 줄 (항목, 이전, 이후). 사진은 따로 그립니다.
  List<(String, String, String)> get _textChanges => [
    if (_name.text.trim() != _original.name)
      ('이름', _original.name, _name.text.trim()),
    if (_idChanged) ('아이디', '@${_original.id}', '@${_id.text.trim()}'),
    if (_ageValue != _original.age)
      ('나이', '${_original.age}세', '${_age.text.trim()}세'),
    if (_gender != _original.gender) ('성별', _original.gender, _gender),
    if (_weight != _original.weightKg)
      (
        '체중',
        '${_original.weightKg.toStringAsFixed(1)} kg',
        '${_weight.toStringAsFixed(1)} kg',
      ),
  ];

  bool get _dirty => _photoChanged || _textChanges.isNotEmpty;

  // ── 동작 ──────────────────────────────────────────

  Future<File?> _pick(ImageSource source) async {
    if (widget.picker != null) return widget.picker!(source);
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return file == null ? null : File(file.path);
  }

  Future<void> _changePhoto() async {
    final hasPhoto =
        _newPhoto != null || (_originalPhoto != null && !_photoRemoved);
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      backgroundColor: AppColors.sheet,
      showDragHandle: true,
      builder: (context) => _PhotoSheet(hasPhoto: hasPhoto),
    );
    if (action == null || !mounted) return;
    if (action == _PhotoAction.remove) {
      setState(() {
        _newPhoto = null;
        _photoRemoved = true;
      });
      return;
    }
    try {
      final file = await _pick(
        action == _PhotoAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
      if (file == null || !mounted) return;
      setState(() {
        _newPhoto = file;
        _photoRemoved = false;
      });
    } on PlatformException {
      if (!mounted) return;
      _message(
        action == _PhotoAction.camera
            ? '카메라를 열 수 없어요. 설정에서 카메라 접근을 허용해 주세요.'
            : '사진을 불러올 수 없어요. 설정에서 사진 접근을 허용해 주세요.',
      );
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// 저장에 성공하면 true.
  Future<bool> _save() async {
    if (!_valid || _saving) return false;
    setState(() => _saving = true);
    try {
      await _store.updateProfile(
        name: _name.text,
        id: _id.text,
        age: _ageValue!,
        gender: _gender,
        weightKg: _weight,
        newPhoto: _newPhoto,
        removePhoto: _photoRemoved,
      );
      return true;
    } on AuthException catch (e) {
      if (mounted) _message(e.message);
      return false;
    } catch (_) {
      if (mounted) _message('저장하지 못했어요. 다시 시도해 주세요.');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndClose() async {
    if (await _save()) _close();
  }

  /// 나가기 막음을 풀고 다음 프레임에 화면을 닫습니다.
  void _close() {
    if (!mounted) return;
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  /// 15-5 바뀐 내용을 보여 주고 저장할지 묻습니다. 저장 버튼과 뒤로 가기 모두 이 창을 띄웁니다.
  Future<void> _confirmLeave() async {
    final action = await showModalBottomSheet<_LeaveAction>(
      context: context,
      backgroundColor: AppColors.sheet,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _LeaveSheet(
        changes: _textChanges,
        photoBefore: _avatar(_originalPhoto, 28),
        photoAfter: _photoChanged ? _avatar(_currentPhoto, 28) : null,
        canSave: _valid,
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _LeaveAction.save:
        await _saveAndClose();
      case _LeaveAction.discard:
        _close();
      case _LeaveAction.keepEditing || null:
        break;
    }
  }

  Future<void> _typeWeight() async {
    final controller = TextEditingController(text: _weight.toStringAsFixed(1));
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    double? parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        void submit() {
          final value = parse(controller.text);
          if (value != null && value >= _minWeight && value <= _maxWeight) {
            Navigator.pop(context, value);
          }
        }

        return AlertDialog(
          title: const Text('체중 입력'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              suffixText: 'kg',
              helperText:
                  '${_minWeight.round()}~${_maxWeight.round()} kg 사이로 입력해 주세요',
            ),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(onPressed: submit, child: const Text('확인')),
          ],
        );
      },
    );
    // 다이얼로그가 닫히는 애니메이션이 끝난 뒤에 컨트롤러를 정리합니다.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (result == null || !mounted) return;
    final kg = (result * 10).round() / 10;
    _ruler.jumpTo(
      ((kg - _minWeight) * _pxPerKg).clamp(0, _ruler.position.maxScrollExtent),
    );
    setState(() => _weight = kg);
  }

  // ── 화면 ──────────────────────────────────────────

  File? get _currentPhoto =>
      _newPhoto ?? (_photoRemoved ? null : _originalPhoto);

  Widget _avatar(File? photo, double radius) {
    final initial = _name.text.trim().isEmpty
        ? _original.initial
        : String.fromCharCode(_name.text.trim().runes.first);
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderControl),
        image: photo == null
            ? null
            : DecorationImage(image: FileImage(photo), fit: BoxFit.cover),
      ),
      child: photo != null
          ? null
          : Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _dirty && _valid && !_saving;
    return PopScope(
      canPop: !_dirty || _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          leading: IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text(
            '프로필 수정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: canSave ? _confirmLeave : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.onInverse,
                disabledBackgroundColor: AppColors.surfacePressed,
                disabledForegroundColor: AppColors.textTertiary,
                shape: const StadiumBorder(),
              ),
              child: Text(
                _saving ? '저장 중…' : '저장',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Center(
                  child: Semantics(
                    button: true,
                    label: '프로필 사진 변경',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _changePhoto,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _avatar(_currentPhoto, 44),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.surfacePressed,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.background,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.photo_camera_outlined,
                                size: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: _changePhoto,
                    child: Text(
                      '사진 변경',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _Section('기본 정보'),
                _Field(
                  label: '이름',
                  controller: _name,
                  error: _nameError,
                  action: TextInputAction.done,
                ),
                _Field(
                  label: '이메일',
                  controller: _email,
                  enabled: false,
                  helper: '로그인에 쓰는 이메일은 바꿀 수 없어요',
                ),
                _Field(
                  label: '아이디',
                  controller: _id,
                  prefix: '@',
                  error: _idError,
                  success: _idChanged && _idError == null
                      ? '사용할 수 있는 형식이에요'
                      : null,
                  helper: '앱에서 보이는 이름 · 영문 소문자, 숫자, _, 4~16자',
                  action: TextInputAction.done,
                  formatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                ),
                const SizedBox(height: 8),
                const _Section('신체 정보', caption: '칼로리 계산에 사용돼요'),
                _Field(
                  label: '나이',
                  controller: _age,
                  suffix: '세',
                  error: _ageError,
                  keyboard: TextInputType.number,
                  action: TextInputAction.done,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                ),
                const _Label('성별'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final (i, g) in _genders.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          selected: _gender == g,
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () => setState(() => _gender = g),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const StadiumBorder(),
                                backgroundColor: _gender == g
                                    ? AppColors.surfacePressed
                                    : Colors.transparent,
                                foregroundColor: _gender == g
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                side: BorderSide(
                                  color: _gender == g
                                      ? AppColors.textPrimary
                                      : AppColors.borderDefault,
                                ),
                              ),
                              child: Text(
                                g,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _gender == g
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                const _Label('체중'),
                const SizedBox(height: 4),
                Center(
                  child: Semantics(
                    button: true,
                    hint: '눌러서 체중을 직접 입력',
                    child: InkWell(
                      onTap: _typeWeight,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _weight.toStringAsFixed(1),
                                style: TextStyle(
                                  fontFamily: 'Archivo',
                                  fontVariations: [FontVariation('wdth', 75)],
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: ' kg',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _WeightRuler(
                  controller: _ruler,
                  weight: _weight,
                  min: _minWeight,
                  max: _maxWeight,
                  pxPerKg: _pxPerKg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 조각 ──────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section(this.title, {this.caption});
  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: AppColors.divider, height: 1)),
        if (caption != null) ...[
          const SizedBox(width: 12),
          Text(
            caption!,
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
  );
}

/// 밑줄 입력칸. 오류는 빨간 밑줄과 문구, 확인은 체크 문구로 보여 줍니다.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.error,
    this.success,
    this.helper,
    this.prefix,
    this.suffix,
    this.keyboard,
    this.action,
    this.formatters,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? error, success, helper, prefix, suffix;
  final TextInputType? keyboard;
  final TextInputAction? action;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) {
    final line = error != null ? AppColors.error : AppColors.borderControl;
    final message = error ?? success ?? helper;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboard,
            textInputAction: action,
            inputFormatters: formatters,
            style: TextStyle(
              fontSize: 16,
              color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            cursorColor: AppColors.textPrimary,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixText: prefix,
              prefixStyle: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              suffixText: suffix,
              suffixStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: line),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: error != null
                      ? AppColors.error
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  if (error != null || success != null) ...[
                    Icon(
                      error != null ? Icons.error_outline : Icons.check,
                      size: 13,
                      color: error != null
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 11,
                        color: error != null
                            ? AppColors.error
                            : AppColors.textTertiary,
                      ),
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

/// 가로로 미는 체중 눈금자. 가운데 흰 선이 현재 체중입니다.
class _WeightRuler extends StatelessWidget {
  const _WeightRuler({
    required this.controller,
    required this.weight,
    required this.min,
    required this.max,
    required this.pxPerKg,
  });

  final ScrollController controller;
  final double weight, min, max, pxPerKg;

  void _step(double kg) => controller.jumpTo(
    (controller.offset + kg * pxPerKg).clamp(
      0,
      controller.position.maxScrollExtent,
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 58,
    child: LayoutBuilder(
      builder: (context, box) => Semantics(
        label: '체중',
        value: '${weight.toStringAsFixed(1)} 킬로그램',
        increasedValue: '${(weight + .1).toStringAsFixed(1)} 킬로그램',
        decreasedValue: '${(weight - .1).toStringAsFixed(1)} 킬로그램',
        onIncrease: () => _step(.1),
        onDecrease: () => _step(-.1),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: box.maxWidth / 2),
                child: CustomPaint(
                  size: Size((max - min) * pxPerKg, 58),
                  painter: _RulerPainter(min: min, max: max, pxPerKg: pxPerKg),
                ),
              ),
            ),
            IgnorePointer(
              child: Container(
                width: 2,
                height: 28,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter({
    required this.min,
    required this.max,
    required this.pxPerKg,
  });
  final double min, max, pxPerKg;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderControl
      ..strokeWidth = 1;
    // 0.2kg마다 눈금, 1kg마다 긴 눈금, 2kg마다 숫자.
    final ticks = ((max - min) * 5).round();
    for (var i = 0; i <= ticks; i++) {
      final x = i * pxPerKg / 5;
      canvas.drawLine(Offset(x, i % 5 == 0 ? 6 : 16), Offset(x, 24), paint);
      if (i % 10 == 0) {
        final label = TextPainter(
          text: TextSpan(
            text: (min + i / 5).round().toString(),
            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x - label.width / 2, 32));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.min != min || old.max != max || old.pxPerKg != pxPerKg;
}

/// 15-4 프로필 사진 시트.
class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({required this.hasPhoto});
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, _PhotoAction action) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: () => Navigator.pop(context, action),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '프로필 사진',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '내 정보 화면에 보여요.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            row(Icons.photo_camera_outlined, '사진 찍기', _PhotoAction.camera),
            row(Icons.photo_library_outlined, '앨범에서 선택', _PhotoAction.album),
            if (hasPhoto)
              row(Icons.delete_outline, '사진 삭제', _PhotoAction.remove),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.borderDefault),
                  shape: const StadiumBorder(),
                ),
                child: const Text('취소'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 15-5 바뀐 내용을 저장할지 묻는 시트.
class _LeaveSheet extends StatelessWidget {
  const _LeaveSheet({
    required this.changes,
    required this.photoBefore,
    required this.photoAfter,
    required this.canSave,
  });

  final List<(String, String, String)> changes;
  final Widget photoBefore;

  /// 사진이 바뀌었을 때만 있습니다.
  final Widget? photoAfter;

  /// 입력 오류가 있으면 저장 대신 계속 수정하도록 안내합니다.
  final bool canSave;

  @override
  Widget build(BuildContext context) {
    Widget arrow() => Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.chevron_right, size: 14, color: AppColors.textTertiary),
    );
    Widget change(String label, Widget before, Widget after) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(child: before),
                arrow(),
                Flexible(child: after),
              ],
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '바뀐 내용을 저장할까요?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              canSave ? '저장하지 않고 나가면 바뀐 내용이 사라져요.' : '입력 내용을 확인해야 저장할 수 있어요.',
              style: TextStyle(
                fontSize: 12,
                color: canSave ? AppColors.textSecondary : AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '바뀐 내용',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  if (photoAfter != null)
                    change('프로필 사진', photoBefore, photoAfter!),
                  for (final (label, before, after) in changes)
                    change(
                      label,
                      Text(
                        before,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        after,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: canSave
                    ? () => Navigator.pop(context, _LeaveAction.save)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.onInverse,
                  disabledBackgroundColor: AppColors.surfacePressed,
                  disabledForegroundColor: AppColors.textTertiary,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  '저장하고 나가기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.pop(context, _LeaveAction.keepEditing),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.borderDefault),
                  shape: const StadiumBorder(),
                ),
                child: const Text('계속 수정하기'),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, _LeaveAction.discard),
                child: Text(
                  '저장하지 않고 나가기',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textSecondary,
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
