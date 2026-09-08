import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'data/local/local_database.dart';
import 'ui_kit.dart';

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
    final future = _ReportData.load(widget.database, _days);
    setState(() {
      _data = future;
    });
    await future;
  }

  String get _rangeLabel => _days == 1 ? 'Today' : 'Last $_days days';

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: kPageTop,
      appBar: ModuleAppBar(
        title: 'Reports',
        subtitle: 'Business performance',
        actions: [
          SoftIconButton(
            icon: LucideIcons.refreshCw,
            tooltip: 'Refresh reports',
            onPressed: _reload,
          ),
        ],
      ),
      body: ModuleBody(
        padded: false,
        child: FutureBuilder<_ReportData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ModuleEmpty(
                icon: LucideIcons.triangleAlert,
                title: 'Reports could not be loaded',
                message: snapshot.error.toString(),
              );
            }
            final data = snapshot.data!;
            final transactions = data.summary['transaction_count'] ?? 0;
            return ListView(
              padding: compact
                  ? const EdgeInsets.fromLTRB(12, 10, 12, 16)
                  : const EdgeInsets.fromLTRB(22, 14, 22, 24),
              children: [
                FilterPillBar(children: [
                  for (final range in const [
                    (1, 'Today'),
                    (7, '7 days'),
                    (30, '30 days')
                  ])
                    FilterPill(
                      label: range.$2,
                      icon: LucideIcons.calendarDays,
                      selected: _days == range.$1,
                      onTap: () {
                        setState(() => _days = range.$1);
                        _reload();
                      },
                    ),
                ]),
                const SizedBox(height: 14),
                HighlightCard(
                  label: 'NET SALES',
                  value: php(data.summary['net_sales'] ?? 0),
                  caption:
                      '$_rangeLabel  •  $transactions ${transactions == 1 ? 'transaction' : 'transactions'}',
                ),
                const SizedBox(height: 12),
                StatTileGrid(tiles: [
                  (width) => StatTile(
                        width: width,
                        icon: LucideIcons.shoppingCart,
                        label: 'Transactions',
                        value: '$transactions',
                      ),
                  (width) => StatTile(
                        width: width,
                        icon: LucideIcons.receiptText,
                        label: 'Average sale',
                        value: php(data.averageSale),
                      ),
                  (width) => StatTile(
                        width: width,
                        icon: LucideIcons.undo2,
                        label: 'Refunds',
                        value: php(data.summary['refunds'] ?? 0),
                        tone: const Color(0xffd05b6f),
                      ),
                  (width) => StatTile(
                        width: width,
                        icon: LucideIcons.trendingUp,
                        label: 'Est. profit',
                        value: php(data.summary['estimated_profit'] ?? 0),
                      ),
                ]),
                const SizedBox(height: 14),
                ModulePanel(
                  icon: LucideIcons.chartColumn,
                  title: 'Sales over time',
                  subtitle: _rangeLabel,
                  child: SizedBox(
                    height: 186,
                    child: _RangeTrend(rows: data.trend, days: _days),
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final products = _ProductPanel(products: data.products);
                    final payments = _PaymentPanel(payments: data.payments);
                    return constraints.maxWidth >= 760
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Expanded(child: products),
                                const SizedBox(width: 14),
                                Expanded(child: payments),
                              ])
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                products,
                                const SizedBox(height: 14),
                                payments,
                              ]);
                  },
                ),
                const SizedBox(height: 14),
                ModulePanel(
                  icon: LucideIcons.boxes,
                  title: 'Inventory valuation',
                  subtitle: 'Stock currently on hand',
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${data.inventory['product_count'] ?? 0} products  •  '
                        '${(data.inventory['total_quantity'] ?? 0).toStringAsFixed(2)} units',
                        style: const TextStyle(color: kInkSoft, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      php(data.inventory['stock_value'] ?? 0),
                      style: const TextStyle(
                          color: kMoney,
                          fontSize: 17,
                          fontWeight: FontWeight.w800),
                    ),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
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

/// Daily sales bars for the selected range.
class _RangeTrend extends StatelessWidget {
  const _RangeTrend({required this.rows, required this.days});
  final List<Map<String, Object?>> rows;
  final int days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final amounts = <double>[];
    final labels = <String>[];
    final dates = <DateTime>[];
    for (var offset = days - 1; offset >= 0; offset--) {
      final day = DateTime(now.year, now.month, now.day - offset);
      final key = day.toUtc().toIso8601String().substring(0, 10);
      final matches = rows.where((row) => row['sale_day'] == key);
      amounts.add(
          matches.isEmpty ? 0 : (matches.first['amount'] as num).toDouble());
      labels.add(days <= 7 ? _weekday(day.weekday) : '${day.month}/${day.day}');
      dates.add(day);
    }
    final peak = amounts.fold<double>(0, math.max);
    final maximum = math.max(1, peak).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const SectionLabel('PEAK DAY'),
        const SizedBox(width: 8),
        Text(
          peak <= 0 ? 'No sales yet' : php(peak),
          style: const TextStyle(
              color: kMoney, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ]),
      const SizedBox(height: 12),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(days, (index) {
            final amount = amounts[index];
            final isPeak = peak > 0 && amount >= peak;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: days > 7 ? 1 : 3),
                child: Column(children: [
                  Expanded(
                    child: Tooltip(
                      message:
                          '${dates[index].month}/${dates[index].day}  •  ${php(amount)}',
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          // Empty days keep a faint stub so the axis still reads.
                          heightFactor: math.max(
                              amount / maximum, amount > 0 ? .04 : .012),
                          widthFactor: days > 7 ? .92 : .68,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: amount <= 0
                                  ? null
                                  : LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: isPeak
                                          ? const [
                                              Color(0xff0d7457),
                                              Color(0xff23c48c)
                                            ]
                                          : const [
                                              Color(0xff2f9d74),
                                              Color(0xff7fd3b4)
                                            ],
                                    ),
                              color:
                                  amount <= 0 ? const Color(0xffe1eae6) : null,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days > 7 && index % 5 != 0 ? '' : labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: isPeak ? kInk : kInkSoft,
                      fontSize: 10,
                      fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
      ),
    ]);
  }

  String _weekday(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

class _ProductPanel extends StatelessWidget {
  const _ProductPanel({required this.products});
  final List<Map<String, Object?>> products;

  @override
  Widget build(BuildContext context) {
    final top =
        products.isEmpty ? 0.0 : (products.first['amount'] as num).toDouble();
    return ModulePanel(
      icon: LucideIcons.packageCheck,
      title: 'Product performance',
      subtitle: 'Best sellers in this period',
      child: products.isEmpty
          ? const ModuleEmpty(
              icon: LucideIcons.packageSearch,
              title: 'No product sales yet',
              message: 'Sales in this period will rank here.',
            )
          : Column(children: [
              for (final product in products) ...[
                _ReportBarRow(
                  label: product['product_name']! as String,
                  detail:
                      '${(product['quantity'] as num).toStringAsFixed(2)} sold',
                  value: php(product['amount'] as num),
                  share: top <= 0
                      ? 0
                      : (product['amount'] as num).toDouble() / top,
                  accent: accentFor(product['product_name']! as String),
                ),
                const SizedBox(height: 8),
              ],
            ]),
    );
  }
}

class _PaymentPanel extends StatelessWidget {
  const _PaymentPanel({required this.payments});
  final List<Map<String, Object?>> payments;

  static const _icons = {
    'cash': LucideIcons.banknote,
    'card': LucideIcons.creditCard,
    'gcash': LucideIcons.smartphone,
    'maya': LucideIcons.wallet,
    'credit': LucideIcons.handCoins,
    'bank_transfer': LucideIcons.landmark,
  };

  @override
  Widget build(BuildContext context) {
    final total = payments.fold<double>(
        0, (sum, payment) => sum + (payment['amount'] as num).toDouble());
    return ModulePanel(
      icon: LucideIcons.creditCard,
      title: 'Payment mix',
      subtitle: 'How customers paid',
      child: payments.isEmpty
          ? const ModuleEmpty(
              icon: LucideIcons.creditCard,
              title: 'No payments yet',
              message: 'Completed payments will break down here.',
            )
          : Column(children: [
              for (final payment in payments) ...[
                _ReportBarRow(
                  label: _title(payment['method']! as String),
                  detail: total <= 0
                      ? 'Payment method'
                      : '${((payment['amount'] as num).toDouble() / total * 100).toStringAsFixed(0)}% of payments',
                  value: php(payment['amount'] as num),
                  share: total <= 0
                      ? 0
                      : (payment['amount'] as num).toDouble() / total,
                  accent: accentFor(payment['method']! as String),
                  icon: _icons[payment['method']] ?? LucideIcons.wallet,
                ),
                const SizedBox(height: 8),
              ],
            ]),
    );
  }

  String _title(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

/// A ranked row whose share bar makes the comparison readable at a glance.
class _ReportBarRow extends StatelessWidget {
  const _ReportBarRow({
    required this.label,
    required this.detail,
    required this.value,
    required this.share,
    required this.accent,
    this.icon,
  });
  final String label;
  final String detail;
  final String value;
  final double share;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ModuleRow(
        child: Column(children: [
          Row(children: [
            if (icon != null) ...[
              RowIcon(icon: icon!, color: accent, size: 34),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: kInkStrong, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kInkSoft, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(color: kMoney, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: share.clamp(0, 1).toDouble(),
              minHeight: 5,
              backgroundColor: const Color(0xffedf3f0),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ]),
      );
}
