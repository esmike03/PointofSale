import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'data/local/local_database.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.database});
  final LocalDatabase database;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 7;
  late Future<_ReportData> _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _data = _ReportData.load(widget.database, _days));
    await _data;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reports'),
                Text('Business performance',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
          actions: [
            IconButton(
                onPressed: _reload,
                tooltip: 'Refresh reports',
                icon: const Icon(LucideIcons.refreshCw))
          ],
        ),
        body: FutureBuilder<_ReportData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final title = Row(children: [
                    const Icon(LucideIcons.trendingUp, size: 19),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('Sales report',
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]);
                  final selector = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('Today')),
                        ButtonSegment(value: 7, label: Text('7 days')),
                        ButtonSegment(value: 30, label: Text('30 days'))
                      ],
                      selected: {_days},
                      onSelectionChanged: (value) {
                        setState(() => _days = value.first);
                        _reload();
                      },
                    ),
                  );
                  // Drop the range selector below the title on narrow phones so
                  // neither the title nor the buttons get squeezed.
                  return constraints.maxWidth < 480
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title,
                            const SizedBox(height: 10),
                            Align(
                                alignment: Alignment.centerLeft,
                                child: selector),
                          ])
                      : Row(children: [
                          Expanded(child: title),
                          const SizedBox(width: 12),
                          selector,
                        ]);
                }),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, constraints) {
                  const spacing = 10.0;
                  final columns =
                      math.max(2, (constraints.maxWidth / 200).floor());
                  final cardWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) / columns;
                  return Wrap(spacing: spacing, runSpacing: spacing, children: [
                    _ReportMetric(
                        width: cardWidth,
                        icon: LucideIcons.banknote,
                        label: 'Net sales',
                        value: _php(data.summary['net_sales'] ?? 0)),
                    _ReportMetric(
                        width: cardWidth,
                        icon: LucideIcons.shoppingCart,
                        label: 'Transactions',
                        value: '${data.summary['transaction_count'] ?? 0}'),
                    _ReportMetric(
                        width: cardWidth,
                        icon: LucideIcons.undo2,
                        label: 'Refunds',
                        value: _php(data.summary['refunds'] ?? 0)),
                    _ReportMetric(
                        width: cardWidth,
                        icon: LucideIcons.receiptText,
                        label: 'Average sale',
                        value: _php(data.averageSale)),
                    _ReportMetric(
                        width: cardWidth,
                        icon: LucideIcons.trendingUp,
                        label: 'Est. profit',
                        value: _php(data.summary['estimated_profit'] ?? 0)),
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
                          Text('Sales over time',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(_days == 1 ? 'Today' : 'Last $_days days',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 16),
                          SizedBox(
                              height: 178,
                              child:
                                  _RangeTrend(rows: data.trend, days: _days)),
                        ]),
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final products =
                        _ProductReportCard(products: data.products);
                    final payments =
                        _PaymentReportCard(payments: data.payments);
                    return constraints.maxWidth >= 700
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Expanded(child: products),
                                const SizedBox(width: 16),
                                Expanded(child: payments)
                              ])
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                products,
                                const SizedBox(height: 16),
                                payments
                              ]);
                  },
                ),
                const SizedBox(height: 20),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              color: Color(0xffe9f5ec),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(6))),
                          child: const Icon(LucideIcons.boxes,
                              color: Color(0xff16803d), size: 19)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Inventory valuation',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(
                                '${data.inventory['product_count']} products  |  ${(data.inventory['total_quantity'] ?? 0).toStringAsFixed(2)} units on hand',
                                style: Theme.of(context).textTheme.bodySmall)
                          ])),
                      Text(_php(data.inventory['stock_value'] ?? 0),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xff146c34))),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _ReportData {
  const _ReportData(
      {required this.summary,
      required this.inventory,
      required this.trend,
      required this.products,
      required this.payments});
  final Map<String, num> summary;
  final Map<String, num> inventory;
  final List<Map<String, Object?>> trend;
  final List<Map<String, Object?>> products;
  final List<Map<String, Object?>> payments;

  double get averageSale {
    final count = summary['transaction_count'] ?? 0;
    return count == 0 ? 0 : (summary['net_sales'] ?? 0) / count;
  }

  static Future<_ReportData> load(LocalDatabase database, int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - days + 1);
    final end = DateTime(now.year, now.month, now.day + 1);
    return _ReportData(
      summary: await database.salesSummaryForRange(start: start, end: end),
      inventory: await database.inventorySummary(),
      trend: await database.salesTrendForRange(start: start, end: end),
      products:
          await database.topSellingProductsForRange(start: start, end: end),
      payments:
          await database.salesByPaymentMethodForRange(start: start, end: end),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric(
      {required this.width,
      required this.icon,
      required this.label,
      required this.value});
  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Color(0xffe9f5ec),
                      borderRadius: BorderRadius.all(Radius.circular(6))),
                  child: Icon(icon, size: 18, color: const Color(0xff16803d))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(label,
                                style: Theme.of(context).textTheme.bodySmall))),
                    const SizedBox(height: 3),
                    SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(value,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800))))
                  ])),
            ]),
          ),
        ),
      );
}

