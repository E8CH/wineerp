import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/wine_catalog_repository.dart';

/// 모델 수정 시트를 열고, 저장되면 갱신된 항목을, 취소되면 null을 돌려준다.
Future<ProductCatalogItem?> showEditWineSheet(
  BuildContext context,
  ProductCatalogItem item,
) {
  return showModalBottomSheet<ProductCatalogItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EditWineSheet(item: item),
  );
}

class _EditWineSheet extends ConsumerStatefulWidget {
  const _EditWineSheet({required this.item});

  final ProductCatalogItem item;

  @override
  ConsumerState<_EditWineSheet> createState() => _EditWineSheetState();
}

class _EditWineSheetState extends ConsumerState<_EditWineSheet> {
  late final _producer = TextEditingController(text: widget.item.producer);
  late final _modelName = TextEditingController(text: widget.item.modelName);
  late final _region = TextEditingController(text: widget.item.region ?? '');
  late final _country = TextEditingController(text: widget.item.country ?? '');
  late final _grape = TextEditingController(text: widget.item.grape ?? '');

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _producer.dispose();
    _modelName.dispose();
    _region.dispose();
    _country.dispose();
    _grape.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  bool get _canSave =>
      _producer.text.trim().isNotEmpty && _modelName.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (_busy || !_canSave) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await ref.read(wineCatalogRepositoryProvider).update(
            widget.item.productId,
            producer: _producer.text.trim(),
            modelName: _modelName.text.trim(),
            region: _clean(_region),
            country: _clean(_country),
            grape: _clean(_grape),
          );
      if (mounted) Navigator.of(context).pop(updated);
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          // manager가 아니면 403 — 버튼이 애초에 manager에게만 보이지만 방어적으로 안내.
          _error = e.response?.statusCode == 403
              ? '관리자만 수정할 수 있습니다'
              : '저장 실패 · 다시 시도하세요';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '저장 실패 · 다시 시도하세요';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('모델 수정', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              '수정하면 재고·입고 내역에도 바로 반영됩니다.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            _Field(
              fieldKey: 'edit_producer',
              controller: _producer,
              label: '생산자',
              onChanged: () => setState(() {}),
            ),
            _Field(
              fieldKey: 'edit_model_name',
              controller: _modelName,
              label: '모델명',
              onChanged: () => setState(() {}),
            ),
            _Field(fieldKey: 'edit_region', controller: _region, label: '지역 (선택)'),
            _Field(fieldKey: 'edit_country', controller: _country, label: '국가 (선택)'),
            _Field(fieldKey: 'edit_grape', controller: _grape, label: '품종 (선택)'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('edit_save'),
                onPressed: (_busy || !_canSave) ? null : _save,
                child: Text(_busy ? '저장 중…' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.fieldKey,
    required this.controller,
    required this.label,
    this.onChanged,
  });

  final String fieldKey;
  final TextEditingController controller;
  final String label;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key(fieldKey),
        controller: controller,
        onChanged: onChanged == null ? null : (_) => onChanged!(),
        maxLength: 200,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          counterText: '',
        ),
      ),
    );
  }
}
