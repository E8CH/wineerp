import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../scan_controller.dart';
import 'scanner_frame.dart';

/// 풀블리드 카메라 + 조준 프레임. 인식 시 햅틱 + 스캔 상태 갱신(디바운스).
/// 실제 카메라는 실기기 필요(위젯 테스트 대상 아님).
class ScannerOverlay extends ConsumerStatefulWidget {
  const ScannerOverlay({super.key, this.onNewCode});

  /// 새 코드 인식 시 콜백(매칭 진입점 — Story 2.4에서 연결).
  final void Function(String code)? onNewCode;

  @override
  ConsumerState<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends ConsumerState<ScannerOverlay> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || code.isEmpty) continue;
      final isNew = ref.read(scanControllerProvider.notifier).onDetected(code);
      if (isNew) {
        HapticFeedback.mediumImpact();
        widget.onNewCode?.call(code);
      }
      break; // 한 프레임에 한 코드만 처리
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _PermissionError(error: error),
        ),
        const ScannerFrame(),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Text(
            '바코드를 프레임 안에 비추세요',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 17),
          ),
        ),
      ],
    );
  }
}

class _PermissionError extends StatelessWidget {
  const _PermissionError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, color: Colors.white70, size: 56),
              const SizedBox(height: 12),
              const Text(
                '카메라를 사용할 수 없습니다.\n권한을 허용한 뒤 다시 시도하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                error.errorCode.name,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
