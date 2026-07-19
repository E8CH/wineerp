import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';

/// 빈티지 입력 — 연도 + **[NV] 토글** (AR2).
///
/// ⚠️ 빈 연도로 NV를 표현하지 않는다. `vintage=null`은 "NV로 확정"과
/// "아직 입력 안 함" 두 가지를 뜻할 수 있는데, 앞은 유효한 재고 단위이고 뒤는
/// 미완성 입력이다. 명시적 토글이 둘을 가른다.
/// 샴페인 85~95%·셰리 ~98%가 NV라 드문 경우가 아니다.
class VintageField extends StatelessWidget {
  const VintageField({
    super.key,
    required this.controller,
    required this.isNv,
    required this.onNvChanged,
    required this.onVintageChanged,
  });

  final TextEditingController controller;
  final bool isNv;
  final ValueChanged<bool> onNvChanged;
  final ValueChanged<int?> onVintageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('vintage_field'),
            controller: controller,
            enabled: !isNv,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => onVintageChanged(int.tryParse(v)),
            decoration: InputDecoration(
              labelText: '빈티지(연도)',
              border: const OutlineInputBorder(),
              counterText: '',
              hintText: isNv ? '해당 없음' : '예: 2018',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: FilterChip(
            key: const Key('nv_toggle'),
            selected: isNv,
            onSelected: onNvChanged,
            avatar: Icon(
              isNv ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: isNv ? AppColors.navy : AppColors.muted,
            ),
            label: const Text('NV'),
            selectedColor: AppColors.container,
            tooltip: 'Non-Vintage — 빈티지 표기가 없는 와인',
          ),
        ),
      ],
    );
  }
}
