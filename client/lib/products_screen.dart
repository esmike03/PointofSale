import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'async_dispose.dart';
import 'data/local/local_database.dart';
import 'module_fab.dart';
import 'pagination_controls.dart';
import 'ui_kit.dart';

List<List<dynamic>> _parseProductCsv(Uint8List bytes) =>
    const CsvToListConverter(shouldParseNumbers: false)
        .convert(utf8.decode(bytes));

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
  bool _importing = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kPageTop,
        appBar: ModuleAppBar(
          title: 'Products',
          subtitle: 'Catalog management',
          actions: [
            _importing
                ? Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kSoftControl,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : SoftIconButton(
                    icon: LucideIcons.upload,
                    tooltip: 'Import products from CSV',
                    onPressed: _importProducts,
                  ),
          ],
        ),
        body: ModuleBody(
          child: ModulePanel(
            fill: true,
            icon: LucideIcons.package,
            title: 'Product catalog',
            subtitle: 'Add, edit and archive what you sell',
            child: Expanded(
              child: Column(children: [
                ModuleSearchField(
                  controller: searchController,
                  hint: 'Search by name, SKU, or barcode',
                  onChanged: (_) => setState(() => _page = 0),
                ),
                const SizedBox(height: 12),
                FilterPillBar(children: [
                  FilterPill(
                    label: 'Active',
                    icon: LucideIcons.packageCheck,
                    selected: !_showArchived,
                    onTap: () => _selectArchived(false),
                  ),
                  FilterPill(
                    label: 'Archived',
                    icon: LucideIcons.archive,
                    selected: _showArchived,
                    onTap: () => _selectArchived(true),
                  ),
                ]),
                const SizedBox(height: 13),
                Expanded(
                  child: FutureBuilder<List<Map<String, Object?>>>(
                    future: widget.database.searchProducts(
                        searchController.text,
                        archived: _showArchived,
                        limit: _pageSize + 1,
                        offset: _page * _pageSize),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          snapshot.data == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final rows = snapshot.data ?? [];
                      final hasNext = rows.length > _pageSize;
                      final products = rows.take(_pageSize).toList();
                      if (products.isEmpty) {
                        return ModuleEmpty(
                          icon: searchController.text.isEmpty
                              ? LucideIcons.packageSearch
                              : LucideIcons.searchX,
                          title: searchController.text.isNotEmpty
                              ? 'No products match your search'
                              : _showArchived
                                  ? 'Nothing archived'
                                  : 'No products yet',
                          message: searchController.text.isNotEmpty
                              ? 'Try another name, SKU or barcode.'
                              : _showArchived
                                  ? 'Archived products are kept here for reference.'
                                  : 'Add your first product to start selling.',
                        );
                      }
                      return Column(children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.only(top: 2, bottom: 4),
                            itemCount: products.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _productRow(products[index]),
                          ),
                        ),
                        PaginationControls(
                            page: _page,
                            hasNext: hasNext,
                            onPrevious: _page == 0
                                ? null
                                : () => setState(() => _page--),
                            onNext:
                                hasNext ? () => setState(() => _page++) : null),
                      ]);
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),
        floatingActionButton: ModuleFab(
          onPressed: () => _productEditor(),
          icon: LucideIcons.plus,
          label: 'Add product',
          heroTag: 'products-add',
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );

  void _selectArchived(bool archived) => setState(() {
        _showArchived = archived;
        _page = 0;
      });

  Widget _productRow(Map<String, Object?> item) {
    final name = item['name']! as String;
    final quantity = (item['quantity'] as num).toDouble();
    final low = quantity <= (item['reorder_level'] as num).toDouble();
    final accent = _showArchived ? const Color(0xff7c8f88) : accentFor(name);
    return ModuleRow(
      onTap: () => _productEditor(existing: item),
      child: Row(children: [
        RowIcon(icon: LucideIcons.package, color: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: kInkStrong, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Row(children: [
                if (_showArchived) ...[
                  const Flexible(
                    child: StatusBadge(
                      label: 'Archived',
                      color: Color(0xff5c6f68),
                      background: Color(0xffeef2f0),
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else if (low) ...[
                  const Flexible(
                    child: StatusBadge(
                      label: 'Low stock',
                      color: kWarning,
                      background: kWarningSoft,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    '${item['sku'] ?? 'No SKU'}  •  ${item['barcode'] ?? 'No barcode'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kInkSoft, fontSize: 11.5),
                  ),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 104),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                php(item['selling_price'] as num),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(color: kMoney, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2)} ${item['unit']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: low && !_showArchived ? kWarning : kInkSoft,
                  fontSize: 10.5,
                  fontWeight:
                      low && !_showArchived ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Product actions',
          icon: const Icon(LucideIcons.ellipsisVertical,
              size: 18, color: Color(0xff8fa49c)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                child: _MenuRow(icon: LucideIcons.pencil, label: 'Edit')),
            if (_showArchived)
              const PopupMenuItem(
                  value: 'restore',
                  child:
                      _MenuRow(icon: LucideIcons.rotateCcw, label: 'Restore'))
            else
              const PopupMenuItem(
                  value: 'archive',
                  child: _MenuRow(icon: LucideIcons.archive, label: 'Archive')),
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
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kDangerSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(LucideIcons.trash2, color: kDanger, size: 23),
        ),
        title: const Text('Delete product?',
            style: TextStyle(fontWeight: FontWeight.w800, color: kInk)),
        content: Text(
          '${product['name']} will be permanently removed. Only archived products without completed sales, returns, held sales, stock, or inventory history can be deleted. This cannot be undone.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kInkSoft, fontSize: 12.5, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton.icon(
              style: accentButton(background: const Color(0xffb91c1c)),
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
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 4, 16, MediaQuery.viewInsetsOf(sheetContext).bottom + 16),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SheetHeader(
                  icon: editing ? LucideIcons.pencil : LucideIcons.packagePlus,
                  title: editing ? 'Edit product' : 'New product',
                  subtitle: editing
                      ? existing['name'] as String?
                      : 'Add an item to your catalog',
                  onClose: () => Navigator.pop(sheetContext),
                ),
                const SizedBox(height: 16),
                TextFormField(
                    controller: name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: moduleField(
                        hint: 'Example: Kopiko Black 3in1',
                        label: 'Product name',
                        icon: LucideIcons.package),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a product name.'
                        : null),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: sku,
                          decoration: moduleField(
                              hint: 'SKU',
                              label: 'SKU',
                              icon: LucideIcons.hash))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: barcode,
                          decoration: moduleField(
                              hint: 'Barcode',
                              label: 'Barcode',
                              icon: LucideIcons.scanBarcode))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: price,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: moduleField(
                              hint: '0.00',
                              label: 'Selling price',
                              icon: LucideIcons.banknote),
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
                          decoration: moduleField(
                              hint: '0.00',
                              label: 'Cost price',
                              icon: LucideIcons.coins))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: DropdownButtonFormField<String>(
                          initialValue: unit,
                          decoration: moduleField(
                              hint: 'Unit',
                              label: 'Unit',
                              icon: LucideIcons.ruler),
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
                          decoration: moduleField(
                              hint: '0',
                              label: 'Reorder level',
                              icon: LucideIcons.triangleAlert))),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: taxCategory,
                  decoration: moduleField(
                      hint: 'Tax category',
                      label: 'Tax category',
                      icon: LucideIcons.landmark),
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
                    height: 52,
                    child: FilledButton.icon(
                        style: accentButton(),
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
    if (!mounted || picked == null || picked.files.single.bytes == null) return;

    final progress = ValueNotifier<_ProductImportProgress>(
      const _ProductImportProgress(
        phase: 'Reading CSV',
        message: 'Preparing the product file...',
      ),
    );
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    setState(() => _importing = true);
    var progressDismissed = false;
    final progressDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => _ProductImportProgressDialog(progress: progress),
    );

    Future<void> dismissProgress() async {
      if (progressDismissed) return;
      progressDismissed = true;
      if (rootNavigator.mounted && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      await progressDialog;
    }

    try {
      // Parse away from the UI isolate so a large CSV does not freeze the
      // progress dialog before row validation begins.
      final rows = await compute(_parseProductCsv, picked.files.single.bytes!);
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
      // Seed the de-duplication sets with products already in the database, so
      // an import can't create duplicates of existing items or of each other.
      progress.value = const _ProductImportProgress(
        phase: 'Checking catalog',
        message: 'Comparing the CSV with products already on this device...',
      );
      final existing = await widget.database.allProductIdentifiers();
      final seenNames = <String>{};
      final seenBarcodes = <String>{};
      for (final row in existing) {
        final existingName =
            (row['name'] as String?)?.trim().toLowerCase() ?? '';
        if (existingName.isNotEmpty) seenNames.add(existingName);
        final existingBarcode =
            (row['barcode'] as String?)?.trim().toLowerCase() ?? '';
        if (existingBarcode.isNotEmpty) seenBarcodes.add(existingBarcode);
      }
      final products = <Map<String, Object?>>[];
      var duplicates = 0;
      final rowTotal = rows.length - 1;
      for (var rowNumber = 1; rowNumber < rows.length; rowNumber++) {
        final row = rows[rowNumber];
        final name = value(row, 'name');
        if (rowNumber == 1 || rowNumber % 250 == 0 || rowNumber == rowTotal) {
          progress.value = _ProductImportProgress(
            phase: 'Validating CSV',
            message: '$rowNumber of $rowTotal rows checked',
            processed: rowNumber,
            total: rowTotal,
            currentItem: name.isEmpty ? 'CSV row ${rowNumber + 1}' : name,
          );
          // Let Flutter paint progress during very large imports.
          await Future<void>.delayed(Duration.zero);
        }
        if (row.every((cell) => cell.toString().trim().isEmpty)) continue;
        final barcode = value(row, 'barcode');
        final price = double.tryParse(value(row, 'selling_price'));
        if (name.isEmpty || price == null || price < 0) {
          throw FormatException(
              'Row ${rowNumber + 1} needs a product name and valid selling price.');
        }
        // A row is a duplicate if its barcode (when present) or its name
        // already exists in the database or earlier in this same file.
        final nameKey = name.toLowerCase();
        final barcodeKey = barcode.toLowerCase();
        if (seenNames.contains(nameKey) ||
            (barcodeKey.isNotEmpty && seenBarcodes.contains(barcodeKey))) {
          duplicates++;
          continue;
        }
        seenNames.add(nameKey);
        if (barcodeKey.isNotEmpty) seenBarcodes.add(barcodeKey);
        products.add({
          'name': name,
          'sku': _optional(value(row, 'sku')),
          'barcode': _optional(barcode),
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
        throw FormatException(duplicates > 0
            ? 'Nothing imported: all $duplicates row(s) are duplicates of existing products.'
            : 'The CSV does not contain valid product rows.');
      }
      progress.value = _ProductImportProgress(
        phase: 'Saving products',
        message: '0 of ${products.length} products saved',
        total: products.length,
      );
      final updateClock = Stopwatch()..start();
      final imported = await widget.database.importProducts(
        products,
        onProgress: (processed, total, currentProduct) {
          // Database callbacks occur for every row. Limit visual rebuilds to
          // roughly ten per second while always showing the final count.
          if (processed != total && updateClock.elapsedMilliseconds < 100) {
            return;
          }
          updateClock.reset();
          progress.value = _ProductImportProgress(
            phase: 'Saving products',
            message: '$processed of $total products saved',
            processed: processed,
            total: total,
            currentItem: currentProduct,
          );
        },
      );
      await dismissProgress();
      if (mounted) {
        // Jump back to the active tab, first page, cleared search so the newly
        // imported products are visible immediately, and rebuild to re-query.
        setState(() {
          _importing = false;
          _showArchived = false;
          _page = 0;
          searchController.clear();
        });
        await _showImportResult(imported: imported, skipped: duplicates);
      }
    } on FormatException catch (error) {
      await dismissProgress();
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      await dismissProgress();
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not import CSV: $error')));
      }
    } finally {
      await dismissProgress();
      progress.dispose();
      if (mounted && _importing) setState(() => _importing = false);
    }
  }

  /// Shows a summary of what the import did once it finishes.
  Future<void> _showImportResult(
      {required int imported, required int skipped}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kAccentSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(LucideIcons.circleCheck, color: kAccent, size: 24),
        ),
        title: const Text('Import complete',
            style: TextStyle(fontWeight: FontWeight.w800, color: kInk)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _ImportStat(
              label: 'Products imported', value: '$imported', highlight: true),
          const SizedBox(height: 8),
          _ImportStat(label: 'Duplicates skipped', value: '$skipped'),
          if (skipped > 0) ...[
            const SizedBox(height: 12),
            const Text(
              'Duplicates match an existing product by barcode or name and were not added.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kInkSoft, fontSize: 12, height: 1.4),
            ),
          ],
        ]),
        actions: [
          FilledButton(
              style: accentButton(),
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Done')),
        ],
      ),
    );
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();
}

class _ProductImportProgress {
  const _ProductImportProgress({
    required this.phase,
    required this.message,
    this.processed = 0,
    this.total = 0,
    this.currentItem,
  });

  final String phase;
  final String message;
  final int processed;
  final int total;
  final String? currentItem;
}

class _ProductImportProgressDialog extends StatelessWidget {
  const _ProductImportProgressDialog({required this.progress});

  final ValueListenable<_ProductImportProgress> progress;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const Key('product-import-progress-dialog'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kAccentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(LucideIcons.fileUp, color: kAccent, size: 24),
          ),
          title: const Text(
            'Importing products',
            style: TextStyle(fontWeight: FontWeight.w800, color: kInk),
          ),
          content: SizedBox(
            width: 360,
            child: ValueListenableBuilder<_ProductImportProgress>(
              valueListenable: progress,
              builder: (context, value, _) {
                final determinate = value.total > 0;
                final fraction = determinate
                    ? (value.processed / value.total).clamp(0.0, 1.0)
                    : null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.phase,
                      style: const TextStyle(
                        color: kInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(value.message,
                        style: const TextStyle(
                            color: kInkSoft, fontSize: 12.5, height: 1.35)),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      key: const Key('product-import-progress-bar'),
                      value: fraction,
                      minHeight: 9,
                      borderRadius: BorderRadius.circular(99),
                      backgroundColor: kSoftControl,
                      color: kAccent,
                    ),
                    if (value.currentItem != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kSoftControl,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT PRODUCT',
                              style: TextStyle(
                                color: kInkSoft,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              value.currentItem!,
                              key: const Key('product-import-current-item'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: kInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 13),
                    const Text(
                      'Keep the app open until the import is complete.',
                      style: TextStyle(color: kInkSoft, fontSize: 11.5),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
}

class _ImportStat extends StatelessWidget {
  const _ImportStat(
      {required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: kInkSoft, fontSize: 12.5)),
          const SizedBox(width: 16),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: highlight ? 18 : 14,
                  color: highlight ? kAccent : kInk)),
        ],
      );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color ?? kSoftControlInk),
        const SizedBox(width: 10),
        Text(label,
            style:
                TextStyle(color: color ?? kInk, fontWeight: FontWeight.w600)),
      ]);
}
