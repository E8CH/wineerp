import 'package:dio/dio.dart';

import '../core/env.dart';

class ImageUploadResult {
  const ImageUploadResult({required this.key, required this.url});

  final String key;
  final String url;
}

/// 라벨 이미지 업로드 (FR4). 서버가 EXIF 제거·저장 후 {key,url} 반환.
/// 실제 촬영·바이트 획득은 촬영 UI(입고 흐름, Story 2.6)에서 주입.
class ImageUploadService {
  ImageUploadService(this._dio);

  final Dio _dio;

  Future<ImageUploadResult> upload(
    List<int> bytes, {
    required String token,
    String filename = 'label.jpg',
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final resp = await _dio.post<Map<String, dynamic>>(
      '${Env.apiV1}/images',
      data: form,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = resp.data!;
    return ImageUploadResult(
      key: data['key'] as String,
      url: data['url'] as String,
    );
  }
}
