import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_menu.dart';
import 'async_dispose.dart';
import 'data/local/local_database.dart';
import 'module_fab.dart';
import 'pagination_controls.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.database});
  final LocalDatabase database;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final searchController = TextEditingController();
  static const _pageSize = 25;
  int _page = 0;
  bool _showArchived = false;

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
                Text('Products'),
                Text('Catalog management',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(children: [
            Row(children: [
              const Icon(LucideIcons.package, size: 19),
              const SizedBox(width: 8),
              Text('Product catalog',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              OutlinedButton.icon(
                  onPressed: _importProducts,
                  icon: const Icon(LucideIcons.upload, size: 18),
                  label: const Text('Import CSV')),
            ]),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      icon: Icon(LucideIcons.packageCheck, size: 17),
                      label: Text('Active')),
                  ButtonSegment(
                      value: true,
                      icon: Icon(LucideIcons.archive, size: 17),
                      label: Text('Archived')),
                ],
                selected: {_showArchived},
                onSelectionChanged: (value) => setState(() {
                  _showArchived = value.first;
                  _page = 0;
                }),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: searchController,
                onChanged: (_) => setState(() => _page = 0),
                decoration: const InputDecoration(
                    prefixIcon: Icon(LucideIcons.search),
                    hintText: 'Search by name, SKU, or barcode',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: widget.database.searchProducts(searchController.text,
                    archived: _showArchived,
                    limit: _pageSize + 1,
                    offset: _page * _pageSize),
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? [];
                  final hasNext = rows.length > _pageSize;
                  final products = rows.take(_pageSize).toList();
                  if (products.isEmpty) {
                    return Center(
                        child: Text(_showArchived
                            ? 'No archived products.'
                            : 'Add your first product to start selling.'));
                  }
                  return Column(children: [
                    Expanded(
                        child: ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const _SoftDivider(),
                      itemBuilder: (context, index) {
                        final item = products[index];
                        final quantity = (item['quantity'] as num).toDouble();
                        final low = quantity <=
                            (item['reorder_level'] as num).toDouble();
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 13, horizontal: 4),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(item['name']! as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(
                                      '${item['sku'] ?? 'No SKU'}  |  ${item['barcode'] ?? 'No barcode'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ])),
                            const SizedBox(width: 12),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                      'PHP ${(item['selling_price'] as num).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xff146c34))),
                                  const SizedBox(height: 3),
                                  Text(
                                      '${quantity.toStringAsFixed(2)} ${item['unit']}${low ? '  low' : ''}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: _showArchived
                                                  ? const Color(0xff66756a)
                                                  : low
                                                      ? const Color(0xffb45309)
                                                      : null)),
                                ]),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              tooltip: 'Product actions',
                              icon: const Icon(LucideIcons.ellipsisVertical,
                                  size: 19),
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _productEditor(existing: item);
                                  case 'archive':
                                    _setArchived(item, true);
                                  case 'restore':
                                    _setArchived(item, false);
                                  case 'delete':
                                    _deleteProduct(item);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 'edit',
                                    child: _MenuRow(
                                        icon: LucideIcons.pencil,
                                        label: 'Edit')),
                                if (_showArchived)
                                  const PopupMenuItem(
                                      value: 'restore',
                                      child: _MenuRow(
                                          icon: LucideIcons.rotateCcw,
                                          label: 'Restore'))
                                else
                                  const PopupMenuItem(
                                      value: 'archive',
                                      child: _MenuRow(
                                          icon: LucideIcons.archive,
                                          label: 'Archive')),
                                if (_showArchived) ...[
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: _MenuRow(
                                          icon: LucideIcons.trash2,
                                          label: 'Delete',
                                          color: Color(0xffb91c1c))),
                                ],
                              ],
                            ),
                          ]),
                        );
                      },
                    )),
                    PaginationControls(
                        page: _page,
                        hasNext: hasNext,
                        onPrevious:
                            _page == 0 ? null : () => setState(() => _page--),
                        onNext: () => setState(() => _page++))
                  ]);
                },
              ),
            ),
          ]),
        ),
        floatingActionButton: ModuleFab(
          onPressed: () => _productEditor(),
          icon: LucideIcons.plus,
          label: 'Add product',
          heroTag: 'products-add',
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );

  Future<void> _setArchived(Map<String, Object?> product, bool archived) async {
    try {
      await widget.database
          .setProductArchived(product['id']! as String, archived);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('${product['name']} ${archived ? 'archived' : 'restored'}.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await widget.database
                .setProductArchived(product['id']! as String, !archived);
            if (mounted) setState(() {});
          },
        ),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _deleteProduct(Map<String, Object?> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
            '${product['name']} will be permanently removed. Only archived products without completed sales, returns, held sales, stock, or inventory history can be deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffb91c1c)),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(LucideIcons.trash2, size: 18),
              label: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.database.deleteProduct(product['id']! as String);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${product['name']} deleted.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _productEditor({Map<String, Object?>? existing}) async {
    final editing = existing != null;
    const units = [
      'piece',
      'kg',
      'g',
      'liter',
      'ml',
      'box',
      'pack',
      'bag',
      'case'
    ];
    final name =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final sku = TextEditingController(text: existing?['sku'] as String? ?? '');
    final barcode =
        TextEditingController(text: existing?['barcode'] as String? ?? '');
    final price = TextEditingController(
        text: editing
            ? (existing['selling_price'] as num).toStringAsFixed(2)
            : '');
    final cost = TextEditingController(
        text:
            editing ? (existing['cost_price'] as num).toStringAsFixed(2) : '');
    final reorder = TextEditingController(
        text: editing ? '${existing['reorder_level']}' : '0');
    final formKey = GlobalKey<FormState>();
    var unit = existing?['unit'] as String? ?? 'piece';
    var taxCategory = existing?['tax_category'] as String? ?? 'vatable';
    if (!units.contains(unit)) unit = 'piece';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(editing ? 'Edit product' : 'New product',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800))),
                const SizedBox(height: 16),
                TextFormField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(
                        labelText: 'Product name',
                        border: OutlineInputBorder()),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a product name.'
                        : null),
                const SizedBox(height: 10),
                TextField(
                    controller: sku,
                    decoration: const InputDecoration(
                        labelText: 'SKU', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: barcode,
                    decoration: const InputDecoration(
                        labelText: 'Barcode', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: price,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Selling price',
                              border: OutlineInputBorder()),
                          validator: (value) =>
                              double.tryParse(value ?? '') == null
                                  ? 'Enter a price.'
                                  : null)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: cost,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Cost price',
                              border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: DropdownButtonFormField<String>(
                          initialValue: unit,
                          decoration: const InputDecoration(
                              labelText: 'Unit', border: OutlineInputBorder()),
                          items: units
                              .map((value) => DropdownMenuItem(
                                  value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) =>
                              setSheetState(() => unit = value!))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: reorder,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Reorder level',
                              border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: taxCategory,
                  decoration: const InputDecoration(
                      labelText: 'Tax category',
                      prefixIcon: Icon(LucideIcons.landmark)),
                  items: const [
                    DropdownMenuItem(value: 'vatable', child: Text('VATable')),
                    DropdownMenuItem(
                        value: 'exempt', child: Text('VAT-exempt')),
                    DropdownMenuItem(
                        value: 'zero_rated', child: Text('Zero-rated')),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => taxCategory = value ?? 'vatable'),
                ),
                const SizedBox(height: 18),
                SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          if (editing) {
                            await widget.database.updateProduct(
                                productId: existing['id']! as String,
                                name: name.text.trim(),
                                sku: _optional(sku.text),
                                barcode: _optional(barcode.text),
                                sellingPrice: double.parse(price.text),
                                costPrice: double.tryParse(cost.text) ?? 0,
                                unit: unit,
                                taxCategory: taxCategory,
                                reorderLevel:
                                    double.tryParse(reorder.text) ?? 0);
                          } else {
                            await widget.database.saveProduct(
                                name: name.text.trim(),
                                sku: _optional(sku.text),
                                barcode: _optional(barcode.text),
                                sellingPrice: double.parse(price.text),
                                costPrice: double.tryParse(cost.text) ?? 0,
                                unit: unit,
                                taxCategory: taxCategory,
                                reorderLevel:
                                    double.tryParse(reorder.text) ?? 0);
                          }
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          if (mounted) setState(() {});
                        },
                        icon: Icon(
                            editing
                                ? LucideIcons.save
                                : LucideIcons.packagePlus,
                            size: 18),
                        label:
                            Text(editing ? 'Save changes' : 'Save product'))),
              ]),
            ),
          ),
        ),
      ),
    );
    disposeAfterClose([name, sku, barcode, price, cost, reorder]);
  }

  Future<void> _importProducts() async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (picked == null || picked.files.single.bytes == null) return;
    try {
      final rows = const CsvToListConverter(shouldParseNumbers: false)
          .convert(utf8.decode(picked.files.single.bytes!));
      if (rows.length < 2) {
        throw const FormatException('The CSV does not contain product rows.');
      }
      final headers = rows.first
          .map((cell) => cell.toString().trim().toLowerCase())
          .toList();
      final required = ['name', 'selling_price'];
      if (required.any((header) => !headers.contains(header))) {
        throw const FormatException(
            'CSV requires name and selling_price columns.');
      }
      final index = {for (var i = 0; i < headers.length; i++) headers[i]: i};
      String value(List<dynamic> row, String key) =>
          index.containsKey(key) && index[key]! < row.length
              ? row[index[key]!].toString().trim()
              : '';
      final products = <Map<String, Object?>>[];
      for (var rowNumber = 1; rowNumber < rows.length; rowNumber++) {
        final row = rows[rowNumber];
        if (row.every((cell) => cell.toString().trim().isEmpty)) continue;
        final name = value(row, 'name');
        final price = double.tryParse(value(row, 'selling_price'));
        if (name.isEmpty || price == null || price < 0) {
          throw FormatException(
              'Row ${rowNumber + 1} needs a product name and valid selling price.');
        }
        products.add({
          'name': name,
          'sku': _optional(value(row, 'sku')),
          'barcode': _optional(value(row, 'barcode')),
          'sellingPrice': price,
          'costPrice': double.tryParse(value(row, 'cost_price')) ?? 0,
          'unit': value(row, 'unit').isEmpty ? 'piece' : value(row, 'unit'),
          'taxCategory': const ['vatable', 'exempt', 'zero_rated']
                  .contains(value(row, 'tax_category'))
              ? value(row, 'tax_category')
              : 'vatable',
          'reorderLevel': double.tryParse(value(row, 'reorder_level')) ?? 0
        });
      }
      if (products.isEmpty) {
        throw const FormatException(
            'The CSV does not contain valid product rows.');
      }
      for (final product in products) {
        await widget.database.saveProduct(
            name: product['name']! as String,
            sku: product['sku'] as String?,
            barcode: product['barcode'] as String?,
            sellingPrice: product['sellingPrice']! as double,
            costPrice: product['costPrice']! as double,
            unit: product['unit']! as String,
            taxCategory: product['taxCategory']! as String,
            reorderLevel: product['reorderLevel']! as double);
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${products.length} products imported locally.')));
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not import CSV: $error')));
      }
    }
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: Color(0xffdfe9e1)));
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ]);
}
