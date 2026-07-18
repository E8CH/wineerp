import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

/// 내역 = 일/주/월 입고 조회 (FR9, Story 4.1). 지금은 플레이스홀더.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '내역',
      icon: Icons.receipt_long,
      message: '입고 내역이 여기에 표시됩니다.',
    );
  }
}
