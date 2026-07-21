import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

/// 라벨 사진 조회·캐시 (Story 6.1).
///
/// `GET /images/{key}`는 **인증 필수**라 `Image.network`로는 못 가져온다(Bearer 헤더가
/// 안 붙어 401). 그래서 dio(토큰 자동 첨부)로 바이트를 받아 위젯에 넘긴다.
///
/// key(`labels/<uuid>.jpg`)는 내용이 불변이라 **무효화가 필요 없다** — 두 단계로 캐시한다:
///  1. 메모리 LRU — 스크롤 왕복·재빌드에서 재요청/재디코드를 막는다. 재고 목록이 수백 장을
///     들고 있으면 메모리가 터지므로 상한을 둔다.
///  2. 디스크 — 앱을 재시작해도 남는다. 실기에서 사진이 매번 새로 받아지던 비용을 없앤다.
///     path_provider가 없는 환경(단위 테스트)에서도 죽지 않도록 디스크 접근은 전부 best-effort.
/// 서버 key(`labels/<uuid>.jpg`)를 캐시 파일명 하나로 평탄화한다.
///
/// 경로 구분자(`/`,`\`)와 상위 이동(`..`)을 전부 제거하므로 결과에는 구분자가 없다 →
/// `File('$dir/$name')`은 **항상 캐시 디렉터리의 직계 자식**이라 디렉터리 밖을 못 건드린다.
/// key는 서버가 발급하는 고유 UUID라 실제로 충돌하지 않는다(치환이 비단사인 건 이론상만).
String labelCacheFileName(String key) =>
    key.replaceAll(RegExp(r'[\\/]'), '_').replaceAll('..', '_');

class ImageRepository {
  ImageRepository(this._dio, {this._memoryCapacity = 24, Directory? cacheDir})
      : _injectedDir = cacheDir;

  final Dio _dio;
  final int _memoryCapacity;

  /// 테스트에서 실제 디스크 캐시 경로를 주입한다(path_provider 없이). null이면 운영은
  /// getApplicationCacheDirectory를 쓴다.
  final Directory? _injectedDir;

  // 접근 순서를 보존하는 LinkedHashMap으로 간단한 LRU를 만든다.
  final LinkedHashMap<String, Uint8List> _memory = LinkedHashMap();
  Directory? _cacheDir;

  /// key에 해당하는 라벨 바이트. 메모리 → 디스크 → 네트워크 순으로 찾는다.
  Future<Uint8List> load(String key) async {
    final cached = _memory.remove(key);
    if (cached != null) {
      _memory[key] = cached; // 최근 사용으로 승격
      return cached;
    }

    final fromDisk = await _readDisk(key);
    if (fromDisk != null) {
      _remember(key, fromDisk);
      return fromDisk;
    }

    final resp = await _dio.get<List<int>>(
      '/images/$key',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(resp.data!);
    _remember(key, bytes);
    await _writeDisk(key, bytes);
    return bytes;
  }

  void _remember(String key, Uint8List bytes) {
    _memory.remove(key);
    _memory[key] = bytes;
    // 가장 오래된 항목부터 버린다(LinkedHashMap 삽입 순서 = 사용 순서).
    while (_memory.length > _memoryCapacity) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<Directory?> _dir() async {
    if (_cacheDir != null) return _cacheDir;
    try {
      final base = _injectedDir ??
          Directory(
              '${(await getApplicationCacheDirectory()).path}/label_cache');
      if (!base.existsSync()) base.createSync(recursive: true);
      _cacheDir = base;
      return base;
    } catch (_) {
      // path_provider 미지원(주입도 없음) — 디스크 캐시 없이 동작한다.
      return null;
    }
  }

  Future<Uint8List?> _readDisk(String key) async {
    try {
      final dir = await _dir();
      if (dir == null) return null;
      final file = File('${dir.path}/${labelCacheFileName(key)}');
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(String key, Uint8List bytes) async {
    try {
      final dir = await _dir();
      if (dir == null) return;
      final file = File('${dir.path}/${labelCacheFileName(key)}');
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // 캐시 쓰기 실패는 조용히 무시한다 — 다음에 네트워크로 다시 받으면 그만이다.
    }
  }
}

final imageRepositoryProvider = Provider<ImageRepository>(
  (ref) => ImageRepository(ref.watch(dioProvider)),
);

/// key별 라벨 바이트. autoDispose로 화면에서 사라지면 메모리에서 놓는다 —
/// 리포지토리의 LRU와 디스크 캐시가 재구독 비용을 흡수하므로 여기서 붙들 이유가 없다.
final labelImageProvider =
    FutureProvider.autoDispose.family<Uint8List, String>((ref, key) {
  return ref.watch(imageRepositoryProvider).load(key);
});
