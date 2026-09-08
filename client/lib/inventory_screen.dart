import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_menu.dart';
import 'async_dispose.dart';
import 'data/local/local_database.dart';
import 'pagination_controls.dart';
import 'ui_kit.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.database});
  final LocalDatabase database;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const _pageSize = 20;
  final searchController = TextEditingController();
  String _view = 'stock';
  int _page = 0;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: AppMenu.leadingOf(context),
          title: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inventory'),
                Text('Stock control',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
          actions: [
            IconButton(
              onPressed: () => setState(() {}),
              tooltip: 'Refresh inventory',
              icon: const Icon(LucideIcons.refreshCw),
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 600 ? 12 : 20,
              16,
              MediaQuery.sizeOf(context).width < 600 ? 12 : 20,
              20),
          child: Column(children: [
            const _InventoryHeading(),
            const SizedBox(height: 18),
            FutureBuilder<Map<String, num>>(
              future: widget.database.inventorySummary(),
              builder: (context, snapshot) {
                final summary = snapshot.data;
                return LayoutBuilder(builder: (context, constraints) {
                  const spacing = 12.0;
                  final rawColumns = (constraints.maxWidth / 200).floor();
                  final columns = rawColumns.clamp(2, 4);
                  final cardWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                  return Wrap(spacing: spacing, runSpacing: spacing, children: [
                    _SummaryMetric(
                        width: cardWidth,
                        icon: LucideIcons.packageCheck,
                        label: 'Products',
                        value: '${summary?['product_count'] ?? 0}'),
                    _SummaryMetric(
                        width: cardWidth,
                        icon: LucideIcons.boxes,
                        label: 'On hand',
                        value: (summary?['total_quantity'] ?? 0)
                            .toStringAsFixed(2)),
                    _SummaryMetric(
                        width: cardWidth,
                        icon: LucideIcons.triangleAlert,
                        label: 'Low stock',
                        value: '${summary?['low_stock_count'] ?? 0}',
                        warning: true),
                    _SummaryMetric(
                        width: cardWidth,
                        icon: LucideIcons.banknote,
                        label: 'Stock value',
                        value:
                            'PHP ${(summary?['stock_value'] ?? 0).toStringAsFixed(2)}'),
                  ]);
                });
              },
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffdfe9e1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    Row(children: [
                      Icon(
                          _view == 'stock'
                              ? LucideIcons.boxes
                              : LucideIcons.history,
                          size: 18,
                          color: const Color(0xff16803d)),
                      const SizedBox(width: 8),
                      Text(
                          _view == 'stock'
                              ? 'Stock directory'
                              : 'Movement history',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<String>(
                        style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(horizontal: 10))),
                        segments: const [
                          ButtonSegment(
                              value: 'stock',
                              icon: Icon(LucideIcons.boxes, size: 17),
                              label: Text('Stock')),
                          ButtonSegment(
                              value: 'history',
                              icon: Icon(LucideIcons.history, size: 17),
                              label: Text('History')),
                        ],
                        selected: {_view},
                        onSelectionChanged: (value) => setState(() {
                          _view = value.first;
                          _page = 0;
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() => _page = 0),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(LucideIcons.search),
                        hintText: _view == 'stock'
                            ? 'Find a product'
                            : 'Find a movement',
                        suffixIcon: searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() {
                                  searchController.clear();
                                  _page = 0;
                                }),
                                tooltip: 'Clear search',
                                icon: const Icon(LucideIcons.x),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                        child:
                            _view == 'stock' ? _stockList() : _movementList()),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _stockList() => FutureBuilder<List<Map<String, Object?>>>(
        future: widget.database.searchProducts(searchController.text),
        builder: (context, snapshot) {
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const _InventoryEmpty(
              icon: LucideIcons.packageSearch,
              message: 'No inventory is available on this device.',
            );
          }
          final start = _page * _pageSize;
          final pageProducts =
              products.skip(start).take(_pageSize).toList(growable: false);
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: pageProducts.length,
                  separatorBuilder: (_, __) => const _SoftDivider(),
                  itemBuilder: (context, index) {
                    final product = pageProducts[index];
                    final quantity = (product['quantity'] as num).toDouble();
                    final reorder =
                        (product['reorder_level'] as num?)?.toDouble() ?? 0;
                    final low = quantity <= reorder;
                    return InkWell(
                      onTap: () => _showProductActions(product),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 4),
                        child: Row(children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                                color: Color(0xffe9f5ec),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(6))),
                            child: const Icon(LucideIcons.package,
                                size: 19, color: Color(0xff16803d)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(product['name']! as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(
                                    '${product['sku'] ?? 'No SKU'}  |  ${product['unit']}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ])),
                          const SizedBox(width: 10),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(quantity.toStringAsFixed(2),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: low
                                            ? const Color(0xffb45309)
                                            : const Color(0xff146c34))),
                                const SizedBox(height: 3),
                                Text(low ? 'Low stock' : 'On hand',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: low
                                                ? const Color(0xffb45309)
                                                : null)),
                              ]),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.chevronRight, size: 18),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              PaginationControls(
                page: _page,
                hasNext: start + _pageSize < products.length,
                onPrevious: _page == 0 ? null : () => setState(() => _page--),
                onNext: start + _pageSize < products.length
                    ? () => setState(() => _page++)
                    : null,
              ),
            ],
          );
        },
      );

  Widget _movementList() => FutureBuilder<List<Map<String, Object?>>>(
        future: widget.database.inventoryMovements(),
        builder: (context, snapshot) {
          final query = searchController.text.trim().toLowerCase();
          final movements = (snapshot.data ?? []).where((item) {
            return query.isEmpty ||
                (item['product_name'] as String)
                    .toLowerCase()
                    .contains(query) ||
                (item['reason'] as String).toLowerCase().contains(query);
          }).toList();
          if (movements.isEmpty) {
            return const _InventoryEmpty(
              icon: LucideIcons.history,
              message: 'No stock movements have been recorded yet.',
            );
          }
          final start = _page * _pageSize;
          final pageMovements =
              movements.skip(start).take(_pageSize).toList(growable: false);
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: pageMovements.length,
                  separatorBuilder: (_, __) => const _SoftDivider(),
                  itemBuilder: (context, index) {
                    final movement = pageMovements[index];
                    final delta =
                        (movement['quantity_delta'] as num).toDouble();
                    final added = delta >= 0;
                    final occurredAt =
                        DateTime.tryParse(movement['occurred_at'] as String)
                            ?.toLocal();
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 13, horizontal: 4),
                      child: Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: added
                                  ? const Color(0xffe9f5ec)
                                  : const Color(0xfffff4e5),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(6))),
                          child: Icon(
                              added
                                  ? LucideIcons.arrowDownToLine
                                  : LucideIcons.arrowUpFromLine,
                              size: 18,
                              color: added
                                  ? const Color(0xff16803d)
                                  : const Color(0xffb45309)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(movement['product_name']! as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                  '${_reasonLabel(movement['reason']! as String)}${occurredAt == null ? '' : '  |  ${occurredAt.toString().substring(0, 16)}'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall),
                              if ((movement['note'] as String?)?.isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 3),
                                Text(movement['note']! as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                            ])),
                        const SizedBox(width: 12),
                        Text('${added ? '+' : ''}${delta.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: added
                                    ? const Color(0xff146c34)
                                    : const Color(0xffb45309))),
                      ]),
                    );
                  },
                ),
              ),
              PaginationControls(
                page: _page,
                hasNext: start + _pageSize < movements.length,
                onPrevious: _page == 0 ? null : () => setState(() => _page--),
                onNext: start + _pageSize < movements.length
                    ? () => setState(() => _page++)
                    : null,
              ),
            ],
          );
        },
      );

  Future<void> _showProductActions(Map<String, Object?> product) async {
    await showModalBottomSheet<void>(
      context: context,
      // Without this the sheet is capped at 9/16 of the window, which a short
      // desktop window is not tall enough to fit these three actions into.
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHeader(
                  icon: LucideIcons.package,
                  title: product['name']! as String,
                  subtitle: '${product['sku'] ?? 'No SKU'}  •  Stock actions',
                  onClose: () => Navigator.pop(sheetContext),
                ),
                const SizedBox(height: 14),
                _ProductLabel(product: product),
                const SizedBox(height: 16),
                const SectionLabel('WHAT HAPPENED'),
                const SizedBox(height: 10),
                _ActionRow(
                  icon: LucideIcons.packagePlus,
                  color: kAccent,
                  title: 'Receive stock',
                  subtitle: 'A delivery arrived from a supplier',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showReceive(product);
                  },
                ),
                const SizedBox(height: 8),
                _ActionRow(
                  icon: LucideIcons.slidersHorizontal,
                  color: const Color(0xffd08118),
                  title: 'Adjust stock',
                  subtitle: 'Damage, expiry, or a return in or out',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showAdjustment(product);
                  },
                ),
                const SizedBox(height: 8),
                _ActionRow(
                  icon: LucideIcons.clipboardCheck,
                  color: const Color(0xff1686a8),
                  title: 'Record stock count',
                  subtitle: 'Set on hand from a physical count',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showStockCount(product);
                  },
                ),
              ]),
        ),
      ),
    );
  }

  Future<String?> _branchId() async {
    final branchId = await widget.database.setting('branch_id');
    if (branchId == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choose a branch in device setup first.')));
    }
    return branchId;
  }

  Future<void> _showReceive(Map<String, Object?> product) async {
    final quantity = TextEditingController();
    final cost = TextEditingController(
        text: ((product['cost_price'] as num?) ?? 0).toStringAsFixed(2));
    final reference = TextEditingController();
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final onHand = (product['quantity'] as num?)?.toDouble() ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final received = double.tryParse(quantity.text) ?? 0;
          return _WorkflowSheet(
            icon: LucideIcons.packagePlus,
            title: 'Receive stock',
            subtitle: 'Log a delivery into inventory',
            child: Form(
              key: formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProductLabel(
                        product: product,
                        after: received == 0 ? null : onHand + received),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: quantity,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setSheetState(() {}),
                        decoration: moduleField(
                            hint: '0.00',
                            label: 'Quantity received',
                            icon: LucideIcons.packagePlus),
                        validator: (value) =>
                            (double.tryParse(value ?? '') ?? 0) <= 0
                                ? 'Enter a quantity greater than zero.'
                                : null),
                    const SizedBox(height: 10),
                    TextField(
                        controller: cost,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: moduleField(
                            hint: '0.00',
                            label: 'Unit cost',
                            icon: LucideIcons.coins)),
                    const SizedBox(height: 10),
                    TextField(
                        controller: reference,
                        decoration: moduleField(
                            hint: 'Delivery receipt or PO number',
                            label: 'Reference number',
                            icon: LucideIcons.hash)),
                    const SizedBox(height: 10),
                    TextField(
                        controller: note,
                        maxLines: 2,
                        decoration: moduleField(
                            hint: 'Anything worth remembering',
                            label: 'Note',
                            icon: LucideIcons.notepadText)),
                    const SizedBox(height: 18),
                    SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                            style: accentButton(),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final branchId = await _branchId();
                              if (branchId == null) return;
                              await widget.database.receiveInventory(
                                  branchId: branchId,
                                  productId: product['id']! as String,
                                  quantity: double.parse(quantity.text),
                                  unitCost: double.tryParse(cost.text) ?? 0,
                                  reference: _optional(reference.text),
                                  note: _optional(note.text));
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(LucideIcons.packagePlus, size: 18),
                            label: const Text('Record receipt'))),
                  ]),
            ),
          );
        },
      ),
    );
    disposeAfterClose([quantity, cost, reference, note]);
  }

  Future<void> _showAdjustment(Map<String, Object?> product) async {
    final quantity = TextEditingController();
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var reason = 'adjustment';
    final onHand = (product['quantity'] as num?)?.toDouble() ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final delta = double.tryParse(quantity.text) ?? 0;
          return _WorkflowSheet(
            icon: LucideIcons.slidersHorizontal,
            title: 'Adjust stock',
            subtitle: 'Correct on hand without a sale',
            child: Form(
              key: formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProductLabel(
                        product: product,
                        after: delta == 0 ? null : onHand + delta),
                    const SizedBox(height: 16),
                    const SectionLabel('REASON'),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final option in _adjustmentReasons)
                        FilterPill(
                          label: option.$2,
                          selected: reason == option.$1,
                          onTap: () => setSheetState(() => reason = option.$1),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: quantity,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        onChanged: (_) => setSheetState(() {}),
                        decoration: moduleField(
                            hint: 'Use a negative value to remove stock',
                            label: 'Quantity change',
                            icon: LucideIcons.diff),
                        validator: (value) =>
                            double.tryParse(value ?? '') == null ||
                                    double.tryParse(value ?? '') == 0
                                ? 'Enter a non-zero quantity.'
                                : null),
                    const SizedBox(height: 10),
                    TextField(
                        controller: note,
                        maxLines: 2,
                        decoration: moduleField(
                            hint: 'Explain the adjustment for the audit trail',
                            label: 'Reason note',
                            icon: LucideIcons.notepadText)),
                    const SizedBox(height: 18),
                    SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                            style: accentButton(),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final branchId = await _branchId();
                              if (branchId == null) return;
                              await widget.database.adjustInventory(
                                  branchId: branchId,
                                  productId: product['id']! as String,
                                  quantityDelta: double.parse(quantity.text),
                                  reason: reason,
                                  note: _optional(note.text));
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(LucideIcons.slidersHorizontal,
                                size: 18),
                            label: const Text('Record adjustment'))),
                  ]),
            ),
          );
        },
      ),
    );
    disposeAfterClose([quantity, note]);
  }

  Future<void> _showStockCount(Map<String, Object?> product) async {
    final counted = TextEditingController(
        text: ((product['quantity'] as num?) ?? 0).toStringAsFixed(2));
    final reference = TextEditingController();
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final onHand = (product['quantity'] as num?)?.toDouble() ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final entered = double.tryParse(counted.text);
          return _WorkflowSheet(
            icon: LucideIcons.clipboardCheck,
            title: 'Record stock count',
            subtitle: 'Set on hand from a physical count',
            child: Form(
              key: formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A count replaces the on-hand figure, so the number that
                    // matters to the counter is the variance it will book.
                    _ProductLabel(
                        product: product,
                        after: entered == null ? null : entered - onHand,
                        afterLabel: 'VARIANCE',
                        signed: true),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: counted,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setSheetState(() {}),
                        decoration: moduleField(
                            hint: '0.00',
                            label: 'Counted quantity',
                            icon: LucideIcons.clipboardCheck),
                        validator: (value) =>
                            (double.tryParse(value ?? '') ?? -1) < 0
                                ? 'Enter zero or a positive quantity.'
                                : null),
                    const SizedBox(height: 10),
                    TextField(
                        controller: reference,
                        decoration: moduleField(
                            hint: 'Count sheet or cycle number',
                            label: 'Count reference',
                            icon: LucideIcons.hash)),
                    const SizedBox(height: 10),
                    TextField(
                        controller: note,
                        maxLines: 2,
                        decoration: moduleField(
                            hint: 'Explain any variance you found',
                            label: 'Count note',
                            icon: LucideIcons.notepadText)),
                    const SizedBox(height: 18),
                    SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                            style: accentButton(),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final branchId = await _branchId();
                              if (branchId == null) return;
                              await widget.database.countInventory(
                                  branchId: branchId,
                                  productId: product['id']! as String,
                                  countedQuantity: double.parse(counted.text),
                                  reference: _optional(reference.text),
                                  note: _optional(note.text));
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(LucideIcons.clipboardCheck,
                                size: 18),
                            label: const Text('Save count'))),
                  ]),
            ),
          );
        },
      ),
    );
    disposeAfterClose([counted, reference, note]);
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  String _reasonLabel(String reason) => reason
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

