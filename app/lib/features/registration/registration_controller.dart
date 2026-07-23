import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/image_upload_service.dart';
import '../../data/inference_repository.dart';
import '../../data/inventory_repository.dart';
import '../../data/wine_catalog_repository.dart';
import '../../data/wine_repository.dart';

/// 라벨 촬영·업로드 경로. 테스트에서 override해 시스템 카메라를 우회한다.
///
/// `camera`가 아니라 `image_picker`인 이유는 하드웨어 경합이다 — `mobile_scanner`가
/// 이미 카메라를 점유하고 있고, 등록 패널은 스캔 화면 위에 뜬다. `image_picker`는
/// 시스템 카메라 앱에 넘겼다가 결과만 받으므로 충돌하지 않는다.
final labelPickerProvider = Provider<Future<List<int>?> Function()>((ref) {
  return () async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    return file == null ? null : await file.readAsBytes();
  };
});

enum InferencePhase { idle, inferring, done, failed }

class RegistrationState {
  const RegistrationState({
    this.imageKey,
    this.producer = '',
    this.modelName = '',
    this.vintage,
    this.isNv = false,
    this.isAiFilled = false,
    this.lowConfidence = false,
    this.phase = InferencePhase.idle,
    this.submitting = false,
    this.error,
    this.initialQuantity,
  });

  /// 업로드된 라벨 사진 key. 없으면 등록도 추론도 불가(AC2).
  final String? imageKey;
  final String producer;
  final String modelName;

  /// 확정된 연도. `isNv`가 true면 무시하고 null을 전송한다.
  final int? vintage;

  /// ⚠️ 빈 연도로 NV를 표현하지 않는다. "아직 입력 안 함"과 "NV로 확정"은 다르다.
  final bool isNv;

  /// 모델명이 AI 추론으로 채워졌는지 — 태그로 출처를 드러내기 위함(SM-C2).
  final bool isAiFilled;
  final bool lowConfidence;
  final InferencePhase phase;
  final bool submitting;
  final String? error;

  /// 초기 세팅에서만 쓰는 보유 수량(선택). null이면 마스터만 등록한다 —
  /// "마스터만 빨리 등록하고 싶다"를 막지 않기 위해 강제하지 않는다.
  final int? initialQuantity;

  bool get hasPhoto => imageKey != null;
  bool get isInferring => phase == InferencePhase.inferring;

  /// 등록 가능 조건. 사진과 두 필수 필드가 모두 있어야 한다.
  bool get canSubmit =>
      hasPhoto && producer.trim().isNotEmpty && modelName.trim().isNotEmpty && !submitting;

  /// 서버로 보낼 빈티지. NV면 명시적으로 null.
  int? get vintageToSubmit => isNv ? null : vintage;

  RegistrationState copyWith({
    String? imageKey,
    String? producer,
    String? modelName,
    int? vintage,
    bool clearVintage = false,
    bool? isNv,
    bool? isAiFilled,
    bool? lowConfidence,
    InferencePhase? phase,
    bool? submitting,
    String? error,
    bool clearError = false,
    int? initialQuantity,
    bool clearInitialQuantity = false,
  }) =>
      RegistrationState(
        imageKey: imageKey ?? this.imageKey,
        producer: producer ?? this.producer,
        modelName: modelName ?? this.modelName,
        vintage: clearVintage ? null : (vintage ?? this.vintage),
        isNv: isNv ?? this.isNv,
        isAiFilled: isAiFilled ?? this.isAiFilled,
        lowConfidence: lowConfidence ?? this.lowConfidence,
        phase: phase ?? this.phase,
        submitting: submitting ?? this.submitting,
        error: clearError ? null : (error ?? this.error),
        initialQuantity: clearInitialQuantity
            ? null
            : (initialQuantity ?? this.initialQuantity),
      );
}

class RegistrationController extends Notifier<RegistrationState> {
  /// 폼의 "세대". 리셋하거나 사용자가 직접 입력하면 올라간다.
  ///
  /// ⚠️ 이 프로바이더는 autoDispose가 아니라서, 패널이 사라진 뒤 도착한 비동기 응답도
  /// `state =`가 조용히 성공한다. 크래시보다 나쁘다 — 업로드/추론 결과가 **다음 병의
  /// 폼**에 찍히고, 작업자는 자기가 찍지 않은 사진과 이전 병의 모델명을 보게 된다.
  /// await 전후로 세대를 비교해 늦게 온 결과를 버린다.
  int _generation = 0;

  @override
  RegistrationState build() => const RegistrationState();

  Future<void> captureLabel() async {
    final gen = _generation;
    final bytes = await ref.read(labelPickerProvider)();
    if (bytes == null) return; // 사용자가 취소
    try {
      final result = await ref.read(imageUploadServiceProvider).upload(bytes);
      if (gen != _generation) return; // 다음 병으로 넘어간 뒤 도착 — 버린다
      state = state.copyWith(imageKey: result.key, clearError: true);
    } catch (_) {
      if (gen != _generation) return;
      state = state.copyWith(error: '사진 업로드 실패 · 다시 촬영하세요');
    }
  }