class _RangeTrend extends StatelessWidget {
  const _RangeTrend({required this.rows, required this.days});
  final List<Map<String, Object?>> rows;
  final int days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final amounts = <double>[];
    final labels = <String>[];
    for (var offset = days - 1; offset >= 0; offset--) {
      final day = DateTime(now.year, now.month, now.day - offset);
      final key = day.toUtc().toIso8601String().substring(0, 10);
      final matches = rows.where((row) => row['sale_day'] == key);
      amounts.add(
          matches.isEmpty ? 0 : (matches.first['amount'] as num).toDouble());
      labels.add(days <= 7 ? _weekday(day.weekday) : '${day.month}/${day.day}');
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
        days,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: days > 7 ? 1 : 3),
            child: Column(children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: amounts[index] / maximum,
                    widthFactor: days > 7 ? .9 : .7,
                    child: const DecoratedBox(
                        decoration: BoxDecoration(
                            color: Color(0xff16803d),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(3)))),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(days > 7 && index % 5 != 0 ? '' : labels[index],
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.clip),
            ]),
          ),
        ),
      ),
    );
  }

  String _weekday(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

class _ProductReportCard extends StatelessWidget {
  const _ProductReportCard({required this.products});
  final List<Map<String, Object?>> products;

  @override
  Widget build(BuildContext context) => _ReportCard(
        icon: LucideIcons.packageCheck,
        title: 'Product performance',
        child: products.isEmpty
            ? const _ReportEmpty(text: 'No product sales in this period.')
            : Column(children: [
                for (final product in products)
                  _ReportRow(
                      label: product['product_name']! as String,
                      detail:
                          '${(product['quantity'] as num).toStringAsFixed(2)} sold',
                      value: _php(product['amount'] as num))
              ]),
      );
}

class _PaymentReportCard extends StatelessWidget {
  const _PaymentReportCard({required this.payments});
  final List<Map<String, Object?>> payments;

  @override
  Widget build(BuildContext context) => _ReportCard(
        icon: LucideIcons.creditCard,
        title: 'Payment report',
        child: payments.isEmpty
            ? const _ReportEmpty(text: 'No payments in this period.')
            : Column(children: [
                for (final payment in payments)
                  _ReportRow(
                      label: _title(payment['method']! as String),
                      detail: 'Payment method',
                      value: _php(payment['amount'] as num))
              ]),
      );

  String _title(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(
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
            child
          ])));
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(
      {required this.label, required this.detail, required this.value});
  final String label;
  final String detail;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(detail, style: Theme.of(context).textTheme.bodySmall)
        ])),
        const SizedBox(width: 10),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: Color(0xff146c34)))
      ]));
}

class _ReportEmpty extends StatelessWidget {
  const _ReportEmpty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall));
}

String _php(num value) => 'PHP ${value.toStringAsFixed(2)}';
