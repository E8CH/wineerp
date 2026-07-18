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

class ScanResult {
  const ScanResult({required this.code, required this.products});

  final String code;
  final List<WineProductRead> products;

  bool get isMatched => products.isNotEmpty;

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        code: json['code'] as String,
        products: ((json['products'] as List<dynamic>?) ?? [])
            .map((e) => WineProductRead.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
