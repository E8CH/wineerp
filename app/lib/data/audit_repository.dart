import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 활동 로그 1건 — 누가·언제·무엇을 넣고·고치고·지웠는지.
class AuditItem {
  const AuditItem({
    required this.id,
    required this.action,
    required this.actorEmail,
    required this.summary,
    required this.entityType,
    required this.createdAt,
    this.entityId,
    this.detail = const {},
  });

  final String id;

  /// 서버 액션 코드('receiving.create' 등). 한글 라벨·색은 화면에서 매핑한다 —
  /// 서버 문자열을 그대로 UI에 쓰면 코드와 표기가 한 곳에 얽힌다.
  final String action;

  /// 행위자 이메일. 서버가 시점 스냅샷으로 저장하므로, 나중에 개명·삭제돼도 흔들리지 않는다.
  final String actorEmail;

  /// 리스트에 한 줄로 뜨는 요약(예: "Château Margaux 2015 · 12병 입고").
  final String summary;
  final String entityType;
  final String? entityId;

  /// 상세 화면용 구조화 데이터(before/after, 수량, 메모 등). action마다 형태가 다르다.
  final Map<String, dynamic> detail;
  final DateTime createdAt;

  factory AuditItem.fromJson(Map<String, dynamic> json) => AuditItem(
        id: json['id'] as String,
        action: json['action'] as String,
        actorEmail: json['actor_email'] as String,
        summary: json['summary'] as String,
        entityType: json['entity_type'] as String,
        entityId: json['entity_id'] as String?,
        detail: (json['detail'] as Map<String, dynamic>?) ?? const {},
        // 서버는 UTC ISO 8601로 준다. 표시 변환은 클라이언트 몫(Format Patterns).
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

class AuditRepository {
  AuditRepository(this._dio);

  final Dio _dio;

  Future<List<AuditItem>> list() async {
    final resp = await _dio.get<Map<String, dynamic>>('/audit');
    final data = (resp.data?['data'] as List<dynamic>?) ?? [];
    return data
        .map((e) => AuditItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(ref.watch(dioProvider)),
);

/// 최근 활동 로그(최신순). 당겨서 새로고침으로 갱신한다.
final auditProvider = FutureProvider<List<AuditItem>>(
  (ref) => ref.watch(auditRepositoryProvider).list(),
);
