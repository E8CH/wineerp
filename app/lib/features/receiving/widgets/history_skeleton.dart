import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// 리스트 로딩은 스켈레톤이다 — 빈 화면 금지(UX 사양 Additional Patterns).
class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('history_skeleton'),
      padding: const EdgeInsets.all(12),
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
