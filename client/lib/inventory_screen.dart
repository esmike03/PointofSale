import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_menu.dart';
import 'async_dispose.dart';
import 'data/local/local_database.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.database});
  final LocalDatabase database;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final searchController = TextEditingController();
  String _view = 'stock';

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
        ),
        body: Padding(
          padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 600 ? 12 : 20, 16,
              MediaQuery.sizeOf(context).width < 600 ? 12 : 20, 20),
          child: Column(children: [
            Row(children: [
              const Icon(LucideIcons.boxes, size: 19),
              const SizedBox(width: 8),
              Text('Inventory analytics',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text('Live stock', style: Theme.of(context).textTheme.bodySmall),
            ]),
            const SizedBox(height: 14),
            FutureBuilder<Map<String, num>>(
              future: widget.database.inventorySummary(),
              builder: (context, snapshot) {
                final summary = snapshot.data;
                return LayoutBuilder(builder: (context, constraints) {
                  const spacing = 10.0;
                  final rawColumns = (constraints.maxWidth / 200).floor();
                  final columns = rawColumns < 2 ? 2 : rawColumns;
                  final cardWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) / columns;
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
            const SizedBox(height: 20),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                        onSelectionChanged: (value) =>
                            setState(() => _view = value.first),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(LucideIcons.search),
                        hintText: _view == 'stock'
                            ? 'Find a product'
                            : 'Find a movement',
                        border: const OutlineInputBorder(),
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
            return const Center(
                child: Text('No inventory is available on this device.'));
          }
          return ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, __) => const _SoftDivider(),
            itemBuilder: (context, index) {
              final product = products[index];
              final quantity = (product['quantity'] as num).toDouble();
              final reorder =
                  (product['reorder_level'] as num?)?.toDouble() ?? 0;
              final low = quantity <= reorder;
              return InkWell(
                onTap: () => _showProductActions(product),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: Color(0xffe9f5ec),
                          borderRadius: BorderRadius.all(Radius.circular(6))),
                      child: const Icon(LucideIcons.package,
                          size: 19, color: Color(0xff16803d)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(product['name']! as String,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(
                              '${product['sku'] ?? 'No SKU'}  |  ${product['unit']}',
                              style: Theme.of(context).textTheme.bodySmall),
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
            return const Center(
                child: Text('No stock movements have been recorded yet.'));
          }
          return ListView.separated(
            itemCount: movements.length,
            separatorBuilder: (_, __) => const _SoftDivider(),
            itemBuilder: (context, index) {
              final movement = movements[index];
              final delta = (movement['quantity_delta'] as num).toDouble();
              final added = delta >= 0;
              final occurredAt =
                  DateTime.tryParse(movement['occurred_at'] as String)
                      ?.toLocal();
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
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
                              style: Theme.of(context).textTheme.bodySmall),
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
          );
        },
      );

  Future<void> _showProductActions(Map<String, Object?> product) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(product['name']! as String,
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    '${product['quantity']} ${product['unit']} currently on hand',
                    style: Theme.of(sheetContext).textTheme.bodySmall),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showReceive(product);
                    },
                    icon: const Icon(LucideIcons.packagePlus),
                    label: const Text('Receive stock')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showAdjustment(product);
                    },
                    icon: const Icon(LucideIcons.slidersHorizontal),
                    label: const Text('Adjust stock')),
                const SizedBox(height: 8),
                FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showStockCount(product);
                    },
                    icon: const Icon(LucideIcons.clipboardCheck),
                    label: const Text('Record stock count')),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _WorkflowSheet(
        title: 'Receive stock',
        child: Form(
          key: formKey,
          child: Column(children: [
            _ProductLabel(product: product),
            const SizedBox(height: 14),
            TextFormField(
                controller: quantity,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Quantity received',
                    border: OutlineInputBorder()),
                validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                    ? 'Enter a quantity greater than zero.'
                    : null),
            const SizedBox(height: 10),
            TextField(
                controller: cost,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Unit cost', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: reference,
                decoration: const InputDecoration(
                    labelText: 'Reference number',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Note', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
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
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(LucideIcons.packagePlus),
                    label: const Text('Record receipt'))),
          ]),
        ),
      ),
    );
    disposeAfterClose([quantity, cost, reference, note]);
  }

  Future<void> _showAdjustment(Map<String, Object?> product) async {
    final quantity = TextEditingController();
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var reason = 'adjustment';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => _WorkflowSheet(
          title: 'Adjust stock',
          child: Form(
            key: formKey,
            child: Column(children: [
              _ProductLabel(product: product),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(
                    labelText: 'Reason', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'adjustment', child: Text('Adjustment')),
                  DropdownMenuItem(
                      value: 'damage', child: Text('Damaged stock')),
                  DropdownMenuItem(
                      value: 'expired', child: Text('Expired stock')),
                  DropdownMenuItem(
                      value: 'return_in', child: Text('Customer return in')),
                  DropdownMenuItem(
                      value: 'return_out', child: Text('Return to supplier')),
                ],
                onChanged: (value) => setSheetState(() => reason = value!),
              ),
              const SizedBox(height: 10),
              TextFormField(
                  controller: quantity,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: const InputDecoration(
                      labelText: 'Quantity change',
                      hintText: 'Use a negative value to remove stock',
                      border: OutlineInputBorder()),
                  validator: (value) => double.tryParse(value ?? '') == null ||
                          double.tryParse(value ?? '') == 0
                      ? 'Enter a non-zero quantity.'
                      : null),
              const SizedBox(height: 10),
              TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Reason note', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
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
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(LucideIcons.slidersHorizontal),
                      label: const Text('Record adjustment'))),
            ]),
          ),
        ),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _WorkflowSheet(
        title: 'Record stock count',
        child: Form(
          key: formKey,
          child: Column(children: [
            _ProductLabel(product: product),
            const SizedBox(height: 14),
            TextFormField(
                controller: counted,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Counted quantity',
                    border: OutlineInputBorder()),
                validator: (value) => (double.tryParse(value ?? '') ?? -1) < 0
                    ? 'Enter zero or a positive quantity.'
                    : null),
            const SizedBox(height: 10),
            TextField(
                controller: reference,
                decoration: const InputDecoration(
                    labelText: 'Count reference',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Count note', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
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
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(LucideIcons.clipboardCheck),
                    label: const Text('Save count'))),
          ]),
        ),
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

class _WorkflowSheet extends StatelessWidget {
  const _WorkflowSheet({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          child
        ])),
      );
}

class _ProductLabel extends StatelessWidget {
  const _ProductLabel({required this.product});
  final Map<String, Object?> product;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
            color: Color(0xffeff8f1),
            borderRadius: BorderRadius.all(Radius.circular(6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product['name']! as String,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('${product['quantity']} ${product['unit']} on hand',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
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
                child: Icon(icon, color: color, size: 19)),
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
