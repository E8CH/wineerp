import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/image_upload_service.dart';
import 'package:wineerp_app/data/inference_repository.dart';
import 'package:wineerp_app/data/inventory_repository.dart';
import 'package:wineerp_app/data/wine_repository.dart';
import 'package:wineerp_app/features/registration/registration_controller.dart';
import 'package:wineerp_app/features/registration/registration_panel.dart';

/// Story 3.2 — 신규 와인 등록 (FR6, UX-DR8).
class _FakeUpload extends ImageUploadService {
  _FakeUpload() : super(Dio());

  @override
  Future<ImageUploadResult> upload(List<int> bytes, {String filename = 'label.jpg'}) async =>
      const ImageUploadResult(key: 'labels/x.jpg', url: 'http://x/labels/x.jpg');
}

class _FakeInference extends InferenceRepository {
  _FakeInference(this._result) : super(Dio());

  final InferenceResult _result;

  @override
  Future<InferenceResult> inferLabel(String imageKey) async => _result;
}

class _FakeWineRepo extends WineRepository {
  _FakeWineRepo() : super(Dio());

  Map<String, dynamic>? lastCall;

  @override
  Future<WineCreated> create({
    required String producer,
    required String modelName,
    int? vintage,
    String? barcode,
    String? representativeImageKey,
    int? initialQuantity,
  }) async {
    lastCall = {
      'producer': producer,
      'modelName': modelName,
      'vintage': vintage,
      'barcode': barcode,
      'imageKey': representativeImageKey,
      'initialQuantity': initialQuantity,
    };
    return const WineCreated(productId: 'p1', vintageId: 'v1');
  }
}

