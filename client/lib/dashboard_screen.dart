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
    final maximum =
        amounts.fold<double>(0, (current, value) => math.max(current, value));
    final peak = amounts.indexOf(maximum);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _TrendAreaPainter(
                amounts, maximum, maximum > 0 ? peak : -1),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final label in labels)
              Expanded(
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ],
    );
  }

  String _weekday(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.products});
  final List<Map<String, Object?>> products;

  @override
  Widget build(BuildContext context) {
    final maxAmount = products.fold<double>(
        0, (current, p) => math.max(current, (p['amount'] as num).toDouble()));
    return _AnalyticsCard(
      icon: LucideIcons.packageCheck,
      title: 'Top products',
      child: products.isEmpty
          ? const _AnalyticsEmpty(text: 'No sales recorded today.')
          : Column(children: [
              for (var i = 0; i < products.length; i++)
                _BarRow(
                    label: products[i]['product_name']! as String,
                    detail:
                        '${(products[i]['quantity'] as num).toStringAsFixed(2)} sold',
                    value: _php(products[i]['amount'] as num),
                    fraction: maxAmount <= 0
                        ? 0
                        : (products[i]['amount'] as num).toDouble() / maxAmount,
                    color: _chartPalette[i % _chartPalette.length])
            ]),
    );
  }
}

class _PaymentMixCard extends StatelessWidget {
  const _PaymentMixCard({required this.payments});
  final List<Map<String, Object?>> payments;

  @override
  Widget build(BuildContext context) {
    final entries =
        payments.where((p) => (p['amount'] as num).toDouble() > 0).toList();
    return _AnalyticsCard(
      icon: LucideIcons.creditCard,
      title: 'Payment mix',
      child: entries.isEmpty
          ? const _AnalyticsEmpty(text: 'No payments recorded today.')
          : _DonutBreakdown(
              slices: [
                for (var i = 0; i < entries.length; i++)
                  _Slice(
                      label: _label(entries[i]['method']! as String),
                      value: (entries[i]['amount'] as num).toDouble(),
                      color: _chartPalette[i % _chartPalette.length])
              ],
              valueFormatter: _php,
            ),
    );
  }

  String _label(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

/// A single wedge of the donut chart / row of a horizontal bar breakdown.
class _Slice {
  const _Slice({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;
}

/// A donut (pie) chart on the left with a coloured legend on the right that
/// lists each slice's share and amount. The centre shows the running total.
class _DonutBreakdown extends StatelessWidget {
  const _DonutBreakdown(
      {required this.slices, required this.valueFormatter});
  final List<_Slice> slices;
  final String Function(num) valueFormatter;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 116,
          height: 116,
          child: CustomPaint(
            painter: _DonutPainter(
                slices.map((slice) => slice.value).toList(),
                slices.map((slice) => slice.color).toList()),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Total', style: Theme.of(context).textTheme.bodySmall),
                SizedBox(
                    width: 82,
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(valueFormatter(total),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)))),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final slice in slices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: slice.color,
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(slice.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600))),
                              Text(
                                  '${total <= 0 ? 0 : (slice.value / total * 100).round()}%',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                            Text(valueFormatter(slice.value),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff146c34))),
                          ]),
                    ),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A labelled horizontal bar showing one item's value relative to the largest.
class _BarRow extends StatelessWidget {
  const _BarRow(
      {required this.label,
      required this.detail,
      required this.value,
      required this.fraction,
      required this.color});
  final String label;
  final String detail;
  final String value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xff146c34))),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 8, color: const Color(0xffeef2f0)),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.02, 1.0),
                child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4))),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

/// Paints an arc-per-value donut. Values are drawn clockwise from the top with
/// a small rounded gap between wedges.
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors);
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;
    final stroke = size.shortestSide * 0.16;
    final radius = (size.shortestSide - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gap = values.length > 1 ? 0.04 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * (2 * math.pi);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = colors[i];
      canvas.drawArc(
          rect, start + gap / 2, math.max(0.0, sweep - gap), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

/// Paints a smoothed area + line chart with faint gridlines, dots at each
/// data point, and a value bubble over the peak day.
class _TrendAreaPainter extends CustomPainter {
  _TrendAreaPainter(this.values, this.maximum, this.peakIndex);
  final List<double> values;
  final double maximum;
  final int peakIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xffe6ebe8)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;
    final max = maximum <= 0 ? 1.0 : maximum;
    final dx = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    Offset pointAt(int i) {
      final x = dx * i;
      final y = size.height -
          (values[i] / max) * size.height * 0.86 -
          size.height * 0.08;
      return Offset(x, y);
    }

    final line = Path();
    final area = Path()..moveTo(0, size.height);
    for (var i = 0; i < values.length; i++) {
      final point = pointAt(i);
      if (i == 0) {
        line.moveTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
      }
      area.lineTo(point.dx, point.dy);
    }
    area.lineTo(size.width, size.height);
    area.close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x3316803d), Color(0x0016803d)])
              .createShader(Offset.zero & size));
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xff16803d));
    for (var i = 0; i < values.length; i++) {
      final point = pointAt(i);
      canvas.drawCircle(point, 3.2, Paint()..color = Colors.white);
      canvas.drawCircle(
          point,
          3.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xff16803d));
    }
    if (peakIndex >= 0 && values[peakIndex] > 0) {
      final point = pointAt(peakIndex);
      final painter = TextPainter(
          text: TextSpan(
              text: _short(values[peakIndex]),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff146c34))),
          textDirection: TextDirection.ltr)
        ..layout();
      var left = point.dx - painter.width / 2;
      left = left.clamp(0.0, size.width - painter.width);
      painter.paint(canvas, Offset(left, math.max(0, point.dy - 16)));
    }
  }

  String _short(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(_TrendAreaPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.maximum != maximum ||
      oldDelegate.peakIndex != peakIndex;
}

/// Palette used to colour chart wedges and bars, cycled by index.
const _chartPalette = <Color>[
  Color(0xff16803d),
  Color(0xff2f9e57),
  Color(0xff5bb97a),
  Color(0xff86cfa0),
  Color(0xff0e7490),
  Color(0xffb45309),
  Color(0xffd97706),
  Color(0xfff59e0b),
];

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
