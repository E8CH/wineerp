import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/scan_models.dart';
import '../../data/scan_repository.dart';
import '../receiving/receiving_controller.dart';
import '../registration/registration_controller.dart';
import '../registration/registration_panel.dart';
import '../receiving/widgets/candidate_list.dart';
import '../receiving/widgets/receiving_panel.dart';
import 'scan_controller.dart';
import 'widgets/scanner_overlay.dart';

/// 홈 = 스캔 (FR3·FR5). 카메라 인식 → /scan 매칭 → 확인 카드 / 미매칭 안내.
class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  Future<void> _match(WidgetRef ref, String code) async {
    ref.read(matchProvider.notifier).state = const AsyncLoading();
    // 다음 병으로 넘어갈 때 이전 상태가 남으면 안 된다 — 셋 다 루트 프로바이더라
    // 자동 리셋되지 않는다.
    ref.read(selectedCandidateProvider.notifier).state = null;
    // ⚠️ 수량·오류도 반드시 함께 버린다. 확인 패널이 떠 있는 동안 카메라는 계속 살아
    // 있으므로, 와인 A에 12를 찍어둔 채 와인 B가 프레임에 들어오면 카드만 B로 바뀌고
    // 스테퍼는 12로 남는다 → [완료] 시 B가 12병 기록된다(조용한 오기록).
    ref.invalidate(receivingControllerProvider);
    ref.read(registeredCandidateProvider.notifier).state = null;
    ref.read(registeringProvider.notifier).state = false;
    try {
      final result = await ref.read(scanRepositoryProvider).scan(code);
      _set(ref, AsyncData(result));
    } catch (e, st) {
      _set(ref, AsyncError(e, st));
    }
  }

  /// 위젯이 이미 dispose된 뒤(로그아웃 등)에는 `ref`가 StateError를 던진다.
  /// catch 블록에서 그대로 쓰면 그 StateError가 uncaught로 새어나간다.
  static void _set(WidgetRef ref, AsyncValue<ScanResult?> value) {
    try {
      ref.read(matchProvider.notifier).state = value;
    } on StateError {
      // 화면이 사라진 뒤 도착한 응답 — 버릴 수 있다.
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
          // ⚠️ 높이를 제한하고 스크롤을 준다. `Positioned(left/right/bottom)`만 주면
          // maxHeight가 무한이라, 큰 글꼴(200%)에서 패널이 Stack 위로 자라 조용히
          // 잘린다 — 오버플로 경고도 없이 "어떤 와인인지" 보여주는 카드만 사라지고
          // [완료]는 그대로 눌린다. 확인 단계에서 최악의 실패 모양이다.
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            top: 12,
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SingleChildScrollView(
                  reverse: true, // 넘칠 때 하단 액션이 먼저 보이도록
                  child: _MatchResult(match: match),
                ),
              ),
            ),
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
        // 방금 등록한 와인이 있으면 그대로 수량 입력으로 이어간다(AC6).
        final registered = ref.watch(registeredCandidateProvider);
        if (registered != null) {
          return _ConfirmFor(candidate: registered, canReselect: false);
        }
        if (result == null) return const SizedBox.shrink();
        final candidates = result.candidates;
        if (candidates.isEmpty) return _UnregisteredCard(code: result.code);

        // 후보가 하나뿐이면 고를 것이 없으므로 확인 카드로 직행한다.
        // 둘 이상이면 반드시 사람이 라벨을 보고 고른다 — "최신 빈티지" 같은
        // 기본 선택으로 탭을 줄이는 최적화는 이 화면의 목적을 무효화한다.
        if (candidates.length == 1) {
          return _ConfirmFor(candidate: candidates.single, canReselect: false);
        }

        final selectedId = ref.watch(selectedCandidateProvider);
        // 선택 id가 이번 결과에 없으면(직전 스캔의 잔여 선택 등) 목록으로 되돌린다.
        // 임의 후보로 폴백하면 직원이 고르지 않은 와인이 고른 것과 구별되지 않는 모습으로
        // 확정된다 — 충돌보다 나쁘다.
        final selected = selectedId == null
            ? null
            : candidates.where((c) => c.id == selectedId).firstOrNull;

        if (selected == null) {
          return CandidateList(
            candidates: candidates,
            selectedId: selectedId,
            onSelect: (c) =>
                ref.read(selectedCandidateProvider.notifier).state = c.id,
            onNotListed: () =>
                ref.read(matchProvider.notifier).state = AsyncData(
              ScanResult(code: result.code, products: const []),
            ),
          );
        }

        return _ConfirmFor(candidate: selected, canReselect: true);
      },
    );
  }
}

/// 미매칭 → 신규 등록 유도. 등록을 시작하면 같은 자리에 등록 패널이 뜬다(FR6).
class _UnregisteredCard extends ConsumerWidget {
  const _UnregisteredCard({this.code});

  /// 스캔된 바코드. 등록 시 연결하면 다음부터 바로 매칭된다.
  final String? code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(registeringProvider)) {
      return RegistrationPanel(
        barcode: code,
        onCancel: () {
          ref.read(registrationControllerProvider.notifier).reset();
          ref.read(registeringProvider.notifier).state = false;
        },
        onRegistered: (vintageId) {
          // 등록 직후 같은 흐름으로 수량 입력·완료까지 이어진다(AC6).
          final reg = ref.read(registrationControllerProvider);
          ref.read(registeredCandidateProvider.notifier).state = VintageCandidate(
            product: WineProductRead(
              id: 'new',
              producer: reg.producer.trim(),
              modelName: reg.modelName.trim(),
            ),
            vintage: WineVintageRead(
              id: vintageId,
              vintage: reg.vintageToSubmit,
            ),
          );
          ref.read(registrationControllerProvider.notifier).reset();
          ref.read(registeringProvider.notifier).state = false;
        },
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('미등록 와인'),
        subtitle: const Text('라벨 사진으로 새로 등록할 수 있습니다.'),
        trailing: FilledButton(
          key: const Key('start_registration'),
          onPressed: () => ref.read(registeringProvider.notifier).state = true,
          child: const Text('새로 등록'),
        ),
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
