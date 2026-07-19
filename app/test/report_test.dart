import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/report_repository.dart';
import 'package:wineerp_app/features/auth/auth_controller.dart';
import 'package:wineerp_app/features/report/report_screen.dart';
import 'package:wineerp_app/features/report/widgets/report_bar_chart.dart';

/// Story 5.1 — 종합 리포트 (FR10, UX-DR11).
class _FakeReportRepo extends ReportRepository {
  _FakeReportRepo(this._report, {this.fail = false}) : super(Dio());

  final ReceivingReport _report;
  final bool fail;
  final List<ReportPeriod> requested = [];

  @override
  Future<ReceivingReport> fetch(ReportPeriod period) async {
    requested.add(period);
    if (fail) throw Exception('boom');
    return _report;
  }
}

class _RoleController extends AuthController {
  _RoleController(this._role);

  final String _role;

  @override
  AuthState build() => AuthState(token: 't', email: 'u@w.co', role: _role);
}

ReceivingReport _report({
  List<int> quantities = const [0, 5, 0, 12, 0, 3, 0],
  List<TopProduct> top = const [
    TopProduct(modelName: 'Grange', producer: 'Penfolds', quantity: 12),
  ],
}) {
  final buckets = [
    for (var i = 0; i < quantities.length; i++)
      DayBucket(
        date: '2026-07-${(13 + i).toString().padLeft(2, '0')}',
        quantity: quantities[i],
      ),
  ];
  final total = quantities.fold<int>(0, (a, b) => a + b);
  return ReceivingReport(
    buckets: buckets,
    topProducts: total == 0 ? const [] : top,
    totalQuantity: total,
    recordCount: quantities.where((q) => q > 0).length,
    distinctWines: 2,
  );
}

ProviderContainer _container(_FakeReportRepo repo, {String role = 'manager'}) {
  final c = ProviderContainer(overrides: [
    reportRepositoryProvider.overrideWithValue(repo),
    authControllerProvider.overrideWith(() => _RoleController(role)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.light, home: const ReportScreen()),
    );

void main() {
  group('권한', () {
    testWidgets('staff에게는 리포트가 보이지 않는다', (tester) async {
      final repo = _FakeReportRepo(_report());
      await tester.pumpWidget(_host(_container(repo, role: 'staff')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report_forbidden')), findsOneWidget);
      expect(repo.requested, isEmpty, reason: '차단됐으면 호출도 하지 않는다');
    });

    testWidgets('manager에게는 리포트가 보인다', (tester) async {
      await tester.pumpWidget(_host(_container(_FakeReportRepo(_report()))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_forbidden')), findsNothing);
      expect(find.byType(ReportBarChart), findsOneWidget);
    });
  });

  group('차트', () {
    testWidgets('빈 날도 막대 자리를 차지한다', (tester) async {
      // 빼면 막대가 붙어 그려지고 "매일 들어왔다"로 읽힌다.
      await tester.pumpWidget(_host(_container(_FakeReportRepo(_report()))));
      await tester.pumpAndSettle();

      final chart = tester.widget<ReportBarChart>(find.byType(ReportBarChart));
      expect(chart.buckets.length, 7);
      expect(chart.buckets.where((b) => b.quantity == 0).length, 4);
    });

    testWidgets('피크는 색만이 아니라 수치로도 표시된다', (tester) async {
      await tester.pumpWidget(_host(_container(_FakeReportRepo(_report()))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('peak_label')), findsOneWidget);
      expect(find.text('12'), findsWidgets);
    });
  });

  group('KPI·상위 품목', () {
    testWidgets('총 입고·기록·품목이 표시된다', (tester) async {
      await tester.pumpWidget(_host(_container(_FakeReportRepo(_report()))));
      await tester.pumpAndSettle();

      expect(find.text('20병'), findsOneWidget); // 5+12+3
      expect(find.text('3건'), findsOneWidget);
      expect(find.text('2종'), findsOneWidget);
    });

    testWidgets('상위 품목 목록이 나온다', (tester) async {
      await tester.pumpWidget(_host(_container(_FakeReportRepo(_report()))));
      await tester.pumpAndSettle();
      expect(find.text('Grange'), findsOneWidget);
      expect(find.text('12병'), findsOneWidget);
    });
  });

  group('상태', () {
    testWidgets('데이터가 없으면 빈 상태', (tester) async {
      final empty = _FakeReportRepo(_report(quantities: const [0, 0, 0]));
      await tester.pumpWidget(_host(_container(empty)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_empty')), findsOneWidget);
    });

    testWidgets('실패 시 오류 상태', (tester) async {
      await tester.pumpWidget(
        _host(_container(_FakeReportRepo(_report(), fail: true))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_error')), findsOneWidget);
    });

    testWidgets('기간을 바꾸면 다시 조회한다', (tester) async {
      final repo = _FakeReportRepo(_report());
      await tester.pumpWidget(_host(_container(repo)));
      await tester.pumpAndSettle();
      expect(repo.requested, [ReportPeriod.week]);

      await tester.tap(find.text('월간'));
      await tester.pumpAndSettle();
      expect(repo.requested.last, ReportPeriod.month);
    });
  });
}
