import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/core/widgets/label_thumbnail.dart';
import 'package:wineerp_app/data/image_repository.dart';

/// Story 6.1 — 인증 라벨 사진 표시·캐시.

/// 유효한 1x1 투명 PNG. Image.memory가 errorBuilder로 떨어지지 않게 진짜 이미지를 쓴다.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// 실제 HTTP 호출 횟수를 세는 어댑터. 캐시가 네트워크를 막는지 검증하려면
/// 리포지토리가 아니라 이 지점에서 세야 한다.
class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.body);
  final Uint8List body;
  int calls = 0;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    paths.add(options.path);
    return ResponseBody.fromBytes(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['image/jpeg'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeImageRepo extends ImageRepository {
  _FakeImageRepo({this.bytes, this.fail = false, this.delay}) : super(Dio());
  final Uint8List? bytes;
  final bool fail;
  final Duration? delay;
  int calls = 0;

  @override
  Future<Uint8List> load(String key) async {
    calls++;
    if (delay != null) await Future<void>.delayed(delay!);
    if (fail) throw Exception('boom');
    return bytes ?? _png;
  }
}

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
    );

ProviderContainer _container(ImageRepository repo) {
  final c = ProviderContainer(
    overrides: [imageRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('LabelThumbnail', () {
    testWidgets('key가 null이면 병 아이콘 폴백이고 네트워크를 건드리지 않는다',
        (tester) async {
      final repo = _FakeImageRepo();
      await tester.pumpWidget(
        _host(_container(repo), const LabelThumbnail(imageKey: null)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wine_bar), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(repo.calls, 0); // 폴백이 조회를 건너뛰는지 — 지우면 calls>0
    });

    testWidgets('빈 문자열도 폴백 처리한다', (tester) async {
      final repo = _FakeImageRepo();
      await tester.pumpWidget(
        _host(_container(repo), const LabelThumbnail(imageKey: '')),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.wine_bar), findsOneWidget);
      expect(repo.calls, 0);
    });

    testWidgets('key가 있으면 사진을 그린다(아이콘 없음)', (tester) async {
      final repo = _FakeImageRepo(bytes: _png);
      await tester.pumpWidget(
        _host(_container(repo),
            const LabelThumbnail(imageKey: 'labels/a.jpg')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.wine_bar), findsNothing);
      expect(repo.calls, 1);
    });

    testWidgets('로딩 중에는 스피너를 보여준다', (tester) async {
      final repo =
          _FakeImageRepo(delay: const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _host(_container(repo),
            const LabelThumbnail(imageKey: 'labels/a.jpg')),
      );
      await tester.pump(); // 아직 미완

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    });

    testWidgets('조회 실패는 병 아이콘으로 떨어진다(깨진 이미지 아님)',
        (tester) async {
      final repo = _FakeImageRepo(fail: true);
      await tester.pumpWidget(
        _host(_container(repo),
            const LabelThumbnail(imageKey: 'labels/a.jpg')),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wine_bar), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('손상된 바이트는 깨진 이미지가 아니라 병 아이콘으로 떨어진다',
        (tester) async {
      // Image.memory의 errorBuilder 경로 — 이걸 지우면 손상 캐시가 Flutter 기본
      // 깨진-이미지 글리프로 렌더된다(조회는 성공했으므로 .when(error:)가 아니다).
      final repo = _FakeImageRepo(bytes: Uint8List.fromList(const [1, 2, 3, 4]));
      await tester.pumpWidget(
        _host(_container(repo),
            const LabelThumbnail(imageKey: 'labels/bad.jpg')),
      );
      await tester.pumpAndSettle();
      tester.takeException(); // 디코드 실패 로그를 소진(errorBuilder가 처리함)

      expect(find.byIcon(Icons.wine_bar), findsOneWidget);
    });
  });

  group('ImageRepository 캐시', () {
    test('같은 key 두 번째 조회는 메모리 캐시로 네트워크를 건너뛴다', () async {
      final adapter = _CountingAdapter(_png);
      final dio = Dio()..httpClientAdapter = adapter;
      final repo = ImageRepository(dio);

      final a = await repo.load('labels/x.jpg');
      final b = await repo.load('labels/x.jpg');

      expect(a, equals(b));
      expect(adapter.calls, 1); // 캐시 히트를 지우면 2가 된다
    });

    test('요청 경로에 key가 그대로 들어간다', () async {
      final adapter = _CountingAdapter(_png);
      final dio = Dio()..httpClientAdapter = adapter;
      await ImageRepository(dio).load('labels/x.jpg');
      expect(adapter.paths.single, '/images/labels/x.jpg');
    });

    test('LRU 상한을 넘긴 가장 오래된 항목은 방출되어 재조회된다', () async {
      final adapter = _CountingAdapter(_png);
      final dio = Dio()..httpClientAdapter = adapter;
      final repo = ImageRepository(dio, memoryCapacity: 2);

      await repo.load('a'); // [a]
      await repo.load('b'); // [a,b]
      await repo.load('c'); // a 방출 → [b,c]
      expect(adapter.calls, 3);

      await repo.load('a'); // 방출됐으므로 다시 네트워크
      expect(adapter.calls, 4);

      await repo.load('c'); // 아직 캐시에 있음
      expect(adapter.calls, 4);
    });

    test('최근 사용은 방출 순서에서 뒤로 밀린다', () async {
      final adapter = _CountingAdapter(_png);
      final dio = Dio()..httpClientAdapter = adapter;
      final repo = ImageRepository(dio, memoryCapacity: 2);

      await repo.load('a'); // [a]
      await repo.load('b'); // [a,b]
      await repo.load('a'); // a 승격 → [b,a] (네트워크 X)
      expect(adapter.calls, 2);

      await repo.load('c'); // b 방출(a가 아니라) → [a,c]
      await repo.load('a'); // 여전히 캐시
      expect(adapter.calls, 3);
    });
  });

  group('ImageRepository 디스크 캐시', () {
    test('디스크에 쓰고, 새 인스턴스가 네트워크 없이 디스크에서 읽는다', () async {
      // path_provider가 없는 단위 테스트에서도 실제 디스크 경로를 주입해 검증한다 —
      // 그래야 _readDisk/_writeDisk가 실행된다(안 그러면 이 경로는 커버리지 0).
      final dir = Directory.systemTemp.createTempSync('label_cache_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      final adapter = _CountingAdapter(_png);
      final dio = Dio()..httpClientAdapter = adapter;

      final repo1 = ImageRepository(dio, cacheDir: dir);
      await repo1.load('labels/x.jpg');
      expect(adapter.calls, 1);

      // 새 인스턴스 = 메모리 캐시가 비어 있다. 디스크에서 나와야 한다(네트워크 X).
      final repo2 = ImageRepository(dio, cacheDir: dir);
      final bytes = await repo2.load('labels/x.jpg');
      expect(bytes, _png);
      expect(adapter.calls, 1, reason: '디스크 히트라 재요청 없음');
    });
  });

  group('labelCacheFileName', () {
    test('경로 구분자·상위 이동을 없애 캐시 디렉터리 밖으로 못 나간다', () {
      expect(labelCacheFileName('labels/x.jpg'), isNot(contains('/')));
      expect(labelCacheFileName('labels/x.jpg'), 'labels_x.jpg');

      final evil = labelCacheFileName('../../etc/passwd');
      expect(evil, isNot(contains('..')));
      expect(evil, isNot(contains('/')));
      expect(evil, isNot(contains(r'\')));
    });
  });
}
