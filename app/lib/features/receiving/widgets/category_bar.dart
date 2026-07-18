import 'package:flutter/material.dart';

/// 정보 그룹 좌측 컬러 바 (UX-DR9) — 네이비(식별)·마룬(라벨)·골드(재고).
class CategoryBar extends StatelessWidget {
  const CategoryBar({super.key, required this.color, this.width = 6});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width / 2),
      ),
    );
  }
}
