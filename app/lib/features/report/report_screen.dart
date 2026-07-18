import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

/// 리포트 = 그래프·엑셀 (FR10,11, Story 5.x, 관리자 전용). 지금은 플레이스홀더.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '리포트',
      icon: Icons.bar_chart,
      message: '기간별 입고 리포트가 여기에 표시됩니다.',
    );
  }
}
