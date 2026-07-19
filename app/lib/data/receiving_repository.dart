import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 입고 확정 API (FR7). 토큰 첨부는 dio 인터셉터가 담당.
///
/// `staffId`·`receivedAt`을 보내지 않는다 — 서버가 토큰과 서버 시계로 정한다.
class ReceivingRepository {
  ReceivingRepository(this._dio);

  final Dio _dio;

  /// 성공 시 생성된 레코드 id. 서버가 2xx를 준 뒤 본문이 비었거나 형태가 달라도
  /// **던지지 않는다** — 이 경로에서 예외는 "저장 실패"가 아니라 "저장됐는데 못 읽음"이고,
  /// 호출부가 재시도하면 입고가 2건이 된다. 응답 파싱은 실패 신호가 될 수 없다.
  Future<String?> create({
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
    return resp.data?['id'] as String?;
  }
}

final receivingRepositoryProvider = Provider<ReceivingRepository>(
  (ref) => ReceivingRepository(ref.watch(dioProvider)),
);
