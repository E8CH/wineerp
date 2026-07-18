import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'scan_controller.dart';
import 'widgets/scanner_overlay.dart';

/// 홈 = 스캔 (FR3). 카메라로 바코드를 자동 인식(매칭은 Story 2.4에서 연결).
class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(scanControllerProvider);
    final cameraEnabled = ref.watch(cameraEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('스캔')),
      body: Stack(
        children: [
          if (cameraEnabled)
            const ScannerOverlay()
          else
            const _CameraPlaceholder(),
          if (scan.lastCode != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Card(
                color: AppColors.container,
                child: ListTile(
                  leading: const Icon(Icons.qr_code, color: AppColors.navy),
                  title: Text('인식됨: ${scan.lastCode}'),
                  subtitle: const Text('매칭 기능은 곧 제공됩니다.'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          '카메라 미리보기',
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}
