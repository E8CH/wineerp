import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/label_photo.dart';
import '../../../data/history_repository.dart';
import '../../auth/auth_controller.dart';
import 'quantity_stepper.dart';

/// 입고 수정 시트 (FR8, Story 4.2) — 수량 정정 + 사유(선택), manager는 취소도.
///
/// 취소가 manager에게만 보이는 이유: 수정은 다시 수정하면 되지만 취소는 재고에서
/// 통째로 빼는 일이고 복구 UI가 없다. 되돌리기 비용이 다르면 권한도 달라야 한다.
class AmendSheet extends ConsumerStatefulWidget {
  const AmendSheet({super.key, required this.item, required this.onDone});

  final HistoryItem item;

  /// 저장·취소가 끝났을 때. 호출부가 목록을 갱신한다.
  final VoidCallback onDone;

  @override
  ConsumerState<AmendSheet> createState() => _AmendSheetState();
}

class _AmendSheetState extends ConsumerState<AmendSheet> {
  late int _quantity = widget.item.quantity;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return; // 중복 제출 차단 — 입고 생성과 같은 이유다
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) widget.onDone();
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
    final repo = ref.read(receivingAmendRepositoryProvider);
    final isManager = ref.watch(authControllerProvider).role == 'manager';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단에 찍은 라벨 사진을 크게. 사진이 없는 기록(초기 세팅 등)은 자리를
          // 비워 시트를 짧게 유지한다.
          if ((widget.item.representativeImageKey ?? '').isNotEmpty) ...[
            LabelPhotoLarge(
              key: const Key('amend_photo'),
              imageKey: widget.item.representativeImageKey,
              height: 220,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            widget.item.modelName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${widget.item.vintageLabel} · 현재 ${widget.item.quantity}병',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          QuantityStepper(
            quantity: _quantity,
            enabled: !_busy,
            onChanged: (v) => setState(() => _quantity = v),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('amend_reason'),
            controller: _reason,
            enabled: !_busy,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: '수정 사유 (선택)',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('amend_save'),
              onPressed: _busy
                  ? null
                  : () => _run(() => repo.updateQuantity(
                        widget.item.id,
                        quantity: _quantity,
                        reason: _reason.text.trim().isEmpty
                            ? null
                            : _reason.text.trim(),
                      )),
              child: Text(_busy ? '저장 중…' : '저장'),
            ),
          ),
          if (isManager)
            TextButton.icon(
              key: const Key('amend_cancel_record'),
              onPressed: _busy ? null : () => _run(() => repo.cancel(widget.item.id)),
              icon: const Icon(Icons.delete_outline, size: 18),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              label: const Text('입고 취소'),
            ),
        ],
      ),
    );
  }
}
