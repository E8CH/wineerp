import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 라벨 추론 결과. 서버가 **항상 200**을 주고 실패를 값으로 표현하므로
/// 이 클래스도 실패를 예외가 아니라 필드로 갖는다(FR6 수동 폴백 분기).
class InferenceResult {
  const InferenceResult({
    this.modelName,
    this.confidence = 0,
    this.failed = false,
    this.lowConfidence = false,
    this.needsManualInput = false,
  });

  final String? modelName;
  final double confidence;
  final bool failed;
  final bool lowConfidence;
  final bool needsManualInput;

  factory InferenceResult.fromJson(Map<String, dynamic> json) => InferenceResult(
        modelName: json['model_name'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        failed: json['failed'] as bool? ?? false,
        lowConfidence: json['low_confidence'] as bool? ?? false,
        needsManualInput: json['needs_manual_input'] as bool? ?? false,
      );
}

class InferenceRepository {
  InferenceRepository(this._dio);

  final Dio _dio;

  Future<InferenceResult> inferLabel(String imageKey) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/inference/label',
      data: {'image_key': imageKey},
    );
    return InferenceResult.fromJson(resp.data!);
  }
}

final inferenceRepositoryProvider = Provider<InferenceRepository>(
  (ref) => InferenceRepository(ref.watch(dioProvider)),
);
