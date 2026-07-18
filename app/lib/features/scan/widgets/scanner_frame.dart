import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// 조준 프레임 — 골드 코너 브래킷(카메라 위에 오버레이). 순수 위젯(카메라 비의존, 테스트 가능).
class ScannerFrame extends StatelessWidget {
  const ScannerFrame({super.key, this.size = 240, this.color = AppColors.categoryStock});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CornerBracketPainter(color: color),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  _CornerBracketPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const len = 28.0;
    final w = size.width;
    final h = size.height;

    // 좌상
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    // 우상
    canvas.drawLine(Offset(w, 0), Offset(w - len, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // 좌하
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - len), paint);
    // 우하
    canvas.drawLine(Offset(w, h), Offset(w - len, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) => oldDelegate.color != color;
}
