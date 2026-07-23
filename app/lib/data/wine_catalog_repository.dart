import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 카탈로그 상세의 빈티지 1건 (Story 7.x).
class VintageStock {
  const VintageStock({
    required this.vintageId,
    required this.stock,
    this.vintage,
    this.representativeImageKey,
  });

  final String vintageId;
  final int? vintage; // null = NV
  final int stock;
  final String? representativeImageKey;

  String get vintageLabel => vintage?.toString() ?? 'NV';

  factory VintageStock.fromJson(Map<String, dynamic> json) => VintageStock(
        vintageId: json['vintage_id'] as String,
        vintage: json['vintage'] as int?,
        stock: (json['stock'] as int?) ?? 0,
        representativeImageKey: json['representative_image_key'] as String?,
      );
}

/// 모델(제품) 카탈로그 카드 1장 = 한 WineProduct + 빈티지들 (Story 7.x).
class ProductCatalogItem {
  const ProductCatalogItem({
    required this.productId,
    required this.producer,
    required this.modelName,
    required this.totalStock,
    required this.vintages,
    required this.createdAt,
    this.region,
    this.country,
    this.grape,
    this.representativeImageKey,
  });

  final String productId;
  final String producer;
  final String modelName;
  final String? region;
  final String? country;
  final String? grape;
  final String? representativeImageKey;
  final int totalStock;
  final List<VintageStock> vintages;

  /// 모델 등록 시각(로컬 KST). 카드 표시 + 등록일 검색에 쓴다.
  final DateTime createdAt;

  /// 텍스트 검색 대상 — 모델명·생산자·지역·국가·품종을 한 줄로 이어 소문자 매칭한다.
  String get searchHaystack => [
        modelName,
        producer,
        region,
        country,
        grape,
      ].where((s) => (s ?? '').isNotEmpty).join(' ').toLowerCase();

  factory ProductCatalogItem.fromJson(Map<String, dynamic> json) =>
      ProductCatalogItem(
        productId: json['product_id'] as String,
        producer: json['producer'] as String,
        modelName: json['model_name'] as String,
        region: json['region'] as String?,
        country: json['country'] as String?,
        grape: json['grape'] as String?,
        representativeImageKey: json['representative_image_key'] as String?,
        totalStock: (json['total_stock'] as int?) ?? 0,
        // 서버는 UTC ISO 8601. 표시·필터는 로컬(KST)로 변환한다(입고 시각과 같은 규칙).
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        vintages: ((json['vintages'] as List<dynamic>?) ?? [])
            .map((e) => VintageStock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WineCatalogRepository {
  WineCatalogRepository(this._dio);

  final Dio _dio;

  Future<List<ProductCatalogItem>> list() async {
    final resp = await _dio.get<List<dynamic>>('/wines');
    final data = resp.data ?? [];
    return data
        .map((e) => ProductCatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 모델 메타 수정(manager 전용, 403 가능). 응답으로 갱신된 카드를 돌려준다.
  Future<ProductCatalogItem> update(
    String productId, {
    required String producer,
    required String modelName,
    String? region,
    String? country,
    String? grape,
  }) async {
    final resp = await _dio.patch<Map<String, dynamic>>(
      '/wines/$productId',
      data: {
        'producer': producer,
        'model_name': modelName,
        'region': region,
        'country': country,
        'grape': grape,
      },
    );
    return ProductCatalogItem.fromJson(resp.data!);
  }

  /// 모델 삭제 = 아카이브(manager 전용, 403 가능). 입고기록 원장은 서버가 보존한다.
  Future<void> delete(String productId) async {
    await _dio.delete<void>('/wines/$productId');
  }
}

final wineCatalogRepositoryProvider = Provider<WineCatalogRepository>(
  (ref) => WineCatalogRepository(ref.watch(dioProvider)),
);

/// 카탈로그를 다시 읽어야 할 때 올리는 리비전(수정·삭제 후). inventory와 같은 지연 평가
/// 패턴 — 탭이 구독 중일 때만 재조회가 돌고, 아니면 다음에 열 때 새 리비전으로 갱신된다.
final catalogRevisionProvider = StateProvider<int>((ref) => 0);

final catalogProvider = FutureProvider.autoDispose<List<ProductCatalogItem>>(
  (ref) {
    ref.watch(catalogRevisionProvider);
    return ref.watch(wineCatalogRepositoryProvider).list();
  },
);

/// 카탈로그 목록 무효화(다음 조회 시 새로고침). 리스너가 없으면 부작용 없다.
void bumpCatalog(Ref ref) =>
    ref.read(catalogRevisionProvider.notifier).state++;
