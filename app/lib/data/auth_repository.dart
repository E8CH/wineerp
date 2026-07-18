import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 인증 API — 로그인(폼), 현재 사용자. 토큰 첨부는 dio 인터셉터가 담당.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<String> login(String email, String password) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': email, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return resp.data!['access_token'] as String;
  }

  Future<Map<String, dynamic>> me() async {
    final resp = await _dio.get<Map<String, dynamic>>('/auth/me');
    return resp.data!;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);
