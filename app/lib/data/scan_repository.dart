import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'scan_models.dart';

/// 스캔 매칭 API 호출 (FR5). 토큰 첨부는 dio 인터셉터가 담당.
class ScanRepository {
  ScanRepository(this._dio);

  final Dio _dio;

  Future<ScanResult> scan(String code) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/scan',
      data: {'code': code},
    );
    return ScanResult.fromJson(resp.data!);
  }
}

final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => ScanRepository(ref.watch(dioProvider)),
);
