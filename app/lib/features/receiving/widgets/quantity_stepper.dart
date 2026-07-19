import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';

/// 수량 스테퍼 (UX-DR6) — [−] / 숫자(34pt) / [+], 최소 1.
///
/// 0병 입고는 입고가 아니므로 1에서 [−]는 비활성이다(숨기지 않는다 — 사라지면
/// 왜 못 줄이는지 알 수 없다).
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
    this.enabled = true,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool enabled;

  bool get _canDecrease => enabled && quantity > min;
  bool get _canIncrease => enabled && quantity < max;

  Future<void> _promptDirectInput(BuildContext context) async {
    final controller = TextEditingController(text: '$quantity');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('수량 입력'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          // 자릿수를 제한해 "20자리 입력 → tryParse null → 조용히 취소"와
          // "5000 입력 → 말없이 999로 clamp"를 애초에 만들지 않는다.
          maxLength: 3,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(suffixText: '병', helperText: '$min~$max'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(controller.text)),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (value != null) onChanged(value.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepButton(
          key: const Key('quantity_decrease'),
          icon: Icons.remove,
          semanticLabel: '수량 감소',
          onPressed: _canDecrease ? () => onChanged(quantity - 1) : null,
        ),
        Expanded(
          child: Semantics(
            label: '수량',
            value: '$quantity병',
            child: InkWell(
              key: const Key('quantity_value'),
              onTap: enabled ? () => _promptDirectInput(context) : null,
              child: Container(
                height: 56,
                alignment: Alignment.center,
                child: Text(
                  '$quantity',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(color: AppColors.onSurface),
                ),
              ),
            ),
          ),
        ),
        _StepButton(
          key: const Key('quantity_increase'),
          icon: Icons.add,
          semanticLabel: '수량 증가',
          onPressed: _canIncrease ? () => onChanged(quantity + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: SizedBox(
        width: 56,
        height: 56, // 터치 타깃 48dp+ (UX-DR15)
        child: IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: 26,
        ),
      ),
    );
  }
}
