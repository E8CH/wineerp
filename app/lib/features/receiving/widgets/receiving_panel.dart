import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/scan_models.dart';
import '../receiving_controller.dart';
import 'quantity_stepper.dart';
import 'receiving_confirm_card.dart';

/// 확정된 후보 → 수량 → [완료] (FR7, UX-DR6·13).
///
/// 확인 카드 아래에 스테퍼와 하단 고정 [완료]를 붙여 "찍고→수량→완료→다음 병"
/// 리듬을 한 화면에서 끝낸다.
class ReceivingPanel extends ConsumerWidget {
  const ReceivingPanel({
    super.key,
    required this.candidate,
    this.onReselect,
  });

  final VintageCandidate candidate;
  final VoidCallback? onReselect;

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final vintageId = candidate.vintage?.id;
    if (vintageId == null) return;

    final ok = await ref.read(receivingControllerProvider.notifier).submit(vintageId);
    if (!ok || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '입고 완료 · ${candidate.product.modelName}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receivingControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReceivingConfirmCard(
          modelName: candidate.product.modelName,
          producer: candidate.product.producer,
          vintage: candidate.year,
          imageKey: candidate.vintage?.representativeImageKey,
          stock: candidate.stock,
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QuantityStepper(
                  quantity: state.quantity,
                  enabled: !state.isSubmitting,
                  onChanged:
                      ref.read(receivingControllerProvider.notifier).setQuantity,
                ),
                // ⚠️ 기본은 접힘. 상시 노출하면 "찍고→수량→완료" 3탭 리듬에 필드가
                // 끼어들고, 100병을 처리하는 직원이 100번 그것을 지나쳐야 한다(NFR3).
                // 메모는 파손·불일치 같은 예외 상황용이다.
                _MemoField(
                  enabled: !state.isSubmitting,
                  onChanged:
                      ref.read(receivingControllerProvider.notifier).setMemo,
                ),
                if (state.error != null) _ErrorRow(message: state.error!),
                const SizedBox(height: 8),
                SizedBox(
                  height: 58, // 하단 고정 1급 액션 (UX 사양)
                  child: FilledButton.icon(
                    key: const Key('receiving_complete'),
                    // 제출 중에는 눌려도 아무 일이 없어야 한다(중복 입고 방지).
                    onPressed: state.isSubmitting
                        ? null
                        : () => _submit(context, ref),
                    icon: state.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(state.isSubmitting ? '저장 중…' : '완료'),
                  ),
                ),
                if (onReselect != null)
                  TextButton.icon(
                    key: const Key('reselect_candidate'),
                    onPressed: state.isSubmitting ? null : onReselect,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('다시 선택'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 접이식 메모 입력. 필요할 때만 펼친다.
class _MemoField extends StatefulWidget {
  const _MemoField({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_MemoField> createState() => _MemoFieldState();
}

class _MemoFieldState extends State<_MemoField> {
  bool _open = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('memo_toggle'),
          onPressed: widget.enabled ? () => setState(() => _open = true) : null,
          icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
          label: const Text('메모 추가'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        key: const Key('memo_field'),
        controller: _controller,
        enabled: widget.enabled,
        maxLength: 500,
        onChanged: widget.onChanged,
        decoration: const InputDecoration(
          labelText: '메모 (선택)',
          hintText: '파손·명세서 불일치 등',
          border: OutlineInputBorder(),
          counterText: '',
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    // 인라인 오류 + 재시도(=[완료] 재활성). 차단 모달 금지(UX-DR13).
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
