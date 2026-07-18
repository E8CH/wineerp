import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/data/scan_models.dart';
import 'package:wineerp_app/features/receiving/widgets/receiving_confirm_card.dart';

void main() {
  test('ScanResult.fromJson: snake_case 매핑 + NV(null) 빈티지', () {
    final json = {
      'code': '3760000000015',
      'products': [
        {
          'id': 'p1',
          'producer': 'Château Margaux',
          'model_name': 'Château Margaux',
          'region': 'Margaux',
          'country': 'France',
          'grape': 'Cabernet Sauvignon',
          'lwin7': '1011531',
          'vintages': [
            {'id': 'v1', 'vintage': 2015, 'lwin11': null, 'representative_image_key': null},
            {'id': 'v2', 'vintage': null, 'lwin11': null, 'representative_image_key': 'labels/x.jpg'},
          ],
        },
      ],
    };
    final result = ScanResult.fromJson(json);
    expect(result.isMatched, isTrue);
    expect(result.products.single.modelName, 'Château Margaux');
    expect(result.products.single.vintages[0].vintage, 2015);
    expect(result.products.single.vintages[1].vintage, isNull); // NV
    expect(result.products.single.vintages[1].representativeImageKey, 'labels/x.jpg');
  });

  test('미매칭 결과', () {
    final result = ScanResult.fromJson({'code': 'x', 'products': []});
    expect(result.isMatched, isFalse);
  });

  testWidgets('ReceivingConfirmCard: 모델명·빈티지 표시', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReceivingConfirmCard(
            modelName: 'Château Margaux',
            producer: 'Château Margaux',
            vintage: 2018,
          ),
        ),
      ),
    );
    expect(find.text('Château Margaux'), findsWidgets);
    expect(find.text('빈티지 2018'), findsOneWidget);
  });

  testWidgets('ReceivingConfirmCard: NV 표시', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReceivingConfirmCard(
            modelName: 'Moët Impérial',
            producer: 'Moët & Chandon',
            vintage: null,
          ),
        ),
      ),
    );
    expect(find.text('빈티지 NV'), findsOneWidget);
  });
}
