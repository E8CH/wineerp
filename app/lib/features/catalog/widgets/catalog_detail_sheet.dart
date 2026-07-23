import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/label_photo.dart';
import '../../../data/history_repository.dart';
import '../../../data/inventory_repository.dart';
import '../../../data/report_repository.dart';
import '../../../data/wine_catalog_repository.dart';
import '../../auth/auth_controller.dart';
import 'edit_wine_sheet.dart';

/// 모델 상세 시트 — 상단 큰 사진, 아래 제품 정보. manager면 [수정]·[삭제].
void showCatalogDetail(BuildContext context, ProductCatalogItem item) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CatalogDetailSheet(initial: item),
  );
}

/// 수정·삭제가 카탈로그·재고·내역·리포트에 두루 영향을 주므로, 성공 시 관련 데이터를
/// 한꺼번에 무효화한다. 무효화를 빠뜨리면 재고/내역이 옛 모델명이나 삭제 전 상태를 계속
/// 보여준다.
void _refreshEverything(WidgetRef ref) {
  // 위젯 컨텍스트라 bump*(Ref) 대신 notifier를 직접 올린다(WidgetRef.read).
  ref.read(catalogRevisionProvider.notifier).state++;
  ref.read(inventoryRevisionProvider.notifier).state++;
  ref.invalidate(historyProvider);
  ref.invalidate(reportProvider);
}

class _CatalogDetailSheet extends ConsumerStatefulWidget {
  const _CatalogDetailSheet({required this.initial});

  final ProductCatalogItem initial;

  @override
  ConsumerState<_CatalogDetailSheet> createState() =>
      _CatalogDetailSheetState();
}

class _CatalogDetailSheetState extends ConsumerState<_CatalogDetailSheet> {
  late ProductCatalogItem _item = widget.initial;
  bool _deleting = false;

  Future<void> _edit() async {
    final updated = await showEditWineSheet(context, _item);
    if (updated != null) {
      setState(() => _item = updated);
      _refreshEverything(ref); // 이름 변경을 재고·내역·리포트에 반영
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('delete_warning_dialog'),
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
        title: const Text('이 모델을 삭제할까요?'),
        content: Text(
          '"${_item.modelName}"을(를) 삭제하면 카탈로그·재고·리포트에서 사라집니다. '
          '연결된 입고 내역은 기록 보존을 위해 남지만 "삭제된 모델"로 표시됩니다.\n\n'
          '삭제 후에도 같은 모델을 다시 등록할 수 있습니다. 계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('delete_confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || _deleting) return;

    setState(() => _deleting = true);
    try {
      await ref.read(wineCatalogRepositoryProvider).delete(_item.productId);
      if (!mounted) return;
      _refreshEverything(ref);
      Navigator.of(context).pop(); // 상세 시트를 닫는다
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제 실패 · 다시 시도하세요')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isManager = ref.watch(authControllerProvider).role == 'manager';
    final item = _item;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단: 찍은 그대로의 큰 사진.
              LabelPhotoLarge(
                key: const Key('catalog_detail_photo'),
                imageKey: item.representativeImageKey,
                height: 280,
              ),
              const SizedBox(height: 16),
              // 아래: 제품 정보.
              Text(item.modelName, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                item.producer,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              if ((item.region ?? '').isNotEmpty)
                _DetailRow(label: '지역', value: item.region!),
              if ((item.country ?? '').isNotEmpty)
                _DetailRow(label: '국가', value: item.country!),
              if ((item.grape ?? '').isNotEmpty)
                _DetailRow(label: '품종', value: item.grape!),
              _DetailRow(label: '재고', value: '${item.totalStock}병'),
              const SizedBox(height: 8),
              // 빈티지별 현재고.
              Text('빈티지', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final v in item.vintages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(v.vintageLabel, style: theme.textTheme.bodyLarge),
                      Text('${v.stock}병',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
              if (isManager) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('catalog_edit'),
                        onPressed: _deleting ? null : _edit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('수정'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('catalog_delete'),
                        onPressed: _deleting ? null : _confirmDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(_deleting ? '삭제 중…' : '삭제'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
