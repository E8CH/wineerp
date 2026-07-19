import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/image_upload_service.dart';
import 'package:wineerp_app/data/inference_repository.dart';
import 'package:wineerp_app/data/scan_models.dart';
import 'package:wineerp_app/data/wine_repository.dart';
import 'package:wineerp_app/features/registration/registration_controller.dart';
import 'package:wineerp_app/features/registration/registration_panel.dart';
import 'package:wineerp_app/features/registration/setup_mode_controller.dart';
import 'package:wineerp_app/features/scan/scan_controller.dart';
import 'package:wineerp_app/features/scan/scan_screen.dart';

/// Story 3.3 — 초기 재고 세팅 모드 (FR13, UX-DR10).
class _FakeUpload extends ImageUploadService {
  _FakeUpload() : super(Dio());

  @override
  Future<ImageUploadResult> upload(List<int> bytes, {String filename = 'label.jpg'}) async =>
      const ImageUploadResult(key: 'labels/x.jpg', url: 'u');
}

class _FakeInference extends InferenceRepository {
  _FakeInference() : super(Dio());

  @override
  Future<InferenceResult> inferLabel(String imageKey) async =>
      const InferenceResult(modelName: 'X', confidence: 0.9);
}

class _FakeWineRepo extends WineRepository {
  _FakeWineRepo() : super(Dio());

  final List<Map<String, dynamic>> calls = [];

  @override
  Future<WineCreated> create({
    required String producer,
    required String modelName,
    int? vintage,
    String? barcode,
    String? representativeImageKey,
    int? initialQuantity,
  }) async {
    calls.add({'barcode': barcode, 'initialQuantity': initialQuantity});
    return WineCreated(productId: 'p${calls.length}', vintageId: 'v${calls.length}');
  }
}

ScanResult _matched() => ScanResult.fromJson({
      'code': 'KNOWN-1',
      'products': [
        {
          'id': 'p1',
          'producer': 'Penfolds',
          'model_name': 'Grange',
          'vintages': [
            {'id': 'v1', 'vintage': 2016, 'stock': 5},
          ],
        },
      ],
    });

ScanResult _unmatched() =>
    ScanResult.fromJson({'code': 'NEW-9', 'products': <dynamic>[]});

