import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/label_thumbnail.dart';
import '../../data/inventory_repository.dart';
import '../receiving/widgets/category_bar.dart';

/// 재고 탭 (UX-DR3, Story 6.2) — 보유 와인의 빈티지별 현재고.
///
/// 행 = 빈티지(재고 단위). 좌측 골드 바로 "재고" 위계를 표시하고(UX-DR9),
/// 라벨 사진·모델명·빈티지·현재고를 보여준다. 재고 0인 마스터도 숨기지 않는다 —
/// 등록됐는데 목록에 없으면 "왜 안 보이지"가 된다.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('재고'),
        actions: [
          IconButton(
            key: const Key('inventory_refresh'),
            tooltip: '새로고침',
            onPressed: () => ref.invalidate(inventoryProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: inventory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _ErrorState(),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(inventoryProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _InventoryRow(item: items[i]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 골드 = 재고 위계(UX-DR9).
            const CategoryBar(color: AppColors.categoryStock),
            Padding(
              padding: const EdgeInsets.all(10),
              child: LabelThumbnail(imageKey: item.representativeImageKey),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.modelName,
                      style: theme.textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${item.producer} · ${item.vintageLabel}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            _StockBadge(stock: item.stock),
          ],
        ),
      ),
    );
  }
}

/// 현재고 배지. 0은 흐리게 — "재고 있음"과 시각적으로 구분한다.
class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = stock == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$stock',
              key: const Key('stock_count'),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: isEmpty ? AppColors.muted : AppColors.onSurface,
              ),
            ),
            Text(
              '병',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('inventory_empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wine_bar, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            '등록된 와인이 없습니다',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            '스캔 탭에서 와인을 등록하면 여기에 표시됩니다.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('inventory_error'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: AppColors.muted),
          SizedBox(height: 12),
          Text('재고를 불러오지 못했습니다'),
        ],
      ),
    );
  }
}
