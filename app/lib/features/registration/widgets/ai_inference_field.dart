import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// 모델명 필드 + "AI 추론" 태그 (UX-DR8).
///
/// SM-C2(맹신 방지)의 UI 구현체다. 자동 채운 값은 **항상 편집 가능**하고, 태그가
/// 출처를 드러내며, 저신뢰는 색만이 아니라 아이콘·문구로도 전달한다.
/// 읽기 전용으로 잠그거나 태그를 숨기면 이 기능은 오등록을 늘리는 순손실이 된다.
class AiInferenceField extends StatelessWidget {
  const AiInferenceField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.isAiFilled = false,
    this.lowConfidence = false,
    this.inferring = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isAiFilled;
  final bool lowConfidence;
  final bool inferring;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('model_name_field'),
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: '모델명',
            border: const OutlineInputBorder(),
            // 추론 중에도 필드는 살아 있다 — 기다리는 동안 직접 칠 수 있어야 한다.
            suffixIcon: inferring
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (isAiFilled) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              const _Tag(
                key: Key('ai_tag'),
                label: 'AI 추론',
                icon: Icons.auto_awesome,
                color: AppColors.navyStrong,
              ),
              if (lowConfidence)
                const _Tag(
                  key: Key('low_confidence_tag'),
                  label: '확인 필요',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            lowConfidence
                ? '자신 없는 추론입니다. 라벨과 대조해 고쳐주세요.'
                : '자동으로 채운 값입니다. 라벨과 다르면 고쳐주세요.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // 색 단독으로 상태를 전달하지 않는다 — 아이콘·텍스트 병기(UX-DR15).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
