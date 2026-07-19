import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/history_repository.dart';
import 'widgets/amend_sheet.dart';
import 'widgets/history_row.dart';
import 'widgets/history_skeleton.dart';

/// 입고 내역 (FR9, UX-DR12) — 일/주/월 세그먼트 + 목록.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(historyPeriodProvider);
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('입고 내역')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<HistoryPeriod>(
              key: const Key('period_segments'),
              segments: [
                for (final p in HistoryPeriod.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {period},
              onSelectionChanged: (s) =>
                  ref.read(historyPeriodProvider.notifier).state = s.first,
            ),
          ),
          Expanded(
            child: history.when(
              loading: () => const HistorySkeleton(),
              error: (_, _) => const _ErrorState(),
              data: (items) => items.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(historyProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => HistoryRow(
                          item: items[i],
                          onTap: () => _openAmendSheet(context, ref, items[i]),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 행을 탭하면 수정 시트. 저장·취소 후 목록을 갱신한다.
Future<void> _openAmendSheet(
  BuildContext context,
  WidgetRef ref,
  HistoryItem item,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => AmendSheet(
      item: item,
      onDone: () {
        Navigator.of(ctx).pop();
        ref.invalidate(historyProvider);
      },
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    // 빈 상태는 안내 + 시작 유도(UX 사양). 막다른 화면을 만들지 않는다.
    return Center(
      key: const Key('history_empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            '이 기간에 입고된 기록이 없습니다',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            '스캔 탭에서 병을 찍으면 여기에 쌓입니다',
            style: TextStyle(color: AppColors.muted),
          ),
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
      key: Key('history_error'),
      child: Text('내역을 불러오지 못했습니다 · 당겨서 새로고침'),
    );
  }
}
