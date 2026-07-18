import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

/// 홈 = 스캔 (FR3~5, Story 2.2+). 지금은 플레이스홀더.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '스캔',
      icon: Icons.qr_code_scanner,
      message: '바코드를 조준하면 입고가 시작됩니다.\n(스캔 기능은 곧 제공됩니다)',
    );
  }
}
