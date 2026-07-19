import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/report_repository.dart';

/// 기간별 입고 막대 (UX-DR11) — 최대값은 골드, 나머지는 네이비.
///
/// 차트 라이브러리를 쓰지 않는 이유: 요구는 막대 하나와 빈 상태다. `fl_chart`는
/// 자체 테마·축 체계를 들고 와 네이비 디자인 토큰과 싸우고 이 요구에는 과하다.
/// 축·툴팁·다중 시리즈가 필요해지면 그때 재검토한다.
///
/// 값 0인 날도 자리를 차지한다 — 빼면 막대가 붙어 그려지고 보는 사람은
/// "매일 들어왔다"고 읽는다.
class ReportBarChart extends StatelessWidget {
  const ReportBarChart({super.key, required this.buckets, this.height = 180});

  final List<DayBucket> buckets;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();
    final peak = buckets.map((b) => b.quantity).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 막대가 많은 달(31일)에서도 가로 스크롤 없이 들어가도록 폭을 나눈다.
          final slot = constraints.maxWidth / buckets.length;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final b in buckets)
                SizedBox(
                  width: slot,
                  child: _Bar(
                    bucket: b,
                    peak: peak,
                    isPeak: peak > 0 && b.quantity == peak,
                    showLabel: slot >= 18,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.bucket,
    required this.peak,
    required this.isPeak,
    required this.showLabel,
  });

  final DayBucket bucket;
  final int peak;
  final bool isPeak;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ratio = peak == 0 ? 0.0 : bucket.quantity / peak;
    return Semantics(
      label: '${bucket.date} ${bucket.quantity}병',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 피크를 색만으로 전달하지 않는다 — 수치를 함께 띄운다(UX-DR15).
            if (isPeak)
              Text(
                '${bucket.quantity}',
                key: const Key('peak_label'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.categoryStock,
                ),
              ),
            const SizedBox(height: 2),
            Expanded(
              child: FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                // 0도 실선으로 보이게 최소 높이를 준다(없는 날과 렌더 실패를 구분).
                heightFactor: ratio == 0 ? 0.012 : ratio.clamp(0.03, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: bucket.quantity == 0
                        ? AppColors.background
                        : (isPeak ? AppColors.categoryStock : AppColors.navy),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (showLabel)
              Text(
                bucket.dayLabel,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}
