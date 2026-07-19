import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/scan_models.dart';
import '../../data/scan_repository.dart';
import '../receiving/widgets/candidate_list.dart';
import '../receiving/widgets/receiving_panel.dart';
import 'scan_controller.dart';
import 'widgets/scanner_overlay.dart';

/// 홈 = 스캔 (FR3·FR5). 카메라 인식 → /scan 매칭 → 확인 카드 / 미매칭 안내.
class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  Future<void> _match(WidgetRef ref, String code) async {
    ref.read(matchProvider.notifier).state = const AsyncLoading();
    // 다음 병으로 넘어갈 때 이전 선택이 남으면 안 된다 — matchProvider는 루트
    // 프로바이더라 자동 리셋되지 않으므로 명시적으로 지운다.
    ref.read(selectedCandidateProvider.notifier).state = null;
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

class _MatchResult extends ConsumerWidget {
  const _MatchResult({required this.match});

  final AsyncValue<ScanResult?> match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        final candidates = result.candidates;
        if (candidates.isEmpty) return const _UnregisteredCard();

        // 후보가 하나뿐이면 고를 것이 없으므로 확인 카드로 직행한다.
        // 둘 이상이면 반드시 사람이 라벨을 보고 고른다 — "최신 빈티지" 같은
        // 기본 선택으로 탭을 줄이는 최적화는 이 화면의 목적을 무효화한다.
        if (candidates.length == 1) {
          return _ConfirmFor(candidate: candidates.single, canReselect: false);
        }

        final selectedId = ref.watch(selectedCandidateProvider);
        if (selectedId == null) {
          return CandidateList(
            candidates: candidates,
            onSelect: (c) =>
                ref.read(selectedCandidateProvider.notifier).state = c.id,
            onNotListed: () =>
                ref.read(matchProvider.notifier).state = AsyncData(
              ScanResult(code: result.code, products: const []),
            ),
          );
        }

        final selected = candidates.firstWhere(
          (c) => c.id == selectedId,
          orElse: () => candidates.first,
        );
        return _ConfirmFor(candidate: selected, canReselect: true);
      },
    );
  }
}

class _UnregisteredCard extends StatelessWidget {
  const _UnregisteredCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.help_outline),
        title: Text('미등록 와인'),
        subtitle: Text('새로 등록하시겠습니까? (신규 등록은 곧 제공)'),
      ),
    );
  }
}

/// 확정된 후보 → 수량 → [완료]. 오선택 시 즉시 목록으로 되돌아갈 수 있어야 한다.
class _ConfirmFor extends ConsumerWidget {
  const _ConfirmFor({required this.candidate, required this.canReselect});

  final VintageCandidate candidate;
  final bool canReselect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 빈티지 행이 없는 제품은 입고 대상이 될 수 없다(wine_vintage_id 부재).
    if (!candidate.isSelectable) return const _UnregisteredCard();

    return ReceivingPanel(
      candidate: candidate,
      onReselect: canReselect
          ? () => ref.read(selectedCandidateProvider.notifier).state = null
          : null,
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
