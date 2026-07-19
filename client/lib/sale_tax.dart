class SaleTaxSummary {
  const SaleTaxSummary({
    required this.mode,
    required this.vatRate,
    required this.vatableSales,
    required this.vatAmount,
    required this.vatExemptSales,
    required this.zeroRatedSales,
  });

  final String mode;
  final double vatRate;
  final double vatableSales;
  final double vatAmount;
  final double vatExemptSales;
  final double zeroRatedSales;

  factory SaleTaxSummary.calculate({
    required List<Map<String, Object?>> items,
    required double grossAmount,
    required double discountAmount,
    required String mode,
    required double vatRate,
  }) {
    if (mode != 'vat' || grossAmount <= 0) {
      return SaleTaxSummary(
        mode: mode,
        vatRate: 0,
        vatableSales: 0,
        vatAmount: 0,
        vatExemptSales: 0,
        zeroRatedSales: 0,
      );
    }
    final categoryGross = <String, double>{
      'vatable': 0,
      'exempt': 0,
      'zero_rated': 0,
    };
    for (final item in items) {
      final category = item['tax_category'] as String? ?? 'vatable';
      final normalized =
          categoryGross.containsKey(category) ? category : 'vatable';
      categoryGross[normalized] =
          categoryGross[normalized]! + (item['line_total'] as num).toDouble();
    }
    double afterDiscount(String category) {
      final amount = categoryGross[category]!;
      return amount - (discountAmount * amount / grossAmount);
    }

    final inclusiveVatable = afterDiscount('vatable');
    final rate = vatRate.clamp(0, 1).toDouble();
    final vatableSales = inclusiveVatable / (1 + rate);
    return SaleTaxSummary(
      mode: mode,
      vatRate: rate,
      vatableSales: vatableSales,
      vatAmount: inclusiveVatable - vatableSales,
      vatExemptSales: afterDiscount('exempt'),
      zeroRatedSales: afterDiscount('zero_rated'),
    );
  }

  factory SaleTaxSummary.fromSale(Map<String, Object?> sale) => SaleTaxSummary(
        mode: sale['tax_mode'] as String? ?? 'unregistered',
        vatRate: (sale['vat_rate'] as num?)?.toDouble() ?? 0,
        vatableSales: (sale['vatable_sales'] as num?)?.toDouble() ?? 0,
        vatAmount: (sale['vat_amount'] as num?)?.toDouble() ?? 0,
        vatExemptSales: (sale['vat_exempt_sales'] as num?)?.toDouble() ?? 0,
        zeroRatedSales: (sale['zero_rated_sales'] as num?)?.toDouble() ?? 0,
      );
}
