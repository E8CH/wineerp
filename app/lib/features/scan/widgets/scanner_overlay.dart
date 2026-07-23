import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme.dart';
import '../scan_controller.dart';
import '../stability_gate.dart';
import 'scanner_frame.dart';

/// 풀블리드 카메라 + 조준 프레임.
///
/// 바코드가 **안정적으로** 인식되면(연속 프레임 확인) 카메라를 홀드하고, 그 순간의
/// 프레임을 정지 사진으로 붙들어 확인이 끝날 때까지 유지한다. 라이브 카메라가 확인 패널
/// 뒤에서 계속 돌지 않으므로, 와인 A를 확인하는 중 옆 병 B가 프레임에 들어와 A의 자리에
/// B가 기록되던 결함군이 원천 제거된다(기존 `_match`의 여러 방어가 막던 바로 그 문제).
class ScannerOverlay extends ConsumerStatefulWidget {
  const ScannerOverlay({super.key, this.onNewCode, this.onRescan});

  /// 새 코드가 **안정 확정**됐을 때(매칭 진입점 — Story 2.4).
  final void Function(String code)? onNewCode;

  /// 홀드를 풀고 다시 스캔하려 할 때. 확인 화면에 갇히지 않기 위한 탈출구.
  /// 호출부가 스캔 상태 전체를 비우면(`ScanController.reset`) 카메라가 자동 재개된다.
  final VoidCallback? onRescan;

  @override
  ConsumerState<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends ConsumerState<ScannerOverlay> {
  // ⚠️ DetectionSpeed.noDuplicates를 쓰지 말 것.
  // 그 중복 제거는 네이티브 계층에 있고 컨트롤러 수명 동안 마지막 값을 붙들기 때문에,
  // 입고 완료 후 `ScanController.reset()`을 해도 **같은 와인 두 번째 병이 인식되지 않는다**.
  // 안정성은 `StabilityGate`(연속 인식)로, 디바운스는 `ScanController`로 관리한다.
  //
  // returnImage: 안정 확정 순간의 프레임을 정지 사진으로 얻기 위함. 매 프레임 인코딩
  // 비용이 있으나, 홀드 화면에 "무엇을 찍었는지"를 남기는 UX가 이를 정당화한다.
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: true,
  );
  final StabilityGate _gate = StabilityGate(threshold: 2);

  /// 이 브랜치가 화면에 보이는지. `StatefulShellRoute.indexedStack`은 다른 탭의
  /// 브랜치를 마운트한 채로 두므로, 이것 없이는 재고·리포트 탭에 있는 동안에도 카메라가
  /// 돌며 프레임에 들어온 라벨로 매칭을 바꿔놓는다. 오프스테이지는 ticker가 뮤트된다.
  bool _visible = true;

  /// 홀드 중인지 + 홀드 순간의 정지 프레임. `_held`인 동안 카메라는 멈춰 있다.
  bool _held = false;
  Uint8List? _frozenFrame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (!visible) {
      unawaited(_controller.stop());
    } else if (!_held) {
      // 홀드 중이면 정지 프레임을 유지한다 — 탭을 다녀와도 카메라를 재개하지 않는다.
      unawaited(_controller.start());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 다음 병을 위해 홀드를 풀고 카메라를 재개한다.
  void _resume() {
    _gate.reset();
    setState(() {
      _held = false;
      _frozenFrame = null;
    });
    if (_visible) unawaited(_controller.start());
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_visible || _held) return; // 이미 홀드 중이면 무시(카메라도 멈춰 있다)
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || code.isEmpty) continue;
      if (!_gate.observe(code)) break; // 아직 안정 아님 — 더 지켜본다
      // 안정 확정 — 홀드 + 정지 프레임. 게이트가 안정성을 이미 판정했으므로 여기서
      // 확정하고, onDetected는 리셋 감지용 lastCode를 세팅하는 역할만 한다.
      ref.read(scanControllerProvider.notifier).onDetected(code);
      HapticFeedback.mediumImpact();
      setState(() {
        _held = true;
        _frozenFrame = capture.image; // null이면 잠금 표시만 (아래 _FrozenFrame)
      });
      unawaited(_controller.stop());
      widget.onNewCode?.call(code);
      break; // 한 프레임에 한 코드만
    }
  }

  @override
  Widget build(BuildContext context) {
    // 스캔 루프가 리셋되면(완료·재스캔·모드전환) 홀드를 풀고 카메라를 재개한다.
    ref.listen(scanControllerProvider, (prev, next) {
      if (next.lastCode == null && _held) _resume();
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_held)
          _FrozenFrame(bytes: _frozenFrame)
        else
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _PermissionError(error: error),
          ),
        // 잠기면 프레임을 초록으로 — 색만으로 전달하지 않도록 안내 문구도 함께 바꾼다.
        ScannerFrame(
          color: _held ? AppColors.success : AppColors.categoryStock,
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 24,
          child: Center(
            child: _held
                ? TextButton.icon(
                    key: const Key('rescan_button'),
                    onPressed: widget.onRescan,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black54,
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 스캔'),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Text(
            _held ? '인식됨 · 아래에서 확인하세요' : '바코드를 프레임 안에 비추세요',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 17),
          ),
        ),
      ],
    );
  }
}

/// 안정 인식 순간의 정지 프레임. 프레임 바이트가 없으면(returnImage 미제공 등) 잠금
/// 표시만 보여준다 — 라이브 카메라로 되돌아가 홀드가 무의미해지지 않게 한다.
class _FrozenFrame extends StatelessWidget {
  const _FrozenFrame({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final frame = bytes;
    if (frame != null) {
      return Image.memory(
        frame,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _LockedPlaceholder(),
      );
    }
    return const _LockedPlaceholder();
  }
}

class _LockedPlaceholder extends StatelessWidget {
  const _LockedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Icon(Icons.check_circle, color: AppColors.success, size: 72),
      ),
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
