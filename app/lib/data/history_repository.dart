import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

enum HistoryPeriod {
  day('day', '일간'),
  week('week', '주간'),
  month('month', '월간');

  const HistoryPeriod(this.wire, this.label);

  final String wire;
  final String label;
}

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.producer,
    required this.modelName,
    required this.quantity,
    required this.receivedAt,
    required this.staffEmail,
    this.vintage,
    this.memo,
    this.representativeImageKey,
    this.amendedBy,
    this.source = 'receiving',
    this.modelArchived = false,
  });

  final String id;
  final String producer;
  final String modelName;
  final int? vintage; // null = NV
  final int quantity;
  final DateTime receivedAt;
  final String staffEmail;
  final String? memo;
  final String? representativeImageKey;

  /// 마지막으로 수정한 사람. `staffEmail`은 최초 입고자이므로, 이 값이 없으면
  /// 남이 고친 수량이 원 입고자 이름으로 표시된다(오귀속).
  final String? amendedBy;

  /// 'initial_setup'이면 초기 세팅분이다. 구분하지 않으면 작업자가
  /// "세팅으로 넣은 10병"을 "오늘 입고된 10병"으로 읽는다.
  final String source;

  /// 이 기록의 모델이 삭제(아카이브)됐는지. 삭제된 모델의 과거 입고는 원장으로 내역에
  /// 남지만 재고·카탈로그엔 없다 — 마커가 없으면 "재고엔 없는데 왜 내역엔 있지"가 된다.
  final bool modelArchived;

  bool get isInitialSetup => source == 'initial_setup';
  String get vintageLabel => vintage?.toString() ?? 'NV';
  bool get hasMemo => (memo ?? '').trim().isNotEmpty;
  bool get isAmended => (amendedBy ?? '').isNotEmpty;

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String,
        producer: json['producer'] as String,
        modelName: json['model_name'] as String,
        vintage: json['vintage'] as int?,
        quantity: json['quantity'] as int,
        // 서버는 UTC ISO 8601로 준다. 표시 변환은 클라이언트 몫(아키텍처 Format Patterns).
        receivedAt: DateTime.parse(json['received_at'] as String).toLocal(),
        staffEmail: json['staff_email'] as String,
        memo: json['memo'] as String?,
        representativeImageKey: json['representative_image_key'] as String?,
        amendedBy: json['amended_by'] as String?,
        source: json['source'] as String? ?? 'receiving',
        modelArchived: json['model_archived'] as bool? ?? false,
      );
}

class HistoryRepository {
  HistoryRepository(this._dio);

  final Dio _dio;

  Future<List<HistoryItem>> list(HistoryPeriod period) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/receiving',
      queryParameters: {'period': period.wire},
    );
    final data = (resp.data?['data'] as List<dynamic>?) ?? [];
    return data
        .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(dioProvider)),
);

final historyPeriodProvider =
    StateProvider<HistoryPeriod>((ref) => HistoryPeriod.day);

/// 선택된 기간의 입고 내역. 기간이 바뀌면 자동으로 다시 조회한다.
final historyProvider = FutureProvider<List<HistoryItem>>((ref) {
  final period = ref.watch(historyPeriodProvider);
  return ref.watch(historyRepositoryProvider).list(period);
});

/// 입고 수정·취소 (FR8, Story 4.2).
class ReceivingAmendRepository {
  ReceivingAmendRepository(this._dio);

  final Dio _dio;

  Future<void> updateQuantity(
    String recordId, {
    required int quantity,
    String? reason,
  }) async {
    await _dio.patch<Map<String, dynamic>>(
      '/receiving/$recordId',
      data: {'quantity': quantity, 'reason': ?reason},
    );
  }

  /// 취소는 서버에서 soft-delete로 처리되며 **manager 전용**이다(403 가능).
  Future<void> cancel(String recordId) async {
    await _dio.delete<Map<String, dynamic>>('/receiving/$recordId');
  }
}

final receivingAmendRepositoryProvider = Provider<ReceivingAmendRepository>(
  (ref) => ReceivingAmendRepository(ref.watch(dioProvider)),
);
