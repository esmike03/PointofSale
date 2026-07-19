import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_menu.dart';
import 'async_dispose.dart';
import 'data/local/local_database.dart';
import 'data/remote/api_client.dart';
import 'module_fab.dart';
import 'pagination_controls.dart';
import 'receipt_image.dart';
import 'receipt_profile.dart';
import 'sale_tax.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key, required this.database});
  final LocalDatabase database;

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  static const _pageSize = 20;
  final _search = TextEditingController();
  int _page = 0;
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
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
              Text('Sales'),
              Text('Receipts, returns and refunds',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          actions: [
            IconButton(
                onPressed: () => setState(() {}),
                tooltip: 'Refresh sales',
                icon: const Icon(LucideIcons.refreshCw))
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(LucideIcons.receiptText,
                  size: 19, color: Color(0xff16803d)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Transaction history',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() => _page = 0),
              decoration: InputDecoration(
                prefixIcon: const Icon(LucideIcons.search),
                hintText: 'Search receipt number',
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() {
                              _search.clear();
                              _page = 0;
                            }),
                        tooltip: 'Clear search',
                        icon: const Icon(LucideIcons.x)),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'completed', label: Text('Completed')),
                  ButtonSegment(value: 'returned', label: Text('Returned')),
                ],
                selected: {_filter},
                onSelectionChanged: (value) => setState(() {
                  _filter = value.first;
                  _page = 0;
                }),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: widget.database.recentSales(
                    query: _search.text,
                    filter: _filter,
                    limit: _pageSize + 1,
                    offset: _page * _pageSize),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  final rows = snapshot.data ?? const <Map<String, Object?>>[];
                  final sales = rows.take(_pageSize).toList();
                  if (sales.isEmpty) {
                    return Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(LucideIcons.receiptText,
                          size: 38, color: Color(0xff7d9181)),
                      const SizedBox(height: 10),
                      Text(_search.text.isEmpty
                          ? 'No completed sales on this device.'
                          : 'No receipts match your search.'),
                    ]));
                  }
                  return Column(children: [
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: sales.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) =>
                              _saleRow(sales[index]),
                        ),
                      ),
                    ),
                    PaginationControls(
                      page: _page,
                      hasNext: rows.length > _pageSize,
                      onPrevious:
                          _page == 0 ? null : () => setState(() => _page--),
                      onNext: rows.length > _pageSize
                          ? () => setState(() => _page++)
                          : null,
                    ),
                  ]);
                },
              ),
            ),
          ]),
        ),
        floatingActionButton: ModuleFab(
          onPressed: _returnByReceipt,
          icon: LucideIcons.undo2,
          label: 'Return by receipt',
          heroTag: 'sales-return',
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );

  Future<void> _returnByReceipt() async {
    final receipt = TextEditingController(text: 'TRX-');
    final sale = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.viewInsetsOf(sheet).bottom + 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(LucideIcons.undo2, color: Color(0xff16803d)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Return by receipt',
                          style: Theme.of(sheet)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800))),
                  IconButton(
                      onPressed: () => Navigator.pop(sheet),
                      tooltip: 'Close',
                      icon: const Icon(LucideIcons.x)),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: receipt,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                      labelText: 'Receipt number', hintText: 'TRX-...'),
                  onSubmitted: (_) => _verifyReturnReceipt(sheet, receipt.text),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _verifyReturnReceipt(sheet, receipt.text),
                  icon: const Icon(LucideIcons.search, size: 18),
                  label: const Text('Verify receipt'),
                ),
              ]),
        ),
      ),
    );
    disposeAfterClose([receipt]);
    if (sale != null && mounted) await _receipt(sale);
  }

  Future<void> _verifyReturnReceipt(BuildContext sheet, String value) async {
    final number = value.trim().toUpperCase();
    if (!RegExp(r'^TRX-[A-Z0-9-]+$').hasMatch(number)) {
      ScaffoldMessenger.of(sheet).showSnackBar(
          const SnackBar(content: Text('Enter a valid TRX receipt number.')));
      return;
    }
    var sale = await widget.database.saleByReceiptNumber(number);
    if (sale == null) {
      final server = await widget.database.setting('server_url');
      final token = await widget.database.setting('token');
      if (server != null && token != null && token.isNotEmpty) {
        try {
          final remote = await ApiClient(Uri.parse(server), token: token)
              .saleByReceipt(number);
          if (remote != null) {
            await widget.database.cacheServerReceipt(remote);
            sale = await widget.database.saleByReceiptNumber(number);
          }
        } catch (_) {
          // The local receipt lookup remains available when the server is offline.
        }
      }
    }
    if (!sheet.mounted) return;
    if (sale == null) {
      ScaffoldMessenger.of(sheet).showSnackBar(
          const SnackBar(content: Text('Receipt not found on this device.')));
      return;
    }
    Navigator.pop(sheet, sale);
  }

  Widget _saleRow(Map<String, Object?> sale) {
    final total = (sale['net_amount'] as num).toDouble();
    final refunded = (sale['refunded_amount'] as num?)?.toDouble() ?? 0;
    final fullyRefunded = refunded >= total - .005;
    final createdAt =
        DateTime.tryParse(sale['occurred_at']! as String)?.toLocal();
    final date = createdAt == null
        ? ''
        : '${createdAt.month}/${createdAt.day}/${createdAt.year}  ${TimeOfDay.fromDateTime(createdAt).format(context)}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: Color(0xffe9f5ec),
            borderRadius: BorderRadius.all(Radius.circular(6))),
        child: const Icon(LucideIcons.receiptText,
            size: 19, color: Color(0xff16803d)),
      ),
      title: Row(children: [
        Flexible(
            child: Text(sale['receipt_number']! as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800))),
        if (refunded > 0) ...[
          const SizedBox(width: 8),
          _StatusBadge(label: fullyRefunded ? 'Refunded' : 'Partial refund'),
        ],
      ]),
      subtitle: Text(
          '${sale['receipt_name'] == null ? '' : '${sale['receipt_name']}  |  '}$date',
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PHP ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Color(0xff146c34))),
              if (refunded > 0)
                Text('-PHP ${refunded.toStringAsFixed(2)} returned',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xffb42318))),
            ]),
        const SizedBox(width: 8),
        const Icon(LucideIcons.chevronRight, size: 18),
      ]),
      onTap: () => _receipt(sale),
    );
  }

  Future<void> _receipt(Map<String, Object?> sale) async {
    final data = await widget.database.saleReceipt(sale['id']! as String);
    if (!mounted) return;
    final total = (sale['net_amount'] as num).toDouble();
    final refunded = data['refunds']!.fold<double>(
        0, (sum, refund) => sum + (refund['amount'] as num).toDouble());
    final profile = sale['receipt_profile'] == null
        ? await ReceiptProfile.load(widget.database)
        : ReceiptProfile.fromSale(sale);
    final tax = SaleTaxSummary.fromSale(sale);
    if (!mounted) return;
    final boundaryKey = GlobalKey();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => FractionallySizedBox(
        heightFactor: .88,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(LucideIcons.receiptText,
                        color: Color(0xff16803d)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Sale receipt',
                              style: Theme.of(sheet)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          Text(sale['receipt_number']! as String,
                              style: Theme.of(sheet).textTheme.bodySmall),
                          if (sale['receipt_name'] != null)
                            Text(sale['receipt_name']! as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                        ])),
                    IconButton(
                        onPressed: () => Navigator.pop(sheet),
                        tooltip: 'Close',
                        icon: const Icon(LucideIcons.x)),
                  ]),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(children: [
                        RepaintBoundary(
                          key: boundaryKey,
                          child: ReceiptImage(
                            receiptNumber: sale['receipt_number']! as String,
                            receiptName: sale['receipt_name'] as String?,
                            occurredAt: sale['occurred_at'] as String?,
                            items: data['items']!,
                            payments: data['payments']!,
                            total: total,
                            discount:
                                (sale['discount_amount'] as num).toDouble(),
                            discountReason: sale['discount_reason'] as String?,
                            refunded: refunded,
                            profile: profile,
                            tax: tax,
                          ),
                        ),
                        if (data['refunds']!.isNotEmpty) ...[
                          const Divider(height: 24),
                          Text('Refund history',
                              style: Theme.of(sheet)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          for (final refund in data['refunds']!)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(LucideIcons.undo2,
                                  size: 18, color: Color(0xffb42318)),
                              title: Text(refund['refund_number']! as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${refund['reason']}  |  ${_title(refund['method']! as String)}'),
                              trailing: Text(
                                  '-PHP ${(refund['amount'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xffb42318))),
                            ),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final path = await saveReceiptPng(
                            boundaryKey, sale['receipt_number']! as String);
                        if (path != null && sheet.mounted) {
                          ScaffoldMessenger.of(sheet).showSnackBar(SnackBar(
                              content: Text('Receipt image saved to $path')));
                        }
                      } catch (error) {
                        if (sheet.mounted) {
                          ScaffoldMessenger.of(sheet).showSnackBar(SnackBar(
                              content: Text(
                                  'Could not save receipt image: $error')));
                        }
                      }
                    },
                    icon: const Icon(LucideIcons.download, size: 18),
                    label: const Text('Download receipt image'),
                  ),
                  if (refunded < total - .005) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final completed =
                              await _refundSale(sale, data['items']!);
                          if (completed && sheet.mounted) Navigator.pop(sheet);
                        },
                        icon: const Icon(LucideIcons.undo2, size: 18),
                        label: const Text('Return items and issue refund'),
                      ),
                    ),
                  ],
                ]),
          ),
        ),
      ),
    );
  }

  Future<bool> _refundSale(
      Map<String, Object?> sale, List<Map<String, Object?>> items) async {
    final reason = TextEditingController();
    final quantities = <String, TextEditingController>{
      for (final item in items)
        item['id']! as String: TextEditingController(
            text: ((item['quantity'] as num).toDouble() -
                    (item['returned_quantity'] as num).toDouble())
                .toStringAsFixed(2)),
    };
    final selected = <String>{};
    var method = 'cash';
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheetState) => FractionallySizedBox(
          heightFactor: .9,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, MediaQuery.viewInsetsOf(sheet).bottom + 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(LucideIcons.undo2, color: Color(0xff16803d)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Return sale items',
                                style: Theme.of(sheet)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(sale['receipt_number']! as String,
                                style: Theme.of(sheet).textTheme.bodySmall),
                          ])),
                      IconButton(
                          onPressed: () => Navigator.pop(sheet, false),
                          tooltip: 'Close',
                          icon: const Icon(LucideIcons.x)),
                    ]),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(children: [
                        const SizedBox(height: 10),
                        Text('Select returned products',
                            style: Theme.of(sheet)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        for (final item in items)
                          if ((item['quantity'] as num).toDouble() -
                                  (item['returned_quantity'] as num)
                                      .toDouble() >
                              .0001)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: selected.contains(item['id']),
                              onChanged: (value) => setSheetState(() =>
                                  value == true
                                      ? selected.add(item['id']! as String)
                                      : selected.remove(item['id'])),
                              title: Text(item['product_name']! as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${((item['quantity'] as num).toDouble() - (item['returned_quantity'] as num).toDouble()).toStringAsFixed(2)} available to return'),
                              secondary: selected.contains(item['id'])
                                  ? SizedBox(
                                      width: 92,
                                      child: TextField(
                                        controller: quantities[item['id']],
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        decoration: const InputDecoration(
                                            labelText: 'Quantity',
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 10)),
                                      ),
                                    )
                                  : null,
                            ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: method,
                          decoration:
                              const InputDecoration(labelText: 'Refund method'),
                          items: const [
                            DropdownMenuItem(
                                value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(
                                value: 'card', child: Text('Card')),
                            DropdownMenuItem(
                                value: 'gcash', child: Text('GCash')),
                            DropdownMenuItem(
                                value: 'maya', child: Text('Maya')),
                            DropdownMenuItem(
                                value: 'bank_transfer',
                                child: Text('Bank transfer')),
                          ],
                          onChanged: (value) => method = value!,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                            controller: reason,
                            maxLines: 2,
                            decoration: const InputDecoration(
                                labelText: 'Refund reason',
                                hintText:
                                    'Example: Damaged item or wrong product')),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final returnItems = <Map<String, Object?>>[];
                          for (final item in items
                              .where((item) => selected.contains(item['id']))) {
                            final quantity =
                                double.tryParse(quantities[item['id']]!.text) ??
                                    0;
                            final available = (item['quantity'] as num)
                                    .toDouble() -
                                (item['returned_quantity'] as num).toDouble();
                            if (quantity <= 0 || quantity > available + .0001) {
                              ScaffoldMessenger.of(sheet).showSnackBar(SnackBar(
                                  content: Text(
                                      'Enter a valid quantity for ${item['product_name']}.')));
                              return;
                            }
                            returnItems.add({
                              'sale_item_id': item['id'],
                              'quantity': quantity
                            });
                          }
                          if (returnItems.isEmpty ||
                              reason.text.trim().isEmpty) {
                            ScaffoldMessenger.of(sheet).showSnackBar(const SnackBar(
                                content: Text(
                                    'Select products and enter a refund reason.')));
                            return;
                          }
                          try {
                            final number = await widget.database.refundSale(
                                saleId: sale['id']! as String,
                                items: returnItems,
                                method: method,
                                reason: reason.text);
                            if (!mounted || !sheet.mounted) return;
                            Navigator.pop(sheet, true);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    '$number saved. Returned stock is available in inventory.')));
                          } catch (error) {
                            if (sheet.mounted) {
                              ScaffoldMessenger.of(sheet).showSnackBar(
                                  SnackBar(content: Text(error.toString())));
                            }
                          }
                        },
                        icon: const Icon(LucideIcons.undo2, size: 18),
                        label: const Text('Complete refund'),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
    disposeAfterClose([reason, ...quantities.values]);
    return completed == true;
  }

  String _title(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: const BoxDecoration(
            color: Color(0xffffebe9),
            borderRadius: BorderRadius.all(Radius.circular(6))),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xffb42318))),
      );
}