/// Reason codes an adjustment can carry, paired with their pill labels.
const _adjustmentReasons = [
  ('adjustment', 'Adjustment'),
  ('damage', 'Damaged'),
  ('expired', 'Expired'),
  ('return_in', 'Return in'),
  ('return_out', 'Return to supplier'),
];

/// Tappable action card used by the product actions sheet.
class _ActionRow extends StatelessWidget {
  const _ActionRow(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ModuleRow(
        onTap: onTap,
        child: Row(children: [
          RowIcon(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: kInkStrong,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: kInkSoft, fontSize: 11.5, height: 1.25)),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(LucideIcons.chevronRight,
              size: 18, color: Color(0xff9db0a8)),
        ]),
      );
}

/// Scrollable, keyboard-aware shell shared by the three stock entry sheets.
class _WorkflowSheet extends StatelessWidget {
  const _WorkflowSheet(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.child});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              16, 4, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SheetHeader(
              icon: icon,
              title: title,
              subtitle: subtitle,
              onClose: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
            child,
          ]),
        ),
      );
}

/// The product a stock sheet is about, plus the figure the entry will produce.
class _ProductLabel extends StatelessWidget {
  const _ProductLabel({
    required this.product,
    this.after,
    this.afterLabel = 'AFTER THIS ENTRY',
    this.signed = false,
  });

