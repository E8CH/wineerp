import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 재고 목록 1행 = 한 빈티지(재고 단위) (Story 6.2).
class InventoryItem {
  const InventoryItem({
    required this.wineProductId,
    required this.producer,
    required this.modelName,
    required this.vintageId,
    required this.stock,
    this.vintage,
    this.region,
    this.country,
    this.grape,
    this.representativeImageKey,
  });

  final String wineProductId;
  final String producer;
  final String modelName;
  final String vintageId;
  final int? vintage; // null = NV (인식 실패가 아니라 유효 상태)
  final String? region;
  final String? country;
  final String? grape;
  final String? representativeImageKey;

  /// 현재고 = 입고 합계(서버 집계). 화면에서 다시 계산하지 말 것.
  final int stock;

  String get vintageLabel => vintage?.toString() ?? 'NV';

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        wineProductId: json['wine_product_id'] as String,
        producer: json['producer'] as String,
        modelName: json['model_name'] as String,
        vintageId: json['vintage_id'] as String,
        vintage: json['vintage'] as int?,
        region: json['region'] as String?,
        country: json['country'] as String?,
        grape: json['grape'] as String?,
        representativeImageKey: json['representative_image_key'] as String?,
        stock: (json['stock'] as int?) ?? 0,
      );
}

class InventoryRepository {
  InventoryRepository(this._dio);

  final Dio _dio;

  Future<List<InventoryItem>> list() async {
    final resp = await _dio.get<List<dynamic>>('/inventory');
    final data = resp.data ?? [];
    return data
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.watch(dioProvider)),
);

/// 재고를 다시 읽어야 할 때 올리는 리비전. 입고·등록 컨트롤러가 증가시킨다.
///
/// ⚠️ 컨트롤러에서 `ref.invalidate(inventoryProvider)`를 부르지 않는 이유: 재고 탭을
/// 보고 있지 않으면(리스너 없음) invalidate가 재계산·autoDispose 정리 **타이머**를
/// 예약하는데, 그 타이머가 무관한 테스트의 위젯 트리보다 오래 살아남아 "pending timer"로
/// 터진다. 리비전을 올리는 방식은 **지연 평가**다 — 탭이 구독 중일 때만 재조회가 돌고,
/// 아니면 다음에 탭을 열 때 새 리비전으로 자연히 갱신된다. 코드베이스가 이미 쓰는
/// 상태-증가 패턴(scan_controller의 provider.state 갱신)과도 결이 같다.
final inventoryRevisionProvider = StateProvider<int>((ref) => 0);

/// 현재고 목록. 재고 탭은 IndexedStack에 남아 계속 구독하므로 리비전이 오르면 갱신된다.
final inventoryProvider = FutureProvider.autoDispose<List<InventoryItem>>(
  (ref) {
    ref.watch(inventoryRevisionProvider);
    return ref.watch(inventoryRepositoryProvider).list();
  },
);

/// 재고 목록을 무효화(다음 조회 시 새로고침). 리스너가 없으면 아무 부작용도 없다.
void bumpInventory(Ref ref) =>
    ref.read(inventoryRevisionProvider.notifier).state++;
