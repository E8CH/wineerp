import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/scan_models.dart';
import 'category_bar.dart';

/// 빈티지 후보 목록 (UX-DR7) — 썸네일 세로 카드, 한 탭 선택.
///
/// 바코드는 빈티지를 구분하지 못한다(AR3). 따라서 이 목록은 인식 실패 시의 폴백이 아니라
/// **정상 경로**다 — 자동 추론이나 "최신 빈티지" 기본 선택으로 대체하지 말 것.
/// 스캔 리듬을 깨지 않도록 차단 모달이 아닌 인라인으로 렌더한다.
class CandidateList extends StatelessWidget {
  const CandidateList({
    super.key,
    required this.candidates,
    required this.onSelect,
    required this.onNotListed,
    this.selectedId,
    this.maxHeight = 320,
  });

  final List<VintageCandidate> candidates;
  final ValueChanged<VintageCandidate> onSelect;

  /// 맞는 빈티지가 목록에 없을 때의 탈출구. 없으면 직원이 가장 가까운 틀린 항목을
  /// 고르고 넘어가며, 그것은 침묵하는 데이터 오염이 된다.
  final VoidCallback onNotListed;

  final String? selectedId;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Header(),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: candidates.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  if (i == candidates.length) {
                    return _NotListedRow(onTap: onNotListed);
                  }
                  final c = candidates[i];
                  return _CandidateRow(
                    key: Key('candidate_${c.id}'),
                    candidate: c,
                    position: i + 1,
                    total: candidates.length,
                    selected: c.id == selectedId,
                    onTap: c.isSelectable ? () => onSelect(c) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.photo_camera_outlined, size: 20, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '라벨을 보고 골라주세요',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    super.key,
    required this.candidate,
    required this.position,
    required this.total,
    required this.selected,
    this.onTap,
  });

  final VintageCandidate candidate;
  final int position;
  final int total;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = candidate.vintageLabel;
    final semantics = [
      candidate.product.modelName,
      candidate.isSelectable ? label : '빈티지 미등록',
      '후보 $position/$total',
      if (selected) '선택됨',
    ].join(', ');

    return Semantics(
      button: candidate.isSelectable,
      selected: selected,
      label: semantics,
      child: Material(
        color: selected ? AppColors.container : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.navy : AppColors.background,
                width: selected ? 2 : 1,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CategoryBar(color: AppColors.categoryIdentity),
                  _Thumbnail(enabled: candidate.isSelectable),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate.product.producer,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            candidate.product.modelName,
                            style: theme.textTheme.bodyLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _VintageBadge(label: label, muted: !candidate.isSelectable),
                  if (selected) const _SelectedMark(),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // representative_image_key → URL 해석기가 아직 없어 placeholder 유지(2.3 후속).
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.wine_bar,
        size: 22,
        color: enabled ? AppColors.muted : AppColors.muted.withValues(alpha: 0.4),
      ),
    );
  }
}

class _VintageBadge extends StatelessWidget {
  const _VintageBadge({required this.label, required this.muted});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        label,
        style: (muted ? theme.textTheme.bodyMedium : theme.textTheme.titleLarge)
            ?.copyWith(color: muted ? AppColors.muted : AppColors.onSurface),
      ),
    );
  }
}

class _SelectedMark extends StatelessWidget {
  const _SelectedMark();

  @override
  Widget build(BuildContext context) {
    // 색 단독으로 상태를 전달하지 않는다(WCAG 2.1 AA / UX-DR15).
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppColors.navy, size: 22),
          Text(
            '선택됨',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}

class _NotListedRow extends StatelessWidget {
  const _NotListedRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('candidate_not_listed'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.background),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline, color: AppColors.muted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '찾는 빈티지가 없어요',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
