import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 입고 확정 API (FR7). 토큰 첨부는 dio 인터셉터가 담당.
///
/// `staffId`·`receivedAt`을 보내지 않는다 — 서버가 토큰과 서버 시계로 정한다.
class ReceivingRepository {
  ReceivingRepository(this._dio);

  final Dio _dio;

  Future<String> create({
    required String wineVintageId,
    required int quantity,
    String? memo,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/receiving',
      data: {
        'wine_vintage_id': wineVintageId,
        'quantity': quantity,
        'memo': ?memo,
      },
    );
    return resp.data!['id'] as String;
  }
}

final receivingRepositoryProvider = Provider<ReceivingRepository>(
  (ref) => ReceivingRepository(ref.watch(dioProvider)),
);
