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

// Shared palette with the Sale (point of sale) screen so both modules read as
// one product.
const _pageBackground = Color(0xfff3f8f5);
const _panelBorder = Color(0xffe1ebe7);
const _accent = Color(0xff0e8a60);
const _accentSoft = Color(0xffe4f7ef);
const _ink = Color(0xff173f34);
const _inkSoft = Color(0xff74877f);
const _money = Color(0xff126d50);
const _rowSurface = Color(0xfffbfdfc);
const _rowBorder = Color(0xffe6eeea);
const _danger = Color(0xffb42318);
const _warning = Color(0xffa86100);

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
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: _pageBackground,
        surfaceTintColor: Colors.transparent,
        leading: AppMenu.leadingOf(context),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales'),
            Text(
              'Receipts, returns and refunds',
              style: TextStyle(
                color: Color(0xff6c827a),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: _SoftIconButton(
                icon: LucideIcons.refreshCw,
                tooltip: 'Refresh sales',
                onPressed: () => setState(() {}),
              ),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_pageBackground, Color(0xfff8fbf6)],
          ),
        ),
        child: Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(12, 10, 12, 12)
              : const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: _historyPanel(compact),
        ),
      ),
      floatingActionButton: ModuleFab(
        onPressed: _returnByReceipt,
        icon: LucideIcons.undo2,
        label: 'Return by receipt',
        heroTag: 'sales-return',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _historyPanel(bool compact) => Container(
        padding:
            EdgeInsets.fromLTRB(compact ? 12 : 16, 16, compact ? 12 : 16, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _panelBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  const Icon(LucideIcons.receiptText, size: 20, color: _accent),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction history',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Tap a receipt to reprint or refund it',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _inkSoft, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 15),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() => _page = 0),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xfff4f8f6),
              prefixIcon: const Icon(LucideIcons.search,
                  size: 20, color: Color(0xff5f7b72)),
              hintText: 'Search receipt number',
              hintStyle: const TextStyle(color: Color(0xff8ca099)),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() {
                        _search.clear();
                        _page = 0;
                      }),
                      tooltip: 'Clear search',
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: Color(0xffe1ebe6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide:
                    const BorderSide(color: Color(0xff15a675), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterPill(
                label: 'All',
                icon: LucideIcons.receiptText,
                selected: _filter == 'all',
                onTap: () => _selectFilter('all'),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Completed',
                icon: LucideIcons.circleCheck,
                selected: _filter == 'completed',
                onTap: () => _selectFilter('completed'),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Returned',
                icon: LucideIcons.undo2,
                selected: _filter == 'returned',
                onTap: () => _selectFilter('returned'),
              ),
            ]),
          ),
          const SizedBox(height: 13),
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
                  return _EmptyState(
                    icon: LucideIcons.triangleAlert,
                    title: 'Sales could not be loaded',
                    message: snapshot.error.toString(),
                  );
                }
                final rows = snapshot.data ?? const <Map<String, Object?>>[];
                final sales = rows.take(_pageSize).toList();
                if (sales.isEmpty) {
                  return _EmptyState(
                    icon: _search.text.isEmpty
                        ? LucideIcons.receiptText
                        : LucideIcons.searchX,
                    title: _search.text.isEmpty
                        ? 'No sales recorded yet'
                        : 'No receipts match your search',
                    message: _search.text.isEmpty
                        ? 'Completed sales made on this device appear here.'
                        : 'Try a different receipt number or clear the search.',
                  );
                }
                return Column(children: [
                  _pageSummary(sales),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      itemCount: sales.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _saleRow(sales[index]),
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
      );

  void _selectFilter(String filter) => setState(() {
        _filter = filter;
        _page = 0;
      });

  /// Totals for the receipts currently listed, mirroring the amount-due card
  /// on the Sale screen.
  Widget _pageSummary(List<Map<String, Object?>> sales) {
    final total = sales.fold<double>(
        0, (sum, sale) => sum + (sale['net_amount'] as num).toDouble());
    final refunded = sales.fold<double>(
        0,
        (sum, sale) =>
            sum + ((sale['refunded_amount'] as num?)?.toDouble() ?? 0));
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff173f38), Color(0xff0d7457)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SALES ON THIS PAGE',
                style: TextStyle(
                  color: Color(0xffb8ded0),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${sales.length} receipt${sales.length == 1 ? '' : 's'}'
                '${refunded > 0 ? ' • PHP ${refunded.toStringAsFixed(2)} returned' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffd2e9e0),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'PHP ${total.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
      ]),
    );
  }

  Widget _saleRow(Map<String, Object?> sale) {
    final total = (sale['net_amount'] as num).toDouble();
    final refunded = (sale['refunded_amount'] as num?)?.toDouble() ?? 0;
    final fullyRefunded = refunded >= total - .005;
    final accent = refunded <= 0
        ? _accent
        : fullyRefunded
            ? const Color(0xffd05b6f)
            : const Color(0xffd08118);
    final createdAt =
        DateTime.tryParse(sale['occurred_at']! as String)?.toLocal();
    final name = sale['receipt_name'] as String?;
    return Material(
      color: _rowSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _rowBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _receipt(sale),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(LucideIcons.receiptText, size: 21, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale['receipt_number']! as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff203f36),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // The refund badge sits on the meta line so a long receipt
                  // number never has to fight it for room.
                  Row(children: [
                    if (refunded > 0) ...[
                      Flexible(
                        child: _StatusBadge(
                          label: fullyRefunded ? 'Refunded' : 'Partial',
                          color: fullyRefunded ? _danger : _warning,
                          background: fullyRefunded
                              ? const Color(0xfffdeceb)
                              : const Color(0xfffff1d8),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        '${name == null || name.isEmpty ? '' : '$name  •  '}'
                        '${_timestamp(createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _inkSoft, fontSize: 11.5),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Capped so a long receipt total never squeezes the receipt number
            // off a narrow phone row.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PHP ${total.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: _money,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (refunded > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      '-PHP ${refunded.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10.5, color: _danger),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(LucideIcons.chevronRight,
                size: 18, color: Color(0xff8fa49c)),
          ]),
        ),
      ),
    );
  }

  String _timestamp(DateTime? at) {
    if (at == null) return '';
    final time = TimeOfDay.fromDateTime(at).format(context);
    final today = DateTime.now();
    final day = DateTime(at.year, at.month, at.day);
    final difference =
        DateTime(today.year, today.month, today.day).difference(day).inDays;
    if (difference == 0) return 'Today  •  $time';
    if (difference == 1) return 'Yesterday  •  $time';
    return '${at.month}/${at.day}/${at.year}  •  $time';
  }

  Future<void> _returnByReceipt() async {
    final receipt = TextEditingController(text: 'CHP-');
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
                _SheetHeader(
                  icon: LucideIcons.undo2,
                  title: 'Return by receipt',
                  subtitle: 'Look up a sale to refund its items',
                  onClose: () => Navigator.pop(sheet),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: receipt,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                      labelText: 'Receipt number', hintText: 'CHP-...'),
                  onSubmitted: (_) => _verifyReturnReceipt(sheet, receipt.text),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _verifyReturnReceipt(sheet, receipt.text),
                    icon: const Icon(LucideIcons.search, size: 18),
                    label: const Text('Verify receipt'),
                  ),
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
    if (!RegExp(r'^(CHP|TRX)-[A-Z0-9-]+$').hasMatch(number)) {
      ScaffoldMessenger.of(sheet).showSnackBar(const SnackBar(
          content: Text('Enter a valid Chirpy POS receipt number.')));
      return;
    }
    var sale = await widget.database.saleByReceiptNumber(number);
    if (sale == null) {
      final deploymentMode = await widget.database.setting('deployment_mode');
      final server = await widget.database.setting('server_url');
      final token = await widget.database.setting('token');
      if (deploymentMode != 'standalone' &&
          server != null &&
          token != null &&
          token.isNotEmpty) {
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
    final name = sale['receipt_name'] as String?;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => FractionallySizedBox(
        heightFactor: .88,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SheetHeader(
                    icon: LucideIcons.receiptText,
                    title: 'Sale receipt',
                    subtitle:
                        '${sale['receipt_number']}${name == null || name.isEmpty ? '' : '  •  $name'}',
                    onClose: () => Navigator.pop(sheet),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(children: [
                        // A tinted backdrop so the torn paper edges read as
                        // paper rather than as a white block on white.
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xffeef4f1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: RepaintBoundary(
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
                              discountReason:
                                  sale['discount_reason'] as String?,
                              refunded: refunded,
                              profile: profile,
                              tax: tax,
                            ),
                          ),
                        ),
                        if (data['refunds']!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Refund history',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final refund in data['refunds']!) ...[
                            _RefundRow(
                              number: refund['refund_number']! as String,
                              detail:
                                  '${refund['reason']}  •  ${_title(refund['method']! as String)}',
                              amount: (refund['amount'] as num).toDouble(),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff426e61),
                      side: const BorderSide(color: Color(0xffd4e4dd)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
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
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
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
                  16, 8, 16, MediaQuery.viewInsetsOf(sheet).bottom + 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SheetHeader(
                      icon: LucideIcons.undo2,
                      title: 'Return sale items',
                      subtitle: sale['receipt_number']! as String,
                      onClose: () => Navigator.pop(sheet, false),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(children: [
                        const Text(
                          'Select returned products',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final item in items)
                          if ((item['quantity'] as num).toDouble() -
                                  (item['returned_quantity'] as num)
                                      .toDouble() >
                              .0001) ...[
                            _ReturnItemRow(
                              name: item['product_name']! as String,
                              available: (item['quantity'] as num).toDouble() -
                                  (item['returned_quantity'] as num).toDouble(),
                              selected: selected.contains(item['id']),
                              quantity: quantities[item['id']]!,
                              onChanged: (value) => setSheetState(() =>
                                  value == true
                                      ? selected.add(item['id']! as String)
                                      : selected.remove(item['id'])),
                            ),
                            const SizedBox(height: 8),
                          ],
                        const SizedBox(height: 6),
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
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
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

class _SoftIconButton extends StatelessWidget {
  const _SoftIconButton(
      {required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: const Color(0xfff0f5f2),
          borderRadius: BorderRadius.circular(12),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon),
            color: const Color(0xff37695a),
            iconSize: 19,
          ),
        ),
      );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _accent : const Color(0xfff1f6f3),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: selected ? _accent : const Color(0xffe2ece7)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 15,
                  color: selected ? Colors.white : const Color(0xff5c7d70)),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xff41645a),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(
      {required this.label, required this.color, required this.background});
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xfff0f6f3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: const Color(0xff6e867e), size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff274b41),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xff7b8f88), fontSize: 12),
            ),
          ]),
        ),
      );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(
      {required this.icon,
      required this.title,
      required this.onClose,
      this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _accentSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: _accent),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _inkSoft, fontSize: 11.5),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _SoftIconButton(
            icon: LucideIcons.x, tooltip: 'Close', onPressed: onClose),
      ]);
}

