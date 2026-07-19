import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'registration_controller.dart';
import 'widgets/ai_inference_field.dart';
import 'widgets/vintage_field.dart';

/// 신규 와인 등록 (FR6, UX-DR8) — 라벨 촬영 → [모델검색] → 확인·수정 → 등록.
///
/// 등록이 끝나면 `onRegistered(vintageId)`로 곧바로 수량 입력·완료 흐름에 이어진다.
class RegistrationPanel extends ConsumerStatefulWidget {
  const RegistrationPanel({
    super.key,
    required this.onRegistered,
    this.barcode,
    this.onCancel,
    this.setupMode = false,
  });

  /// 초기 세팅 모드 여부. 보유 수량 필드와 골드 CTA("등록하고 다음 병")를 켠다.
  final bool setupMode;

  /// 스캔에서 넘어온 코드. 있으면 등록 시 연결해 다음부터 바로 매칭된다.
  final String? barcode;
  final ValueChanged<String> onRegistered;
  final VoidCallback? onCancel;

  @override
  ConsumerState<RegistrationPanel> createState() => _RegistrationPanelState();
}

class _RegistrationPanelState extends ConsumerState<RegistrationPanel> {
  final _model = TextEditingController();
  final _producer = TextEditingController();
  final _vintage = TextEditingController();
  final _quantity = TextEditingController();

  @override
  void dispose() {
    _model.dispose();
    _producer.dispose();
    _vintage.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = await ref
        .read(registrationControllerProvider.notifier)
        .submit(barcode: widget.barcode);
    // ⚠️ mounted 확인 없이 콜백을 부르면, 저장 중 세팅 모드를 나갔을 때 콜백 안의
    // `ref.read`가 이미 죽은 엘리먼트에 닿아 StateError가 uncaught로 샌다.
    // 와인은 서버에 생성된 채로 카운터도 안 오르고 확인도 못 받는다.
    if (id != null && mounted) widget.onRegistered(id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationControllerProvider);
    final ctrl = ref.read(registrationControllerProvider.notifier);

    // 추론이 모델명을 채웠을 때만 텍스트를 덮어쓴다(사용자 입력을 밀어내지 않는다).
    if (state.isAiFilled && _model.text != state.modelName) {
      _model.text = state.modelName;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.add_a_photo_outlined, color: AppColors.categoryLabel),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.setupMode ? '보유 와인 등록' : '새 와인 등록',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.onCancel != null)
                  IconButton(
                    key: const Key('registration_cancel'),
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close),
                    tooltip: '취소',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _PhotoRow(hasPhoto: state.hasPhoto, onCapture: ctrl.captureLabel),
            const SizedBox(height: 12),
            // 사진이 없으면 아무것도 진행되지 않는다 — 라벨은 기록·재매칭·추론의
            // 공용 소스이고, 바코드 없는 와인이 절반가량이다(FR4).
            if (state.hasPhoto) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const Key('infer_button'),
                      onPressed: state.isInferring ? null : ctrl.inferModelName,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: Text(state.isInferring ? '읽는 중…' : '모델검색'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ⚠️ 추론 중에도 눌린다. 3~5초 동안 아무것도 못 하면 현장 리듬이
                  // 끊긴다 — 폴백은 실패 후가 아니라 처음부터 보인다(UX-DR13).
                  TextButton(
                    key: const Key('manual_input_button'),
                    onPressed: ctrl.useManualInput,
                    child: const Text('직접입력'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AiInferenceField(
                controller: _model,
                onChanged: ctrl.setModelName,
                isAiFilled: state.isAiFilled,
                lowConfidence: state.lowConfidence,
                inferring: state.isInferring,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('producer_field'),
                controller: _producer,
                onChanged: ctrl.setProducer,
                decoration: const InputDecoration(
                  labelText: '생산자',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              VintageField(
                controller: _vintage,
                isNv: state.isNv,
                onNvChanged: ctrl.setNv,
                onVintageChanged: ctrl.setVintage,
              ),
              if (widget.setupMode) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('initial_quantity_field'),
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => ctrl.setInitialQuantity(int.tryParse(v)),
                  decoration: const InputDecoration(
                    labelText: '보유 수량 (선택)',
                    helperText: '비워두면 마스터만 등록합니다',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ],
              if (state.error != null) _ErrorRow(message: state.error!),
              const SizedBox(height: 8),
              SizedBox(
                height: 58,
                child: FilledButton.icon(
                  key: const Key('registration_submit'),
                  onPressed: state.canSubmit ? _submit : null,
                  icon: state.submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    state.submitting
                        ? '등록 중…'
                        : (widget.setupMode ? '등록하고 다음 병' : '등록하고 계속'),
                  ),
                  // 초기 세팅 Primary는 골드 — 입고 모드와 색으로 구분한다(UX 사양).
                  style: widget.setupMode
                      ? FilledButton.styleFrom(
                          backgroundColor: AppColors.categoryStock,
                        )
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.hasPhoto, required this.onCapture});

  final bool hasPhoto;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('capture_label_button'),
      onPressed: onCapture,
      icon: Icon(hasPhoto ? Icons.check_circle : Icons.photo_camera),
      label: Text(hasPhoto ? '라벨 사진 촬영됨 · 다시 찍기' : '라벨 사진 촬영 (필수)'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: hasPhoto ? AppColors.success : AppColors.navy,
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
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
