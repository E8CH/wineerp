import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

/// 재고 = 와인 마스터/현재고 (후속). 지금은 플레이스홀더.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '재고',
      icon: Icons.wine_bar,
      message: '보유 와인 재고가 여기에 표시됩니다.',
    );
  }
}
