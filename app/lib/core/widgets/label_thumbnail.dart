import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/image_repository.dart';
import '../theme.dart';

/// 라벨 사진 썸네일 (Story 6.1).
///
/// 기존 화면들은 사진 자리에 `Icons.wine_bar` 아이콘만 그렸다(사진을 실제로 못 불러와서다).
/// 이 위젯이 그 자리를 대체한다 — key가 있으면 인증 조회로 사진을 그리고, 없거나 실패하면
/// **같은 아이콘 폴백**으로 떨어진다. 그래서 사진이 아직 없는 와인도 깨진 이미지가 아니라
/// 원래의 병 아이콘으로 보인다.
class LabelThumbnail extends ConsumerWidget {
  const LabelThumbnail({
    super.key,
    required this.imageKey,
    this.size = 56,
    this.radius = 12,
    this.iconSize = 24,
  });

  /// null/빈 문자열이면 곧바로 아이콘 폴백 — 네트워크를 건드리지 않는다.
  final String? imageKey;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = imageKey;
    final Widget child;
    if (key == null || key.isEmpty) {
      child = _fallback();
    } else {
      child = ref.watch(labelImageProvider(key)).when(
            data: (bytes) => Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              // 디코드 실패(손상 바이트 등)도 아이콘으로 떨어뜨린다.
              errorBuilder: (_, _, _) => _fallback(),
            ),
            // 로딩·에러 모두 폴백 아이콘 위에 얹는다 — 실패해도 레이아웃이 흔들리지 않는다.
            loading: () => _fallback(loading: true),
            error: (_, _) => _fallback(),
          );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _fallback({bool loading = false}) {
    return Center(
      child: loading
          ? SizedBox(
              width: iconSize * 0.7,
              height: iconSize * 0.7,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.muted,
              ),
            )
          : Icon(Icons.wine_bar, color: AppColors.muted, size: iconSize),
    );
  }
}
