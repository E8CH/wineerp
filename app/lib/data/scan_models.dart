/// 스캔 매칭 응답 모델 (FR5). 와이어 snake_case → Dart camelCase 매핑.
class WineVintageRead {
  const WineVintageRead({
    required this.id,
    this.vintage,
    this.lwin11,
    this.representativeImageKey,
  });

  final String id;
  final int? vintage;
  final String? lwin11;
  final String? representativeImageKey;

  factory WineVintageRead.fromJson(Map<String, dynamic> json) => WineVintageRead(
        id: json['id'] as String,
        vintage: json['vintage'] as int?,
        lwin11: json['lwin11'] as String?,
        representativeImageKey: json['representative_image_key'] as String?,
      );
}

class WineProductRead {
  const WineProductRead({
    required this.id,
    required this.producer,
    required this.modelName,
    this.region,
    this.country,
    this.grape,
    this.lwin7,
    this.vintages = const [],
  });

  final String id;
  final String producer;
  final String modelName;
  final String? region;
  final String? country;
  final String? grape;
  final String? lwin7;
  final List<WineVintageRead> vintages;

  factory WineProductRead.fromJson(Map<String, dynamic> json) => WineProductRead(
        id: json['id'] as String,
        producer: json['producer'] as String,
        modelName: json['model_name'] as String,
        region: json['region'] as String?,
        country: json['country'] as String?,
        grape: json['grape'] as String?,
        lwin7: json['lwin7'] as String?,
        vintages: ((json['vintages'] as List<dynamic>?) ?? [])
            .map((e) => WineVintageRead.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 후보 1건 = (제품, 빈티지) 쌍. 바코드는 빈티지를 구분하지 못하므로(AR3)
/// 사용자가 라벨을 보고 이 중 하나를 확정한다.
class VintageCandidate {
  const VintageCandidate({required this.product, this.vintage});

  final WineProductRead product;

  /// null = 해당 제품에 등록된 빈티지 행이 없음(NV와 다름 — NV는 vintage.vintage가 null).
  final WineVintageRead? vintage;

  /// 선택 비교용 키. `WineVintageRead`에 `==`/`hashCode`가 없어 객체 동등성에 의존할 수 없다.
  String get id => vintage?.id ?? 'product:${product.id}';

  int? get year => vintage?.vintage;

  /// 빈티지 행이 있으면 연도 또는 NV, 없으면 미등록.
  /// NV(Non-Vintage)는 인식 실패가 아니라 1급 유효 상태다 — 오류로 표시하지 말 것.
  String get vintageLabel =>
      vintage == null ? '빈티지 미등록' : (year?.toString() ?? 'NV');

  /// 빈티지 행이 없으면 입고 대상이 될 수 없다(receiving_records가 wine_vintage_id를 요구).
  bool get isSelectable => vintage != null;
}

class ScanResult {
  const ScanResult({required this.code, required this.products});

  final String code;
  final List<WineProductRead> products;

  bool get isMatched => products.isNotEmpty;

  /// 제품×빈티지를 평탄화한 후보 목록. 서버 정렬(최신 우선·NV 최후)을 그대로 보존한다.
  /// 빈티지가 없는 제품도 후보로 남긴다 — 빼면 스캔 결과가 조용히 사라진다.
  List<VintageCandidate> get candidates => [
        for (final p in products)
          if (p.vintages.isEmpty)
            VintageCandidate(product: p)
          else
            for (final v in p.vintages)
              VintageCandidate(product: p, vintage: v),
      ];

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        code: json['code'] as String,
        products: ((json['products'] as List<dynamic>?) ?? [])
            .map((e) => WineProductRead.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