ProviderContainer _container({
  InferenceResult inference = const InferenceResult(
    modelName: 'Château Test',
    confidence: 0.9,
  ),
  _FakeWineRepo? wineRepo,
  bool cameraCancels = false,
}) {
  final c = ProviderContainer(overrides: [
    imageUploadServiceProvider.overrideWithValue(_FakeUpload()),
    inferenceRepositoryProvider.overrideWithValue(_FakeInference(inference)),
    wineRepositoryProvider.overrideWithValue(wineRepo ?? _FakeWineRepo()),
    labelPickerProvider.overrideWithValue(
      () async => cameraCancels ? null : <int>[1, 2, 3],
    ),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c, {String? barcode, ValueChanged<String>? onDone}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RegistrationPanel(
              barcode: barcode,
              onRegistered: onDone ?? (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  group('라벨 사진 필수', () {
    testWidgets('사진 전에는 입력·등록이 노출되지 않는다', (tester) async {
      await tester.pumpWidget(_host(_container()));
      expect(find.byKey(const Key('capture_label_button')), findsOneWidget);
      expect(find.byKey(const Key('registration_submit')), findsNothing);
      expect(find.byKey(const Key('infer_button')), findsNothing);
    });

    testWidgets('촬영을 취소하면 진행되지 않는다', (tester) async {
      final c = _container(cameraCancels: true);
      await tester.pumpWidget(_host(c));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();
      expect(c.read(registrationControllerProvider).hasPhoto, isFalse);
      expect(find.byKey(const Key('registration_submit')), findsNothing);
    });

    testWidgets('촬영 후 입력·등록이 열린다', (tester) async {
      await tester.pumpWidget(_host(_container()));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('registration_submit')), findsOneWidget);
    });
  });

  group('AI 추론 (SM-C2)', () {
    testWidgets('추론 결과에 "AI 추론" 태그가 붙고 필드는 편집 가능하다', (tester) async {
      await tester.pumpWidget(_host(_container()));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('infer_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_tag')), findsOneWidget);
      final field = tester.widget<TextField>(find.byKey(const Key('model_name_field')));
      expect(field.enabled, isNot(false), reason: '자동 채운 값은 항상 수정 가능해야 한다');
    });

    testWidgets('저신뢰는 색이 아니라 아이콘·문구로도 경고한다', (tester) async {
      await tester.pumpWidget(_host(_container(
        inference: const InferenceResult(
          modelName: 'Ch. Blur',
          confidence: 0.3,
          lowConfidence: true,
        ),
      )));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('infer_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('low_confidence_tag')), findsOneWidget);
      expect(find.textContaining('자신 없는 추론'), findsOneWidget);
    });

    testWidgets('사용자가 고치면 AI 태그가 내려간다', (tester) async {
      final c = _container();
      await tester.pumpWidget(_host(c));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('infer_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('model_name_field')), '직접 고침');
      await tester.pump();
      expect(find.byKey(const Key('ai_tag')), findsNothing);
    });

    testWidgets('추론 실패는 수동 입력 안내로 이어진다 (500이 아니다)', (tester) async {
      await tester.pumpWidget(_host(_container(
        inference: const InferenceResult(failed: true, needsManualInput: true),
      )));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('infer_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('직접 입력'), findsWidgets);
    });

    testWidgets('[직접입력]은 추론 대기 중에도 눌린다', (tester) async {
      // 폴백은 실패 후가 아니라 처음부터 보인다(UX-DR13, 차단 모달 금지).
      await tester.pumpWidget(_host(_container()));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();

      final manual = tester.widget<TextButton>(
        find.byKey(const Key('manual_input_button')),
      );
      expect(manual.onPressed, isNotNull);
    });
  });

  group('빈티지 / NV', () {
    testWidgets('NV 토글이 연도를 비활성화하고 null을 전송한다', (tester) async {
      final repo = _FakeWineRepo();
      final c = _container(wineRepo: repo);
      await tester.pumpWidget(_host(c));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('producer_field')), 'Moët');
      await tester.enterText(find.byKey(const Key('model_name_field')), 'Impérial');
      await tester.enterText(find.byKey(const Key('vintage_field')), '2018');
      await tester.pump();

      await tester.tap(find.byKey(const Key('nv_toggle')));
      await tester.pumpAndSettle();

      final vintageField =
          tester.widget<TextField>(find.byKey(const Key('vintage_field')));
      expect(vintageField.enabled, isFalse);

      await tester.tap(find.byKey(const Key('registration_submit')));
      await tester.pumpAndSettle();
      expect(repo.lastCall!['vintage'], isNull, reason: 'NV는 명시적 null이다');
    });

    testWidgets('연도를 입력하면 그대로 전송된다', (tester) async {
      final repo = _FakeWineRepo();
      await tester.pumpWidget(_host(_container(wineRepo: repo)));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('producer_field')), 'Penfolds');
      await tester.enterText(find.byKey(const Key('model_name_field')), 'Grange');
      await tester.enterText(find.byKey(const Key('vintage_field')), '2016');
      await tester.pump();
      await tester.tap(find.byKey(const Key('registration_submit')));
      await tester.pumpAndSettle();

      expect(repo.lastCall!['vintage'], 2016);
    });

    testWidgets('등록 성공 시 재고 리비전을 올린다(재고 탭 갱신)', (tester) async {
      // 새 마스터가 재고 목록에 즉시 나타나게 하는 배선. registration_controller의
      // bumpInventory(ref)를 지우면 이 단언만 깨진다.
      final c = _container(wineRepo: _FakeWineRepo());
      expect(c.read(inventoryRevisionProvider), 0);
      await tester.pumpWidget(_host(c));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('producer_field')), 'Penfolds');
      await tester.enterText(find.byKey(const Key('model_name_field')), 'Grange');
      await tester.pump();
      await tester.tap(find.byKey(const Key('registration_submit')));
      await tester.pumpAndSettle();

      expect(c.read(inventoryRevisionProvider), 1);
    });
  });

  group('등록', () {
    testWidgets('필수값이 비면 등록 버튼이 비활성이다', (tester) async {
      await tester.pumpWidget(_host(_container()));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('registration_submit')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('바코드와 사진 key가 함께 전송되고 결과 id가 콜백된다', (tester) async {
      final repo = _FakeWineRepo();
      String? got;
      await tester.pumpWidget(_host(
        _container(wineRepo: repo),
        barcode: 'NEW-123',
        onDone: (id) => got = id,
      ));
      await tester.tap(find.byKey(const Key('capture_label_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('producer_field')), 'A');
      await tester.enterText(find.byKey(const Key('model_name_field')), 'B');
      await tester.pump();
      await tester.tap(find.byKey(const Key('registration_submit')));
      await tester.pumpAndSettle();

      expect(repo.lastCall!['barcode'], 'NEW-123');
      expect(repo.lastCall!['imageKey'], 'labels/x.jpg');
      expect(got, 'v1', reason: '등록 직후 수량 입력으로 이어져야 한다');
    });
  });

  group('늦게 도착한 비동기 결과 (코드리뷰 C2·C3)', () {
    test('사용자가 직접 입력하면 진행 중이던 추론 결과를 버린다', () async {
      // 덮어쓰면 사용자가 친 글자가 사라지고 커서가 튄다.
      final c = _container(
        inference: const InferenceResult(modelName: 'AI 값', confidence: 0.9),
      );
      final ctrl = c.read(registrationControllerProvider.notifier);
      await ctrl.captureLabel();

      final infer = ctrl.inferModelName(); // 진행 중
      ctrl.setModelName('사용자가 친 값'); // 사용자가 필드를 가져간다
      await infer;

      expect(c.read(registrationControllerProvider).modelName, '사용자가 친 값');
      expect(c.read(registrationControllerProvider).isAiFilled, isFalse);
    });

    test('[직접입력] 후 도착한 추론 결과도 무시된다', () async {
      final c = _container(
        inference: const InferenceResult(modelName: 'AI 값', confidence: 0.9),
      );
      final ctrl = c.read(registrationControllerProvider.notifier);
      await ctrl.captureLabel();

      final infer = ctrl.inferModelName();
      ctrl.useManualInput();
      await infer;

      expect(c.read(registrationControllerProvider).isAiFilled, isFalse);
      expect(c.read(registrationControllerProvider).modelName, isEmpty);
    });

    test('다음 병으로 넘어간 뒤 도착한 업로드 결과는 버린다', () async {
      // 남으면 작업자가 찍지 않은 사진이 다음 병의 폼에 붙는다.
      final c = _container();
      final ctrl = c.read(registrationControllerProvider.notifier);

      final capture = ctrl.captureLabel();
      ctrl.reset(); // 다음 병
      await capture;

      expect(c.read(registrationControllerProvider).hasPhoto, isFalse);
    });
  });
}