  final Map<String, Object?> product;

  /// Resulting quantity (or variance) once the sheet is saved, when known.
  final double? after;
  final String afterLabel;

  /// Whether [after] is a change to show with an explicit sign.
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final name = product['name']! as String;
    final unit = product['unit'] as String? ?? '';
    final quantity = (product['quantity'] as num?)?.toDouble() ?? 0;
    final reorder = (product['reorder_level'] as num?)?.toDouble() ?? 0;
    final low = quantity <= reorder;
    final value = after;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kRowSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kRowBorder),
      ),
      child: Column(children: [
        Row(children: [
          RowIcon(icon: LucideIcons.package, color: accentFor(name)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: kInkStrong,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('${quantity.toStringAsFixed(2)} $unit on hand',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kInkSoft, fontSize: 11.5)),
            ]),
          ),
          if (low) ...[
            const SizedBox(width: 8),
            const StatusBadge(
                label: 'Low stock', color: kWarning, background: kWarningSoft),
          ],
        ]),
        if (value != null) ...[
          const SizedBox(height: 11),
          const SizedBox(height: 1, child: ColoredBox(color: kRowBorder)),
          const SizedBox(height: 11),
          Row(children: [
            Expanded(child: SectionLabel(afterLabel)),
            const SizedBox(width: 10),
            Text(
              signed
                  ? '${value > 0 ? '+' : ''}${value.toStringAsFixed(2)} $unit'
                  : '${value.toStringAsFixed(2)} $unit',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: value < 0
                    ? (signed ? kWarning : kDanger)
                    : (value == 0 ? kInkSoft : kMoney),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _InventoryHeading extends StatelessWidget {
  const _InventoryHeading();

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xffe9f5ec),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.boxes,
                size: 20, color: Color(0xff16803d)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inventory analytics',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Products, quantities and stock activity',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xffedf8f0),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xffcfe7d6)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 7,
                  height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: Color(0xff16803d), shape: BoxShape.circle),
                  ),
                ),
                SizedBox(width: 6),
                Text('Live stock',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      );
}

class _InventoryEmpty extends StatelessWidget {
  const _InventoryEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xffeef5f0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 21, color: const Color(0xff6e8577)),
            ),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: Color(0xffdfe9e1)));
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric(
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
      height: 124,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xffdfe9e1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: warning
                            ? const Color(0xfffff4e5)
                            : const Color(0xffe9f5ec),
                        borderRadius: BorderRadius.circular(7)),
                    child: Icon(icon, color: color, size: 17)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ]),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
