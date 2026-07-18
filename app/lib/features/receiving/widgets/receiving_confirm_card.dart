import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'category_bar.dart';

/// 입고 확인 카드 (UX-DR5) — 병 사진 자리·모델명(22)·빈티지·좌측 CategoryBar.
/// 현재고 배지는 receiving_records(Story 2.6)에서 연결.
class ReceivingConfirmCard extends StatelessWidget {
  const ReceivingConfirmCard({
    super.key,
    required this.modelName,
    required this.producer,
    this.vintage,
    this.imageUrl,
    this.onConfirm,
  });

  final String modelName;
  final String producer;
  final int? vintage;
  final String? imageUrl;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vintageLabel = vintage?.toString() ?? 'NV';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CategoryBar(color: AppColors.categoryIdentity),
            // 병 사진 자리
            Container(
              width: 72,
              height: 72,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.wine_bar, color: AppColors.muted),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(producer, style: theme.textTheme.bodyMedium),
                    Text(modelName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text('빈티지 $vintageLabel'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
            if (onConfirm != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: FilledButton(
                  onPressed: onConfirm,
                  child: const Text('선택'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
