import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_menu.dart';
import 'data/local/local_database.dart';
import 'reports_screen.dart';
import 'sales_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.database});
  final LocalDatabase database;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final future = _DashboardData.load(widget.database);
    setState(() {
      _data = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: AppMenu.leadingOf(context),
          title: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dashboard'),
                Text('Today at a glance',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
          actions: [
            IconButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            SalesHistoryScreen(database: widget.database))),
                tooltip: 'Sales history',
                icon: const Icon(LucideIcons.history)),
            IconButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            ReportsScreen(database: widget.database))),
                tooltip: 'Open reports',
                icon: const Icon(LucideIcons.fileText)),
            IconButton(
                onPressed: _reload,
                tooltip: 'Refresh dashboard',
                icon: const Icon(LucideIcons.refreshCw)),
          ],
        ),
        body: FutureBuilder<_DashboardData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            final hPad = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 20.0;
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 20),
                children: [
                  Row(children: [
                    const Icon(LucideIcons.trendingUp, size: 19),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('Sales analytics',
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const Spacer(),
                    Text('Today', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, constraints) {
                    const spacing = 10.0;
                    final columns =
                        math.max(2, (constraints.maxWidth / 200).floor());
                    final cardWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                    return Wrap(spacing: spacing, runSpacing: spacing, children: [
                      _MetricCard(
                          width: cardWidth,
                          icon: LucideIcons.banknote,
                          label: 'Net sales',
                          value: _php(data.summary['net_sales'] ?? 0)),
                      _MetricCard(
                          width: cardWidth,
                          icon: LucideIcons.shoppingCart,
                          label: 'Transactions',
                          value: '${data.summary['transaction_count'] ?? 0}'),
                      _MetricCard(
                          width: cardWidth,
                          icon: LucideIcons.undo2,
                          label: 'Refunds',
                          value: _php(data.summary['refunds'] ?? 0),
                          warning: (data.summary['refunds'] ?? 0) > 0),
                      _MetricCard(
                          width: cardWidth,
                          icon: LucideIcons.trendingUp,
                          label: 'Est. profit',
                          value: _php(data.summary['estimated_profit'] ?? 0)),
                      _MetricCard(
                          width: cardWidth,
                          icon: LucideIcons.handCoins,
                          label: 'Outstanding credit',
                          value: _php(data.finance['outstanding_credit'] ?? 0),
                          warning:
                              (data.finance['outstanding_credit'] ?? 0) > 0),
                      _MetricCard(
                          width: cardWidth,
                          icon: LucideIcons.receipt,
                          label: 'Costs this month',
                          value: _php(data.finance['month_expenses'] ?? 0),
                          warning: (data.finance['month_expenses'] ?? 0) > 0),
                      _MetricCard(
                          width: cardWidth,
                          icon: LucideIcons.triangleAlert,
                          label: 'Low stock',
                          value: '${data.inventory['low_stock_count'] ?? 0}',
                          warning:
                              (data.inventory['low_stock_count'] ?? 0) > 0),
                    ]);
                  }),
                  const SizedBox(height: 20),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sales trend',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('Last 7 days',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 16),
                            SizedBox(
                                height: 170,
                                child: _SalesTrendChart(rows: data.trend)),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 800;
                      final topProducts =
                          _TopProductsCard(products: data.topProducts);
                      final payments = _PaymentMixCard(payments: data.payments);
                      final lowStock = _LowStockCard(products: data.lowStock);
                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Expanded(child: topProducts),
                                  const SizedBox(width: 16),
                                  Expanded(child: payments),
                                  const SizedBox(width: 16),
                                  Expanded(child: lowStock)
                                ])
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                  topProducts,
                                  const SizedBox(height: 16),
                                  payments,
                                  const SizedBox(height: 16),
                                  lowStock
                                ]);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );

  String _php(num value) => 'PHP ${value.toStringAsFixed(2)}';
}

class _DashboardData {
  const _DashboardData(
      {required this.summary,
      required this.inventory,
      required this.finance,
      required this.trend,
      required this.topProducts,
      required this.payments,
      required this.lowStock});
  final Map<String, num> summary;
  final Map<String, num> inventory;
  final Map<String, num> finance;
  final List<Map<String, Object?>> trend;
  final List<Map<String, Object?>> topProducts;
  final List<Map<String, Object?>> payments;
  final List<Map<String, Object?>> lowStock;

