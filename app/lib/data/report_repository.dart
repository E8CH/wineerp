import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 리포트 기간. 일간은 막대가 하나뿐이라 그래프의 의미가 없어 제외한다.
enum ReportPeriod {
  week('week', '주간'),
  month('month', '월간');

  const ReportPeriod(this.wire, this.label);

  final String wire;
  final String label;
}

class DayBucket {
  const DayBucket({required this.date, required this.quantity});

  final String date; // KST 로컬 날짜 YYYY-MM-DD
  final int quantity;

  /// 축 라벨용 일(day) 숫자.
  String get dayLabel => date.split('-').last.replaceFirst(RegExp(r'^0'), '');

  factory DayBucket.fromJson(Map<String, dynamic> j) => DayBucket(
        date: j['date'] as String,
        quantity: j['quantity'] as int,
      );
}

class TopProduct {
  const TopProduct({
    required this.modelName,
    required this.producer,
    required this.quantity,
  });

  final String modelName;
  final String producer;
  final int quantity;

  factory TopProduct.fromJson(Map<String, dynamic> j) => TopProduct(
        modelName: j['model_name'] as String,
        producer: j['producer'] as String,
        quantity: j['quantity'] as int,
      );
}

class ReceivingReport {
  const ReceivingReport({
    required this.buckets,
    required this.topProducts,
    required this.totalQuantity,
    required this.recordCount,
    required this.distinctWines,
  });

  final List<DayBucket> buckets;
  final List<TopProduct> topProducts;
  final int totalQuantity;
  final int recordCount;
  final int distinctWines;

  bool get isEmpty => totalQuantity == 0;

  factory ReceivingReport.fromJson(Map<String, dynamic> j) => ReceivingReport(
        buckets: ((j['buckets'] as List<dynamic>?) ?? [])
            .map((e) => DayBucket.fromJson(e as Map<String, dynamic>))
            .toList(),
        topProducts: ((j['top_products'] as List<dynamic>?) ?? [])
            .map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalQuantity: j['total_quantity'] as int? ?? 0,
        recordCount: j['record_count'] as int? ?? 0,
        distinctWines: j['distinct_wines'] as int? ?? 0,
      );
}

class ReportRepository {
  ReportRepository(this._dio);

  final Dio _dio;

  Future<ReceivingReport> fetch(ReportPeriod period) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/reports/receiving',
      queryParameters: {'period': period.wire},
    );
    return ReceivingReport.fromJson(resp.data!);
  }
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(dioProvider)),
);

final reportPeriodProvider =
    StateProvider<ReportPeriod>((ref) => ReportPeriod.week);

final reportProvider = FutureProvider<ReceivingReport>((ref) {
  final period = ref.watch(reportPeriodProvider);
  return ref.watch(reportRepositoryProvider).fetch(period);
});
