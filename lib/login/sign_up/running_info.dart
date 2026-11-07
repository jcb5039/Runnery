import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/app_colors.dart';
import '../auth_ui/auth_ui.dart';

class RunningInfoPage extends StatefulWidget {
  const RunningInfoPage({
    super.key,
    this.name = '',
    this.email = '',
    this.id = '',
    this.password = '',
  });
  final String name, email, id, password;
  @override
  State<RunningInfoPage> createState() => _RunningInfoPageState();
}

class _RunningInfoPageState extends State<RunningInfoPage> {
  final form = GlobalKey<FormState>();
  final age = TextEditingController();
  final ruler = ScrollController(initialScrollOffset: 2040);
  String gender = '선택 안 함';
  double weight = 60;
  @override
  void initState() {
    super.initState();
    ruler.addListener(() {
      setState(() => weight = (ruler.offset / 34 * 10).round() / 10);
    });
  }

  @override
  void dispose() {
    age.dispose();
    ruler.dispose();
    super.dispose();
  }

  static const _minWeight = 20.0, _maxWeight = 300.0;

  /// 체중 숫자를 누르면 키패드로 직접 입력합니다. 눈금자도 그 값으로 옮깁니다.
  Future<void> _typeWeight() async {
    final controller = TextEditingController(text: weight.toStringAsFixed(1));
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    final formKey = GlobalKey<FormState>();
    double? parse(String? v) =>
        double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('체중 입력'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(suffixText: 'kg'),
            validator: (v) {
              final value = parse(v);
              return value != null && value >= _minWeight && value <= _maxWeight
                  ? null
                  : '${_minWeight.round()}~${_maxWeight.round()} kg 사이로 입력해주세요';
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, parse(controller.text));
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, parse(controller.text));
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
    // 다이얼로그가 닫히는 애니메이션이 끝난 뒤에 컨트롤러를 정리합니다.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (result == null || !mounted) return;
    final value = (result * 10).round() / 10;
    // 눈금자 1kg = 34px(0.1kg = 3.4px). 스크롤 위치가 바뀌면 리스너가 weight를 갱신합니다.
    ruler.jumpTo((value * 34).clamp(0, ruler.position.maxScrollExtent));
    setState(() => weight = value);
  }

  void complete() {
    if (!form.currentState!.validate()) return;
    if (weight <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('체중을 선택해주세요')));
      return;
    }
    Navigator.pop(
      context,
      RegistrationData(
        name: widget.name,
        email: widget.email,
        id: widget.id,
        password: widget.password,
        age: int.parse(age.text),
        gender: gender,
        weight: weight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    content: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SignupHeading(
            step: 3,
            title: 'RUNNING\nINFORMATION',
            description: '정확한 칼로리 계산을 위해 필요해요',
          ),
          const SizedBox(height: 32),
          AuthField(
            label: 'AGE',
            controller: age,
            hint: '나이를 입력해주세요',
            suffix: '세',
            keyboard: TextInputType.number,
            action: TextInputAction.done,
            validator: (v) =>
                (int.tryParse(v ?? '') ?? 0) > 0 ? null : '나이를 숫자로 입력해주세요',
          ),
          const SizedBox(height: 24),
          Text('GENDER', style: authLabelStyle),
          const SizedBox(height: 10),
          Row(
            children: ['여성', '남성', '선택 안 함']
                .map(
                  (value) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: value == '선택 안 함' ? 0 : 8,
                      ),
                      child: Semantics(
                        selected: gender == value,
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: gender == value
                                  ? AppColors.surfacePressed
                                  : Colors.transparent,
                              foregroundColor: gender == value
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              side: BorderSide(
                                color: gender == value
                                    ? AppColors.textPrimary
                                    : AppColors.borderDefault,
                              ),
                            ),
                            onPressed: () => setState(() => gender = value),
                            child: Text(value),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('WEIGHT', style: authLabelStyle),
              Text(
                '칼로리 계산에만 사용돼요',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: InkWell(
              onTap: _typeWeight,
              borderRadius: BorderRadius.circular(12),
              child: Semantics(
                button: true,
                hint: '눌러서 체중을 직접 입력',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: weight.toStringAsFixed(1),
                          style: const TextStyle(
                            fontFamily: 'Archivo',
                            fontVariations: [FontVariation('wdth', 75)],
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: ' KG', style: authLabelStyle),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: AppColors.textTertiary,
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
          SizedBox(
            height: 58,
            child: LayoutBuilder(
              builder: (context, box) => Semantics(
                label: '체중',
                value: '${weight.toStringAsFixed(1)} 킬로그램',
                increasedValue: '${(weight + .1).toStringAsFixed(1)} 킬로그램',
                decreasedValue: '${(weight - .1).toStringAsFixed(1)} 킬로그램',
                onIncrease: () => ruler.jumpTo(
                  (ruler.offset + 3.4).clamp(0, ruler.position.maxScrollExtent),
                ),
                onDecrease: () => ruler.jumpTo(
                  (ruler.offset - 3.4).clamp(0, ruler.position.maxScrollExtent),
                ),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    SingleChildScrollView(
                      controller: ruler,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: box.maxWidth / 2,
                        ),
                        child: CustomPaint(
                          size: const Size(10200, 58),
                          painter: _WeightRuler(),
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
          ),
        ],
      ),
    ),
    actions: AuthButton(label: '가입 완료', onPressed: complete),
  );
}

class _WeightRuler extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderControl
      ..strokeWidth = 1;
    for (int i = 0; i <= 1500; i++) {
      final x = i * 6.8;
      canvas.drawLine(Offset(x, i % 5 == 0 ? 6 : 16), Offset(x, 24), paint);
      if (i % 10 == 0) {
        final label = TextPainter(
          text: TextSpan(
            text: (i / 5).round().toString(),
            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x - label.width / 2, 32));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightRuler oldDelegate) => false;
}