  static Future<_DashboardData> load(LocalDatabase database) async =>
      _DashboardData(
        summary: await database.salesSummaryToday(),
        inventory: await database.inventorySummary(),
        finance: await database.financeSummary(),
        trend: await database.salesTrend(),
        topProducts: await database.topSellingProducts(),
        payments: await database.salesByPaymentMethod(),
        lowStock: await database.lowStockProducts(),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.icon,
      required this.label,
      required this.value,
      this.width,
      this.warning = false});
  final IconData icon;
  final String label;
  final String value;
  final double? width;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xffb45309) : const Color(0xff16803d);
    return SizedBox(
      width: width ?? 190,
      height: 112,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: warning
                        ? const Color(0xfffff4e5)
                        : const Color(0xffe9f5ec),
                    borderRadius: const BorderRadius.all(Radius.circular(8))),
                child: Icon(icon, size: 19, color: color)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(value,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800))))
                ])),
          ]),
        ),
      ),
    );
  }
}

class _SalesTrendChart extends StatelessWidget {
  const _SalesTrendChart({required this.rows});
  final List<Map<String, Object?>> rows;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final amounts = <double>[];
    final labels = <String>[];
    for (var offset = 6; offset >= 0; offset--) {
      final day = DateTime(today.year, today.month, today.day - offset);
      final key = day.toUtc().toIso8601String().substring(0, 10);
      final matching = rows.where((item) => item['sale_day'] == key);
      final row = matching.isEmpty ? null : matching.first;
      amounts.add((row?['amount'] as num?)?.toDouble() ?? 0);
      labels.add(_weekday(day.weekday));
    }
    final maximum = math
        .max(
            1,
            amounts.fold<double>(
                0, (current, value) => math.max(current, value)))
        .toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(
        7,
        (index) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: amounts[index] / maximum,
                    widthFactor: .7,
                    child: const DecoratedBox(
                        decoration: BoxDecoration(
                            color: Color(0xff16803d),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(4)))),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(labels[index], style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }

  String _weekday(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.products});
  final List<Map<String, Object?>> products;

  @override
  Widget build(BuildContext context) => _AnalyticsCard(
        icon: LucideIcons.packageCheck,
        title: 'Top products',
        child: products.isEmpty
            ? const _AnalyticsEmpty(text: 'No sales recorded today.')
            : Column(children: [
                for (final product in products)
                  _AnalyticsRow(
                      label: product['product_name']! as String,
                      detail:
                          '${(product['quantity'] as num).toStringAsFixed(2)} sold',
                      value: _php(product['amount'] as num))
              ]),
      );
}

class _PaymentMixCard extends StatelessWidget {
  const _PaymentMixCard({required this.payments});
  final List<Map<String, Object?>> payments;

  @override
  Widget build(BuildContext context) => _AnalyticsCard(
        icon: LucideIcons.creditCard,
        title: 'Payment mix',
        child: payments.isEmpty
            ? const _AnalyticsEmpty(text: 'No payments recorded today.')
            : Column(children: [
                for (final payment in payments)
                  _AnalyticsRow(
                      label: _label(payment['method']! as String),
                      detail: 'Payment method',
                      value: _php(payment['amount'] as num))
              ]),
      );

  String _label(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.products});
  final List<Map<String, Object?>> products;

  @override
  Widget build(BuildContext context) => _AnalyticsCard(
        icon: LucideIcons.triangleAlert,
        title: 'Low stock',
        child: products.isEmpty
            ? const _AnalyticsEmpty(
                text: 'All products are above their reorder level.')
            : Column(children: [
                for (final product in products)
                  _AnalyticsRow(
                      label: product['name']! as String,
                      detail: 'Reorder at ${product['reorder_level']}',
                      value:
                          '${(product['quantity'] as num).toStringAsFixed(2)} ${product['unit']}',
                      warning: true)
              ]),
      );
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard(
      {required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: const Color(0xff16803d)),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800))
            ]),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );
}

class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow(
      {required this.label,
      required this.detail,
      required this.value,
      this.warning = false});
  final String label;
  final String detail;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodySmall)
              ])),
          const SizedBox(width: 10),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: warning
                      ? const Color(0xffb45309)
                      : const Color(0xff146c34))),
        ]),
      );
}

class _AnalyticsEmpty extends StatelessWidget {
  const _AnalyticsEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall));
}

String _php(num value) => 'PHP ${value.toStringAsFixed(2)}';
