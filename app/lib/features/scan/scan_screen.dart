import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/scan_models.dart';
import '../../data/scan_repository.dart';
import '../receiving/widgets/receiving_confirm_card.dart';
import 'scan_controller.dart';
import 'widgets/scanner_overlay.dart';

/// 홈 = 스캔 (FR3·FR5). 카메라 인식 → /scan 매칭 → 확인 카드 / 미매칭 안내.
class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  Future<void> _match(WidgetRef ref, String code) async {
    ref.read(matchProvider.notifier).state = const AsyncLoading();
    try {
      final result = await ref.read(scanRepositoryProvider).scan(code);
      ref.read(matchProvider.notifier).state = AsyncData(result);
    } catch (e, st) {
      ref.read(matchProvider.notifier).state = AsyncError(e, st);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraEnabled = ref.watch(cameraEnabledProvider);
    final match = ref.watch(matchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('스캔')),
      body: Stack(
        children: [
          if (cameraEnabled)
            ScannerOverlay(onNewCode: (code) => _match(ref, code))
          else
            const _CameraPlaceholder(),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _MatchResult(match: match),
          ),
        ],
      ),
    );
  }
}

class _MatchResult extends StatelessWidget {
  const _MatchResult({required this.match});

  final AsyncValue<ScanResult?> match;

  @override
  Widget build(BuildContext context) {
    return match.when(
      loading: () => const Card(
        child: ListTile(
          leading: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('매칭 중…'),
        ),
      ),
      error: (e, _) => const Card(
        child: ListTile(
          leading: Icon(Icons.error_outline, color: Colors.red),
          title: Text('매칭 실패 · 다시 스캔하세요'),
        ),
      ),
      data: (result) {
        if (result == null) return const SizedBox.shrink();
        if (!result.isMatched) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.help_outline),
              title: Text('미등록 와인'),
              subtitle: Text('새로 등록하시겠습니까? (신규 등록은 곧 제공)'),
            ),
          );
        }
        final product = result.products.first;
        final vintage =
            product.vintages.isNotEmpty ? product.vintages.first.vintage : null;
        return ReceivingConfirmCard(
          modelName: product.modelName,
          producer: product.producer,
          vintage: vintage,
        );
      },
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
        child: Text('카메라 미리보기', style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}
