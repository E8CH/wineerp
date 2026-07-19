import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

class ImageUploadResult {
  const ImageUploadResult({required this.key, required this.url});

  final String key;
  final String url;
}

/// 라벨 이미지 업로드 (FR4). 서버가 EXIF 제거 후 저장하고 {key,url}을 돌려준다.
/// 토큰은 dio 인터셉터가 붙인다 — 직접 헤더를 넣지 말 것.
class ImageUploadService {
  ImageUploadService(this._dio);

  final Dio _dio;

  Future<ImageUploadResult> upload(
    List<int> bytes, {
    String filename = 'label.jpg',
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final resp = await _dio.post<Map<String, dynamic>>('/images', data: form);
    final data = resp.data!;
    return ImageUploadResult(
      key: data['key'] as String,
      url: data['url'] as String,
    );
  }
}

final imageUploadServiceProvider = Provider<ImageUploadService>(
  (ref) => ImageUploadService(ref.watch(dioProvider)),
);
