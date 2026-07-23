import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/label_thumbnail.dart';
import '../../data/wine_catalog_repository.dart';
import '../receiving/widgets/category_bar.dart';
import 'widgets/catalog_detail_sheet.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 카탈로그를 텍스트 + 등록일 범위로 거른다. **순수 함수**라 단위 검증한다 — 위젯 안에
/// 두면 showDateRangePicker 없이는 날짜 필터를 테스트하기 어렵다.
///
/// - 텍스트: 모델명·생산자·지역/국가/품종을 이어 소문자 부분일치.
/// - 날짜: item.createdAt의 (로컬) 날짜가 범위 [start, end] **양끝 포함**인지. 날짜만
///   비교하므로 종료일 당일에 등록된 항목도 포함된다(시각으로 자르면 그날치가 빠진다).
List<ProductCatalogItem> filterCatalog(
  List<ProductCatalogItem> items, {
  required String query,
  DateTimeRange? dateRange,
}) {
  final q = query.trim().toLowerCase();
  return items.where((item) {
    if (q.isNotEmpty && !item.searchHaystack.contains(q)) return false;
    if (dateRange != null) {
      final d = _dateOnly(item.createdAt);
      if (d.isBefore(_dateOnly(dateRange.start)) ||
          d.isAfter(_dateOnly(dateRange.end))) {
        return false;
      }
    }
    return true;
  }).toList();
}

/// 모델(제품) 카탈로그 탭 (Story 7.x) — 등록된 와인 모델을 카드로 보여준다.
///
/// 재고 탭이 **빈티지 단위** 행이라면, 여기는 **제품(모델) 단위** 카드다. 카드를 누르면
/// 상단 사진 + 아래 정보의 상세가 뜨고, 거기서 수정·삭제(manager)한다.
///
/// 검색: 모델명·생산자·지역/국가/품종 텍스트 + 등록일 범위. 카탈로그는 이미 통째로
/// 불러오므로(수백 개 규모) **클라이언트에서 필터**한다 — 입력 즉시 반응하고 추가 왕복이
/// 없다. 수천 개로 커지면 서버 쿼리로 옮긴다.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _search = TextEditingController();
  String _query = '';
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
      helpText: '등록일 범위 선택',
      saveText: '적용',
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('모델'),
        actions: [
          IconButton(
            key: const Key('catalog_refresh'),
            tooltip: '새로고침',
            onPressed: () => ref.read(catalogRevisionProvider.notifier).state++,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            dateRange: _dateRange,
            onPickDate: _pickDateRange,
            onClearDate: () => setState(() => _dateRange = null),
          ),
          Expanded(
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const _ErrorState(),
              data: (items) {
                if (items.isEmpty) return const _EmptyState();
                final filtered =
                    filterCatalog(items, query: _query, dateRange: _dateRange);
                if (filtered.isEmpty) return const _NoResults();
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(catalogRevisionProvider.notifier).state++,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CatalogCard(item: filtered[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.dateRange,
    required this.onPickDate,
    required this.onClearDate,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final DateTimeRange? dateRange;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;

  String _fmt(DateTime d) => '${d.year}.${d.month}.${d.day}';

  @override
  Widget build(BuildContext context) {
    final range = dateRange;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          TextField(
            key: const Key('catalog_search'),
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '모델명·생산자·지역 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('catalog_search_clear'),
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // 등록일 범위 필터. 선택되면 칩에 범위가 뜨고 X로 해제.
              range == null
                  ? OutlinedButton.icon(
                      key: const Key('catalog_date_filter'),
                      onPressed: onPickDate,
                      icon: const Icon(Icons.date_range, size: 18),
                      label: const Text('등록일'),
                    )
                  : InputChip(
                      key: const Key('catalog_date_chip'),
                      avatar: const Icon(Icons.date_range, size: 18),
                      label: Text('${_fmt(range.start)} ~ ${_fmt(range.end)}'),
                      onPressed: onPickDate,
                      onDeleted: onClearDate,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item});

  final ProductCatalogItem item;

  /// 지역·국가·품종 중 있는 것만 가운뎃점으로 잇는다.
  String get _spec => [item.region, item.country, item.grape]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' · ');

  String get _registered {
    final d = item.createdAt;
    return '등록 ${d.year}.${d.month}.${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = _spec;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => showCatalogDetail(context, item),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 네이비 = 식별(모델) 위계.
              const CategoryBar(color: AppColors.categoryIdentity),
              Padding(
                padding: const EdgeInsets.all(10),
                child: LabelThumbnail(
                  imageKey: item.representativeImageKey,
                  size: 64,
                ),
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
                        item.producer,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (spec.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            spec,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '빈티지 ${item.vintages.length}종 · 재고 ${item.totalStock}병',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.navy),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _registered,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Icon(Icons.chevron_right, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('catalog_empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.style_outlined, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            '등록된 모델이 없습니다',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            '스캔 탭에서 새 와인을 등록하면 여기에 쌓입니다.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// 검색·필터로 걸러 아무것도 안 남았을 때. 빈 카탈로그(_EmptyState)와 구분한다 —
/// "등록된 게 없다"와 "검색 결과가 없다"는 사용자가 할 행동이 다르다.
class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('catalog_no_results'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            '검색 결과가 없습니다',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('catalog_error'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: AppColors.muted),
          SizedBox(height: 12),
          Text('모델 목록을 불러오지 못했습니다'),
        ],
      ),
    );
  }
}