  /// 라벨에서 모델명 초안을 받아온다.
  ///
  /// 서버는 실패도 200 + 값으로 주므로 여기서 예외를 기대하지 않는다. 결과는
  /// **초안일 뿐이며 자동 저장되지 않는다** — 직원이 확인·수정해야 등록된다(SM-C2).
  Future<void> inferModelName() async {
    final key = state.imageKey;
    if (key == null || state.isInferring) return;
    final gen = _generation;
    state = state.copyWith(phase: InferencePhase.inferring, clearError: true);
    try {
      final r = await ref.read(inferenceRepositoryProvider).inferLabel(key);
      // 사용자가 [직접입력]을 눌렀거나 직접 타이핑했거나 다음 병으로 넘어갔으면
      // 이 응답은 늦은 것이다. 덮어쓰면 사용자가 친 글자가 사라지고 커서가 튄다.
      if (gen != _generation) return;
      if (r.needsManualInput) {
        state = state.copyWith(
          phase: InferencePhase.failed,
          error: '모델명을 읽지 못했습니다 · 직접 입력해주세요',
        );
        return;
      }
      state = state.copyWith(
        modelName: r.modelName!,
        isAiFilled: true,
        lowConfidence: r.lowConfidence,
        phase: InferencePhase.done,
      );
    } catch (_) {
      if (gen != _generation) return;
      state = state.copyWith(
        phase: InferencePhase.failed,
        error: '추론 실패 · 직접 입력해주세요',
      );
    }
  }

  /// 사용자가 값을 건드리면 더 이상 AI 값이 아니다 — 태그를 내린다.
  void setModelName(String v) {
    // 사용자가 직접 쳤으면 이 필드는 사용자 것이다 — 진행 중인 추론 결과를 무효화한다.
    _generation++;
    state = state.copyWith(modelName: v, isAiFilled: false, lowConfidence: false);
  }

  void setProducer(String v) => state = state.copyWith(producer: v);

  void setVintage(int? v) =>
      state = v == null
          ? state.copyWith(clearVintage: true)
          : state.copyWith(vintage: v);

  void setNv(bool nv) => state = state.copyWith(isNv: nv);

  void setInitialQuantity(int? q) => state = q == null
      ? state.copyWith(clearInitialQuantity: true)
      : state.copyWith(initialQuantity: q);

  /// 추론을 건너뛰고 즉시 수동 입력으로. 대기 중에도 눌린다(폴백 상시 노출).
  void useManualInput() {
    // 진행 중인 추론을 취소할 수는 없지만, 그 결과를 받아들이지는 않는다.
    _generation++;
    state = state.copyWith(phase: InferencePhase.idle, clearError: true);
  }

  void reset() {
    _generation++;
    state = const RegistrationState();
  }

  /// 등록. 성공 시 생성된 `vintage_id`를 반환해 곧바로 입고로 이어진다.
  Future<String?> submit({String? barcode}) async {
    if (!state.canSubmit) return null;
    final gen = _generation;
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final created = await ref.read(wineRepositoryProvider).create(
            producer: state.producer.trim(),
            modelName: state.modelName.trim(),
            vintage: state.vintageToSubmit,
            barcode: barcode,
            representativeImageKey: state.imageKey,
            // 초기 세팅에서만 채워진다. 마스터와 기준 재고를 한 요청으로 만드는
            // 이유는 원자성이다 — 두 번 부르면 사이에서 실패했을 때 수량 없는
            // 마스터가 남고 작업자는 알 수 없다.
            initialQuantity: state.initialQuantity,
          );
      // 새 마스터(및 초기 세팅 수량)가 생겼으니 재고·카탈로그를 다음 조회 때 새로고침한다 —
      // 없으면 방금 등록한 와인이 재고·모델 목록에 안 나타난다.
      bumpInventory(ref);
      bumpCatalog(ref);
      // ⚠️ 성공 경로에서도 반드시 내린다. 호출자가 reset()을 부를 것이라고 가정하면,
      // 부르지 않는 호출자에게는 영원히 도는 스피너와 잠긴 폼이 남는다.
      if (gen != _generation) return created.vintageId; // 폼은 이미 다음 병 것
      state = state.copyWith(submitting: false);
      return created.vintageId;
    } catch (_) {
      if (gen != _generation) return null;
      state = state.copyWith(submitting: false, error: '등록 실패 · 다시 시도하세요');
      return null;
    }
  }
}

final registrationControllerProvider =
    NotifierProvider<RegistrationController, RegistrationState>(
  RegistrationController.new,
);
