import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/history_repository.dart';
import 'category_bar.dart';

/// 입고 내역 행 (UX-DR12) — 사진 자리·모델명·시간·담당·수량 강조·메모.
///
/// 좌측 CategoryBar로 초기 세팅분(네이비)과 입고분(골드)을 구분한다. 색만으로
/// 전달하지 않도록 세팅분에는 라벨도 붙인다(UX-DR15).
class HistoryRow extends StatelessWidget {
  const HistoryRow({super.key, required this.item, this.onTap});

  final HistoryItem item;
  final VoidCallback? onTap;

  String get _time {
    final t = item.receivedAt;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day} $hh:$mm';
  }

  String get _staff => item.staffEmail.split('@').first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CategoryBar(
                color: item.isInitialSetup
                    ? AppColors.categoryIdentity
                    : AppColors.categoryStock,
              ),
              Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wine_bar, color: AppColors.muted, size: 24),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.modelName,
                        style: theme.textTheme.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${item.vintageLabel} · $_time · $_staff',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.isInitialSetup)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '초기 세팅',
                            key: const Key('setup_badge'),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.navy),
                          ),
                        ),
                      if (item.hasMemo)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.sticky_note_2_outlined,
                                size: 14,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.memo!,
                                  key: const Key('memo_text'),
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    '${item.quantity}',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: AppColors.onSurface),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
