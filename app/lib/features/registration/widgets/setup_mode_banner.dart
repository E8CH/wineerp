import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// 초기 세팅 모드 배너 (UX-DR10) — 골드로 입고 모드와 시각 구분 + 등록 카운터 + 나가기.
///
/// 색만으로 모드를 전달하지 않는다: 아이콘·문구·카운터를 함께 둔다(UX-DR15).
class SetupModeBanner extends StatelessWidget {
  const SetupModeBanner({
    super.key,
    required this.registeredCount,
    required this.onExit,
  });

  final int registeredCount;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.categoryStock,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              // 폴드 커버(≈280dp)·큰 글꼴에서 카운터·나가기와 한 줄에 다 못 들어가므로
              // 라벨을 먼저 줄여(…) 오버플로우를 막는다. 카운터·나가기는 항상 보인다.
              const Flexible(
                child: Text(
                  '초기 세팅 모드',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                key: const Key('setup_counter'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$registeredCount종 등록',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const Spacer(),
              // 명확한 나가기(UX 사양: "별도 모드 — 배너 진입 표시·명확한 나가기").
              TextButton(
                key: const Key('setup_exit'),
                onPressed: onExit,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('나가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
