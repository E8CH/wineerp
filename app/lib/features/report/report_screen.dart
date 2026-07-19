import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/report_repository.dart';
import '../auth/auth_controller.dart';
import 'widgets/report_bar_chart.dart';

/// 종합 리포트 (FR10, UX-DR11) — **관리자 전용**.
///
/// 서버도 403으로 막지만 UI에서도 막는다. UI만 숨기면 API가 열려 있고,
/// 서버만 막으면 staff가 빈 화면과 오류를 본다.
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isManager = ref.watch(authControllerProvider).role == 'manager';
    if (!isManager) return const _StaffBlocked();

    final period = ref.watch(reportPeriodProvider);
    final report = ref.watch(reportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('리포트')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ReportPeriod>(
              key: const Key('report_period'),
              segments: [
                for (final p in ReportPeriod.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {period},
              onSelectionChanged: (s) =>
                  ref.read(reportPeriodProvider.notifier).state = s.first,
            ),
          ),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                key: Key('report_error'),
                child: Text('리포트를 불러오지 못했습니다'),
              ),
              data: (data) => data.isEmpty
                  ? const _EmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      children: [
                        _KpiRow(report: data),
                        const SizedBox(height: 16),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                            child: ReportBarChart(buckets: data.buckets),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _TopProducts(products: data.topProducts),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.report});

  final ReceivingReport report;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Kpi(label: '총 입고', value: '${report.totalQuantity}병'),
        _Kpi(label: '기록', value: '${report.recordCount}건'),
        _Kpi(label: '품목', value: '${report.distinctWines}종'),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColors.navy),
              ),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.products});

  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const ListTile(
            dense: true,
            title: Text('상위 품목', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          for (final p in products)
            ListTile(
              dense: true,
              title: Text(p.modelName),
              subtitle: Text(p.producer),
              trailing: Text(
                '${p.quantity}병',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('report_empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            '이 기간에 입고 데이터가 없습니다',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _StaffBlocked extends StatelessWidget {
  const _StaffBlocked();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('리포트')),
      body: const Center(
        key: Key('report_forbidden'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: AppColors.muted),
            SizedBox(height: 12),
            Text('리포트는 관리자만 볼 수 있습니다'),
          ],
        ),
      ),
    );
  }
}
