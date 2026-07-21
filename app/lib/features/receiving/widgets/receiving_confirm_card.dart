import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/label_thumbnail.dart';
import 'category_bar.dart';

/// 입고 확인 카드 (UX-DR5) — 병 사진·모델명(22)·빈티지·현재고 배지·좌측 CategoryBar.
class ReceivingConfirmCard extends StatelessWidget {
  const ReceivingConfirmCard({
    super.key,
    required this.modelName,
    required this.producer,
    this.vintage,
    this.imageKey,
    this.stock,
    this.onConfirm,
  });

  final String modelName;
  final String producer;
  final int? vintage;

  /// 저장된 라벨 사진 key(있으면). null이면 병 아이콘으로 떨어진다.
  final String? imageKey;

  /// 현재고(서버 집계). null이면 배지를 숨긴다 — 0과 "모름"은 다르다.
  final int? stock;

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
            Padding(
              padding: const EdgeInsets.all(12),
              child: LabelThumbnail(imageKey: imageKey, size: 72),
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Chip(
                          label: Text('빈티지 $vintageLabel'),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (stock != null)
                          Chip(
                            key: const Key('stock_badge'),
                            avatar: const Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                              color: AppColors.categoryStock,
                            ),
                            label: Text('현재고 $stock'),
                            backgroundColor: AppColors.container,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
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
