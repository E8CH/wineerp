import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/core/widgets/label_photo.dart';
import 'package:wineerp_app/data/image_repository.dart';

/// LabelPhotoLarge — 상세 시트 상단의 큰 사진(잘림 없이 찍은 그대로).

/// 유효한 1x1 PNG(디코드 성공용). label_image_test와 동일.
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

class _FakeImageRepo extends ImageRepository {
  _FakeImageRepo({this.bytes, this.fail = false}) : super(Dio());
  final Uint8List? bytes;
  final bool fail;
  int calls = 0;

  @override
  Future<Uint8List> load(String key) async {
    calls++;
    if (fail) throw Exception('boom');
    return bytes ?? _png;
  }
}

ProviderContainer _container(ImageRepository repo) {
  final c = ProviderContainer(
    overrides: [imageRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
    );

void main() {
  testWidgets('key가 없으면 병 아이콘 폴백이고 네트워크를 건드리지 않는다',
      (tester) async {
    final repo = _FakeImageRepo();
    await tester.pumpWidget(
      _host(_container(repo), const LabelPhotoLarge(imageKey: null)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.wine_bar), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(repo.calls, 0);
  });

  testWidgets('key가 있으면 사진을 BoxFit.contain으로 그린다', (tester) async {
    // contain이어야 세로/가로 어느 각도든 잘리지 않고 그대로 담긴다. cover로
    // 바꾸면(잘라 채움) 이 단언이 깨진다.
    final repo = _FakeImageRepo(bytes: _png);
    await tester.pumpWidget(
      _host(_container(repo),
          const LabelPhotoLarge(imageKey: 'labels/a.jpg')),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(find.byIcon(Icons.wine_bar), findsNothing);
    expect(repo.calls, 1);
  });

  testWidgets('조회 실패는 깨진 이미지가 아니라 병 아이콘으로 떨어진다',
      (tester) async {
    final repo = _FakeImageRepo(fail: true);
    await tester.pumpWidget(
      _host(_container(repo),
          const LabelPhotoLarge(imageKey: 'labels/a.jpg')),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.wine_bar), findsOneWidget);
  });

  testWidgets('손상된 바이트도 병 아이콘으로 떨어진다', (tester) async {
    // Image.memory errorBuilder 경로 — 지우면 Flutter 기본 깨진-이미지 글리프가 뜬다.
    final repo = _FakeImageRepo(bytes: Uint8List.fromList(const [1, 2, 3, 4]));
    await tester.pumpWidget(
      _host(_container(repo),
          const LabelPhotoLarge(imageKey: 'labels/bad.jpg')),
    );
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.byIcon(Icons.wine_bar), findsOneWidget);
  });
}
