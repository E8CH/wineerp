import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

class WineCreated {
  const WineCreated({required this.productId, required this.vintageId});

  final String productId;
  final String vintageId;
}

/// 신규 와인 마스터 등록 (FR6). 토큰은 dio 인터셉터가 담당.
class WineRepository {
  WineRepository(this._dio);

  final Dio _dio;

  Future<WineCreated> create({
    required String producer,
    required String modelName,
    int? vintage, // null = NV (인식 실패가 아니라 유효 상태)
    String? barcode,
    String? representativeImageKey,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/wines',
      data: {
        'producer': producer,
        'model_name': modelName,
        'vintage': vintage,
        'barcode': ?barcode,
        'representative_image_key': ?representativeImageKey,
      },
    );
    final data = resp.data!;
    return WineCreated(
      productId: data['product_id'] as String,
      vintageId: data['vintage_id'] as String,
    );
  }
}

final wineRepositoryProvider = Provider<WineRepository>(
  (ref) => WineRepository(ref.watch(dioProvider)),
);
