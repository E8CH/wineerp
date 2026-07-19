import 'dart:async';

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
  // ⚠️ DetectionSpeed.noDuplicates를 쓰지 말 것.
  // 그 중복 제거는 네이티브 계층에 있고 컨트롤러 수명 동안 마지막 값을 붙들기 때문에,
  // 입고 완료 후 `ScanController.reset()`을 해도 **같은 와인 두 번째 병이 인식되지 않는다**
  // (앱 계층만 리셋되고 네이티브는 그대로). 같은 와인 여러 병은 가장 흔한 경우다.
  // 디바운스는 `ScanController._lastAccepted` 한 곳에서만 관리한다.
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

  /// 이 브랜치가 화면에 보이는지. `StatefulShellRoute.indexedStack`은 다른 탭의
  /// 브랜치를 마운트한 채로 두므로, 이것 없이는 재고·리포트 탭에 있는 동안에도
  /// 카메라가 돌며 프레임에 들어온 라벨로 `matchProvider`를 바꿔놓는다
  /// (탭 복귀 시 엉뚱한 확인 카드가 떠 있음). 배터리·프라이버시 문제이기도 하다.
  /// 오프스테이지 브랜치는 ticker가 뮤트되므로 새 의존성 없이 판별할 수 있다.
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    unawaited(visible ? _controller.start() : _controller.stop());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_visible) return; // 보이지 않는 동안의 인식은 버린다
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