class _RefundRow extends StatelessWidget {
  const _RefundRow(
      {required this.number, required this.detail, required this.amount});
  final String number;
  final String detail;
  final double amount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _rowSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _rowBorder),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xffd05b6f).withValues(alpha: .11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(LucideIcons.undo2,
                size: 18, color: Color(0xffb42318)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xff203f36), fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _inkSoft, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('-PHP ${amount.toStringAsFixed(2)}',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, color: _danger)),
        ]),
      );
}

class _ReturnItemRow extends StatelessWidget {
  const _ReturnItemRow(
      {required this.name,
      required this.available,
      required this.selected,
      required this.quantity,
      required this.onChanged});
  final String name;
  final double available;
  final bool selected;
  final TextEditingController quantity;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xfff3faf6) : _rowSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? const Color(0xffbfe3d1) : _rowBorder),
        ),
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: selected,
          onChanged: onChanged,
          activeColor: _accent,
          title: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xff203f36), fontWeight: FontWeight.w800)),
          subtitle: Text('${available.toStringAsFixed(2)} available to return',
              style: const TextStyle(color: _inkSoft, fontSize: 11.5)),
          secondary: selected
              ? SizedBox(
                  width: 92,
                  child: TextField(
                    controller: quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                        labelText: 'Quantity',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                  ),
                )
              : null,
        ),
      );
}