ProviderContainer _container({ScanResult? result, _FakeWineRepo? repo}) {
  final c = ProviderContainer(overrides: [
    cameraEnabledProvider.overrideWithValue(false),
    imageUploadServiceProvider.overrideWithValue(_FakeUpload()),
    inferenceRepositoryProvider.overrideWithValue(_FakeInference()),
    wineRepositoryProvider.overrideWithValue(repo ?? _FakeWineRepo()),
    labelPickerProvider.overrideWithValue(() async => <int>[1, 2, 3]),
    if (result != null) matchProvider.overrideWith((ref) => AsyncData(result)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.light, home: const ScanScreen()),
    );

void main() {
  group('모드 진입·표시·나가기', () {
    testWidgets('배너·카운터가 뜨고 나가기로 벗어난다', (tester) async {
      final c = _container();
      await tester.pumpWidget(_host(c));

      await tester.tap(find.byKey(const Key('enter_setup_mode')));
      await tester.pumpAndSettle();
      expect(find.text('초기 세팅 모드'), findsOneWidget);
      expect(find.byKey(const Key('setup_counter')), findsOneWidget);
      expect(find.text('0종 등록'), findsOneWidget);

      await tester.tap(find.byKey(const Key('setup_exit')));
      await tester.pumpAndSettle();
      expect(find.text('초기 세팅 모드'), findsNothing);
      expect(c.read(setupModeProvider).active, isFalse);
    });

    testWidgets('나가면 카운터가 초기화된다', (tester) async {
      final c = _container();
      c.read(setupModeProvider.notifier).enter();
      c.read(setupModeProvider.notifier).countRegistration();
      expect(c.read(setupModeProvider).registeredCount, 1);

      c.read(setupModeProvider.notifier).exit();
      expect(c.read(setupModeProvider).registeredCount, 0);
      await tester.pumpWidget(_host(c));
    });
  });

  group('세팅 중에는 입고가 일어나지 않는다', () {
    testWidgets('매칭돼도 수량·완료가 아니라 "이미 등록됨"이 뜬다', (tester) async {
      // 창고를 돌며 등록된 병을 스캔하는 일은 흔하다. 여기서 [완료]가 보이면
      // 실제로 들어온 것 없이 입고가 생겨 재고가 이중 계상된다.
      final c = _container(result: _matched());
      c.read(setupModeProvider.notifier).enter();
      await tester.pumpWidget(_host(c));
      await tester.pumpAndSettle();

      expect(find.text('이미 등록된 와인'), findsOneWidget);
      expect(find.byKey(const Key('receiving_complete')), findsNothing);
    });

    testWidgets('입고 모드에서는 같은 결과가 수량·완료로 이어진다', (tester) async {
      final c = _container(result: _matched());
      await tester.pumpWidget(_host(c));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('receiving_complete')), findsOneWidget);
      expect(find.text('이미 등록된 와인'), findsNothing);
    });
  });

  group('연속 등록', () {
    testWidgets('미매칭이면 버튼 없이 바로 등록 폼이 뜬다', (tester) async {
      final c = _container(result: _unmatched());
      c.read(setupModeProvider.notifier).enter();
      await tester.pumpWidget(_host(c));
      await tester.pumpAndSettle();

      expect(find.byType(RegistrationPanel), findsOneWidget);
      expect(find.byKey(const Key('start_registration')), findsNothing);
    });

    testWidgets('보유 수량 필드가 노출되고 CTA가 "등록하고 다음 병"이다', (tester) async {
      final c = _container(result: _unmatched());
      c.read(setupModeProvider.notifier).enter();
      await tester.pumpWidget(_host(c));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('initial_quantity_field')), findsOneWidget);
      expect(find.text('등록하고 다음 병'), findsOneWidget);
    });

    testWidgets('보유 수량과 바코드가 함께 전송되고 카운터가 오른다', (tester) async {
      final repo = _FakeWineRepo();
      final c = _container(result: _unmatched(), repo: repo);
      c.read(setupModeProvider.notifier).enter();
      await tester.pumpWidget(_host(c));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('producer_field')), 'A');
      await tester.enterText(find.byKey(const Key('model_name_field')), 'B');
      await tester.enterText(find.byKey(const Key('initial_quantity_field')), '6');
      await tester.pump();
      await tester.tap(find.byKey(const Key('registration_submit')));
      await tester.pumpAndSettle();

      expect(repo.calls.single['initialQuantity'], 6);
      expect(repo.calls.single['barcode'], 'NEW-9');
      expect(c.read(setupModeProvider).registeredCount, 1);
      expect(c.read(setupModeProvider).active, isTrue, reason: '모드는 유지된다');
    });

    testWidgets('수량을 비우면 마스터만 등록한다', (tester) async {
      final repo = _FakeWineRepo();
      final c = _container(result: _unmatched(), repo: repo);
      c.read(setupModeProvider.notifier).enter();
      await tester.pumpWidget(_host(c));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('producer_field')), 'A');
      await tester.enterText(find.byKey(const Key('model_name_field')), 'B');
      await tester.pump();
      await tester.tap(find.byKey(const Key('registration_submit')));
      await tester.pumpAndSettle();

      expect(repo.calls.single['initialQuantity'], isNull);
    });

    testWidgets('등록 후 같은 바코드를 다시 스캔할 수 있다', (tester) async {
      final c = _container(result: _unmatched());
      c.read(setupModeProvider.notifier).enter();
      final scan = c.read(scanControllerProvider.notifier);
      expect(scan.onDetected('NEW-9'), isTrue);

      await tester.pumpWidget(_host(c));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('producer_field')), 'A');
      await tester.enterText(find.byKey(const Key('model_name_field')), 'B');
      await tester.pump();
      await tester.tap(find.byKey(const Key('registration_submit')));
      await tester.pumpAndSettle();

      expect(scan.onDetected('NEW-9'), isTrue, reason: '다음 병으로 이어져야 한다');
    });
  });
}
