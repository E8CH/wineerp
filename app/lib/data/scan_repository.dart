import 'package:dio/dio.dart';

import '../core/env.dart';
import 'scan_models.dart';

/// 스캔 매칭 API 호출 (FR5). code → WineProduct 후보.
class ScanRepository {
  ScanRepository(this._dio);

  final Dio _dio;

  Future<ScanResult> scan(String code, {required String token}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '${Env.apiV1}/scan',
      data: {'code': code},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return ScanResult.fromJson(resp.data!);
  }
}
