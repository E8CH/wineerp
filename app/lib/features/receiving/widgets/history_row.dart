import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/label_thumbnail.dart';
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
  String get _amender => (item.amendedBy ?? '').split('@').first;

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
              Padding(
                padding: const EdgeInsets.all(10),
                child: LabelThumbnail(imageKey: item.representativeImageKey),
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
                      // 수정 사실을 드러내지 않으면 최초 입고자 이름 옆에 남이 고친
                      // 수량이 뜬다 — 감사 행은 남지만 화면에서는 오귀속된다.
                      if (item.isAmended)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_note,
                                size: 14,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '수정됨 · $_amender',
                                  key: const Key('amended_badge'),
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: AppColors.warning),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
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
                      // 삭제된 모델의 과거 입고는 원장으로 남는다 — 재고엔 없는 이유를 밝힌다.
                      if (item.modelArchived)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.block, size: 14,
                                  color: AppColors.muted),
                              const SizedBox(width: 4),
                              Text(
                                '삭제된 모델',
                                key: const Key('archived_badge'),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.muted),
                              ),
                            ],
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
                  // 수량 폭을 묶어 좁은 폭에서도 왼쪽 이름(Expanded)을 잠식하지 않게 하고,
                  // 자릿수가 많으면 줄바꿈 대신 줄어들게 한다.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 64),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${item.quantity}',
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(color: AppColors.onSurface),
                      ),
                    ),
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
