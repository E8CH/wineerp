import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/label_thumbnail.dart';
import '../../data/wine_catalog_repository.dart';
import '../receiving/widgets/category_bar.dart';
import 'widgets/catalog_detail_sheet.dart';

/// 모델(제품) 카탈로그 탭 (Story 7.x) — 등록된 와인 모델을 카드로 보여준다.
///
/// 재고 탭이 **빈티지 단위** 행이라면, 여기는 **제품(모델) 단위** 카드다. 카드를 누르면
/// 상단 사진 + 아래 정보의 상세가 뜨고, 거기서 수정·삭제(manager)한다.
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('모델'),
        actions: [
          IconButton(
            key: const Key('catalog_refresh'),
            tooltip: '새로고침',
            onPressed: () => ref.read(catalogRevisionProvider.notifier).state++,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _ErrorState(),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.read(catalogRevisionProvider.notifier).state++,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CatalogCard(item: items[i]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item});

  final ProductCatalogItem item;

  /// 지역·국가·품종 중 있는 것만 가운뎃점으로 잇는다.
  String get _spec => [item.region, item.country, item.grape]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' · ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = _spec;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => showCatalogDetail(context, item),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 네이비 = 식별(모델) 위계.
              const CategoryBar(color: AppColors.categoryIdentity),
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
                        item.producer,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (spec.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            spec,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '빈티지 ${item.vintages.length}종 · 재고 ${item.totalStock}병',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.navy),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Icon(Icons.chevron_right, color: AppColors.muted),
                ),
              ),
            ],
          ),
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
      key: const Key('catalog_empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.style_outlined, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            '등록된 모델이 없습니다',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            '스캔 탭에서 새 와인을 등록하면 여기에 쌓입니다.',
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
      key: Key('catalog_error'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: AppColors.muted),
          SizedBox(height: 12),
          Text('모델 목록을 불러오지 못했습니다'),
        ],
      ),
    );
  }
}
