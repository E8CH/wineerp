import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/image_repository.dart';
import '../theme.dart';

/// 라벨 사진 **크게** 보기 — 상세 시트 상단용.
///
/// [LabelThumbnail]은 목록의 작은 정사각형이라 `BoxFit.cover`로 잘라 채운다. 이 위젯은
/// 반대로 **찍은 그대로**를 보여주는 게 목적이라 `BoxFit.contain`으로 잘리지 않게 담는다 —
/// 세로/가로 어느 각도로 찍었든 비율을 유지한 채 전체가 보인다(사진이 눕지 않도록 회전은
/// 서버가 픽셀에 구워 보낸다: `core/imaging.strip_exif_to_jpeg`).
///
/// key가 없거나 조회·디코드가 실패하면 [LabelThumbnail]과 같은 병 아이콘 폴백으로 떨어져
/// 깨진 이미지 대신 일관된 빈 상태를 보인다.
class LabelPhotoLarge extends ConsumerWidget {
  const LabelPhotoLarge({
    super.key,
    required this.imageKey,
    this.height = 260,
  });

  /// null/빈 문자열이면 곧바로 아이콘 폴백 — 네트워크를 건드리지 않는다.
  final String? imageKey;
  final double height;

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
              height: height,
              width: double.infinity,
              // 잘라 채우지 않는다 — 찍은 비율·각도 그대로 담는다.
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _fallback(),
            ),
            loading: () => _fallback(loading: true),
            error: (_, _) => _fallback(),
          );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        width: double.infinity,
        color: AppColors.background,
        child: child,
      ),
    );
  }

  Widget _fallback({bool loading = false}) {
    return Center(
      child: loading
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.muted,
              ),
            )
          : const Icon(Icons.wine_bar, color: AppColors.muted, size: 64),
    );
  }
}
