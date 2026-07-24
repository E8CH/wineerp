import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/audit_repository.dart';
import '../auth/auth_controller.dart';

/// 활동 로그 (감사) — **관리자 전용**.
///
/// 누가 데이터를 넣고·고치고·지웠는지 시간순으로 본다. 내역처럼 정보를 담되 카드가 아니라
/// **연속 리스트**다(변경 한 건 = 한 줄). 행을 누르면 상세 시트가 열린다.
///
/// 리포트와 같은 권한 경계: 서버도 403으로 막지만 UI에서도 막는다. UI만 숨기면 API가
/// 열려 있고, 서버만 막으면 staff가 빈 화면과 오류를 본다.
class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isManager = ref.watch(authControllerProvider).role == 'manager';
    if (!isManager) return const _AuditBlocked();

    final audit = ref.watch(auditProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('활동 로그'),
        actions: [
          IconButton(
            key: const Key('audit_refresh'),
            tooltip: '새로고침',
            onPressed: () => ref.invalidate(auditProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: audit.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _ErrorState(),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(auditProvider),
                // 카드가 아닌 연속 리스트: 얇은 구분선으로만 나눈다(요구사항).
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, thickness: 0.5),
                  itemBuilder: (_, i) => _AuditRow(item: items[i]),
                ),
              ),
      ),
    );
  }
}

/// 액션별 한글 라벨·색·아이콘. 서버 코드와 표기를 한 곳에서만 잇는다.
class _ActionMeta {
  const _ActionMeta(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;

  static const _fallback =
      _ActionMeta('변경', AppColors.muted, Icons.history);

  static _ActionMeta of(String action) => switch (action) {
        'receiving.create' =>
          const _ActionMeta('입고', AppColors.success, Icons.login),
        'receiving.amend' =>
          const _ActionMeta('수량 수정', AppColors.categoryStock, Icons.edit),
        'receiving.cancel' =>
          const _ActionMeta('입고 취소', AppColors.error, Icons.undo),
        'wine.create' =>
          const _ActionMeta('모델 등록', AppColors.navy, Icons.style),
        'wine.update' =>
          const _ActionMeta('모델 수정', AppColors.categoryStock, Icons.edit_note),
        'wine.archive' =>
          const _ActionMeta('모델 삭제', AppColors.categoryLabel, Icons.delete_outline),
        'wine.initial_setup' =>
          const _ActionMeta('초기재고', AppColors.categoryStock, Icons.inventory_2),
        _ => _fallback,
      };
}

String _formatTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.month)}.${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.item});

  final AuditItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _ActionMeta.of(item.action);
    return ListTile(
      onTap: () => _showAuditDetail(context, item),
      leading: CircleAvatar(
        backgroundColor: meta.color.withValues(alpha: 0.14),
        child: Icon(meta.icon, color: meta.color, size: 22),
      ),
      title: Text(
        item.summary,
        style: theme.textTheme.bodyLarge,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '${meta.label} · ${item.actorEmail} · ${_formatTime(item.createdAt)}',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
    );
  }
}

/// 상세 시트 — 요약 + 행위자·시각 + 액션별 세부(수량 변경, 필드 변경 등).
void _showAuditDetail(BuildContext context, AuditItem item) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AuditDetailSheet(item: item),
  );
}

class _AuditDetailSheet extends StatelessWidget {
  const _AuditDetailSheet({required this.item});

  final AuditItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _ActionMeta.of(item.action);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(meta.icon, color: meta.color),
                  const SizedBox(width: 8),
                  Text(meta.label, style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 12),
              Text(item.summary, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              _DetailRow(label: '작업자', value: item.actorEmail),
              _DetailRow(label: '시각', value: _formatTime(item.createdAt)),
              ..._detailRows(),
            ],
          ),
        ),
      ),
    );
  }

  /// 액션별 세부 행. detail JSON은 action마다 형태가 달라, 아는 키만 골라 표시한다.
  List<Widget> _detailRows() {
    final d = item.detail;
    final rows = <Widget>[];

    // 수량 변경(수정): before→after.
    if (d['before_quantity'] != null && d['after_quantity'] != null) {
      rows.add(_DetailRow(
        label: '수량',
        value: '${d['before_quantity']}병 → ${d['after_quantity']}병',
      ));
    } else if (d['quantity'] != null) {
      rows.add(_DetailRow(label: '수량', value: '${d['quantity']}병'));
    }

    // 메모 변경.
    final beforeMemo = (d['before_memo'] as String?)?.trim();
    final afterMemo = (d['after_memo'] as String?)?.trim();
    if ((beforeMemo ?? '').isNotEmpty || (afterMemo ?? '').isNotEmpty) {
      rows.add(_DetailRow(
        label: '메모',
        value: '${beforeMemo?.isNotEmpty == true ? beforeMemo : '(없음)'}'
            ' → ${afterMemo?.isNotEmpty == true ? afterMemo : '(없음)'}',
      ));
    } else if ((d['memo'] as String?)?.trim().isNotEmpty ?? false) {
      rows.add(_DetailRow(label: '메모', value: d['memo'] as String));
    }

    // 수정 사유.
    if ((d['reason'] as String?)?.trim().isNotEmpty ?? false) {
      rows.add(_DetailRow(label: '사유', value: d['reason'] as String));
    }

    // 모델 수정: 바뀐 필드만 before→after.
    final before = d['before'] as Map<String, dynamic>?;
    final after = d['after'] as Map<String, dynamic>?;
    if (before != null && after != null) {
      const labels = {
        'producer': '생산자',
        'model_name': '모델명',
        'region': '지역',
        'country': '국가',
        'grape': '품종',
      };
      for (final entry in labels.entries) {
        final b = before[entry.key];
        final a = after[entry.key];
        if (b != a) {
          rows.add(_DetailRow(
            label: entry.value,
            value: '${b ?? '(없음)'} → ${a ?? '(없음)'}',
          ));
        }
      }
    }
    return rows;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _AuditBlocked extends StatelessWidget {
  const _AuditBlocked();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('활동 로그')),
      body: const Center(
        key: Key('audit_forbidden'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: AppColors.muted),
            SizedBox(height: 12),
            Text('활동 로그는 관리자만 볼 수 있습니다'),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('audit_empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text('아직 기록된 활동이 없습니다',
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('audit_error'),
      child: Text('활동 로그를 불러오지 못했습니다 · 당겨서 새로고침'),
    );
  }
}
