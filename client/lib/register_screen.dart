import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_menu.dart';
import 'async_dispose.dart';
import 'data/local/local_database.dart';
import 'module_fab.dart';
import 'pagination_controls.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.database});
  final LocalDatabase database;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _pageSize = 10;
  int _historyPage = 0;

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: AppMenu.leadingOf(context),
          title: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Register'),
                Text('Cashier shift and drawer',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
        ),
        body: FutureBuilder<Map<String, Object?>?>(
          future: widget.database.activeRegisterShift(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final shift = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Row(children: [
                  const Icon(LucideIcons.banknote, size: 19),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('Cash register',
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const Spacer(),
                  Chip(
                      avatar: Icon(
                          shift == null
                              ? LucideIcons.circleMinus
                              : LucideIcons.circleCheck,
                          size: 16,
                          color: shift == null
                              ? const Color(0xffb45309)
                              : const Color(0xff16803d)),
                      label: Text(shift == null ? 'Closed' : 'Shift open')),
                ]),
                const SizedBox(height: 14),
                if (shift == null) _closedRegister() else _openRegister(shift),
                const SizedBox(height: 20),
                Text('Shift history',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _history(),
              ],
            );
          },
        ),
        floatingActionButton: FutureBuilder<Map<String, Object?>?>(
          future: widget.database.activeRegisterShift(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.data != null) {
              return const SizedBox.shrink();
            }
            return ModuleFab(
              onPressed: _showOpenShift,
              icon: LucideIcons.plus,
              label: 'Open register',
              heroTag: 'register-open',
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );

  Widget _closedRegister() => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(LucideIcons.banknote,
                size: 30, color: Color(0xff16803d)),
            const SizedBox(height: 12),
            Text('Start a cashier shift',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(
                'Record the opening drawer amount before accepting cash sales.',
                style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
      );

  Widget _openRegister(Map<String, Object?> shift) =>
      FutureBuilder<Map<String, num>>(
        future: widget.database.registerSummary(shift),
        builder: (context, snapshot) {
          final summary = snapshot.data ?? const <String, num>{};
          return Column(children: [
            LayoutBuilder(builder: (context, constraints) {
              const spacing = 10.0;
              final columns = math.max(2, (constraints.maxWidth / 200).floor());
              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(spacing: spacing, runSpacing: spacing, children: [
                _RegisterMetric(
                    width: cardWidth,
                    label: 'Opening cash',
                    value: _php(summary['opening_cash'] ?? 0),
                    icon: LucideIcons.banknote),
                _RegisterMetric(
                    width: cardWidth,
                    label: 'Cash sales',
                    value: _php(summary['cash_sales'] ?? 0),
                    icon: LucideIcons.shoppingCart),
                _RegisterMetric(
                    width: cardWidth,
                    label: 'Cash refunds',
                    value: _php(summary['cash_refunds'] ?? 0),
                    icon: LucideIcons.undo2,
                    warning: true),
                _RegisterMetric(
                    width: cardWidth,
                    label: 'Cash in',
                    value: _php(summary['cash_in'] ?? 0),
                    icon: LucideIcons.arrowDownToLine),
                _RegisterMetric(
                    width: cardWidth,
                    label: 'Cash out',
                    value: _php(summary['cash_out'] ?? 0),
                    icon: LucideIcons.arrowUpFromLine,
                    warning: true),
                _RegisterMetric(
                    width: cardWidth,
                    label: 'Expected cash',
                    value: _php(summary['expected_cash'] ?? 0),
                    icon: LucideIcons.circleCheck),
              ]);
            }),
            const SizedBox(height: 14),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        OutlinedButton.icon(
                            onPressed: () => _showMovement(
                                shift['id']! as String, 'cash_in'),
                            icon: const Icon(LucideIcons.arrowDownToLine),
                            label: const Text('Cash in')),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                            onPressed: () => _showMovement(
                                shift['id']! as String, 'cash_out'),
                            icon: const Icon(LucideIcons.arrowUpFromLine),
                            label: const Text('Cash out')),
                        const Spacer(),
                        FilledButton.icon(
                            onPressed: () => _showCloseShift(shift, summary),
                            icon: const Icon(LucideIcons.circleCheck),
                            label: const Text('Close shift')),
                      ]),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Map<String, Object?>>>(
                        future: widget.database
                            .cashMovements(shift['id']! as String),
                        builder: (context, movementSnapshot) {
                          final movements = movementSnapshot.data ?? [];
                          if (movements.isEmpty) {
                            return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child:
                                    Text('No cash movements in this shift.'));
                          }
                          return Column(children: [
                            for (final movement in movements)
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                      movement['type'] == 'cash_in'
                                          ? LucideIcons.arrowDownToLine
                                          : LucideIcons.arrowUpFromLine,
                                      color: movement['type'] == 'cash_in'
                                          ? const Color(0xff16803d)
                                          : const Color(0xffb45309)),
                                  title: Text(
                                      movement['type'] == 'cash_in'
                                          ? 'Cash in'
                                          : 'Cash out',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                      (movement['note'] as String?) ??
                                          'No note'),
                                  trailing: Text(
                                      _php(movement['amount'] as num),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)))
                          ]);
                        },
                      ),
                    ]),
              ),
            ),
          ]);
        },
      );

  Widget _history() => FutureBuilder<List<Map<String, Object?>>>(
        future: widget.database.registerShifts(
            limit: _pageSize + 1, offset: _historyPage * _pageSize),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? [];
          final hasNext = rows.length > _pageSize;
          final shifts = rows.take(_pageSize).toList();
          if (shifts.isEmpty) {
            return const Card(
                margin: EdgeInsets.zero,
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No register shifts recorded yet.')));
          }
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (final shift in shifts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        shift['status'] == 'open'
                            ? 'Open shift'
                            : 'Closed shift',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(_date(shift['opened_at']! as String)),
                    trailing: Text(
                        shift['status'] == 'closed'
                            ? 'Variance ${_php((shift['variance'] as num?) ?? 0)}'
                            : _php(shift['opening_cash'] as num),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: ((shift['variance'] as num?) ?? 0) == 0
                                ? const Color(0xff146c34)
                                : const Color(0xffb45309))),
                  ),
                PaginationControls(
                    page: _historyPage,
                    hasNext: hasNext,
                    onPrevious: _historyPage == 0
                        ? null
                        : () => setState(() => _historyPage--),
                    onNext: () => setState(() => _historyPage++)),
              ]),
            ),
          );
        },
      );

  Future<void> _showOpenShift() async {
    final amount = TextEditingController(text: '0.00');
    final note = TextEditingController();
    final saved = await _moneySheet(
        title: 'Open register',
        amountLabel: 'Opening cash',
        amount: amount,
        note: note,
        actionLabel: 'Start shift');
    if (saved) {
      await widget.database.openRegister(
          openingCash: double.parse(amount.text), note: _optional(note.text));
      _refresh();
    }
    disposeAfterClose([amount, note]);
  }

  Future<void> _showMovement(String shiftId, String type) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final saved = await _moneySheet(
        title: type == 'cash_in' ? 'Cash in' : 'Cash out',
        amountLabel: 'Amount',
        amount: amount,
        note: note,
        actionLabel: 'Record ${type == 'cash_in' ? 'cash in' : 'cash out'}');
    if (saved) {
      await widget.database.addCashMovement(
          shiftId: shiftId,
          type: type,
          amount: double.parse(amount.text),
          note: _optional(note.text));
      _refresh();
    }
    disposeAfterClose([amount, note]);
  }

  Future<void> _showCloseShift(
      Map<String, Object?> shift, Map<String, num> summary) async {
    final amount = TextEditingController(
        text: (summary['expected_cash'] ?? 0).toStringAsFixed(2));
    final note = TextEditingController();
    final saved = await _moneySheet(
        title: 'Close shift',
        amountLabel: 'Counted cash',
        amount: amount,
        note: note,
        actionLabel: 'Close register',
        helper: 'Expected ${_php(summary['expected_cash'] ?? 0)}');
    if (!saved) {
      disposeAfterClose([amount, note]);
      return;
    }
    final result = await widget.database.closeRegister(
        shiftId: shift['id']! as String,
        actualCash: double.parse(amount.text),
        note: _optional(note.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Shift closed. Variance ${_php(result['variance'] ?? 0)}.')));
    }
    disposeAfterClose([amount, note]);
    _refresh();
  }

  Future<bool> _moneySheet(
          {required String title,
          required String amountLabel,
          required TextEditingController amount,
          required TextEditingController note,
          required String actionLabel,
          String? helper}) async =>
      await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (sheet) => Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, MediaQuery.viewInsetsOf(sheet).bottom + 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(title,
                        style: Theme.of(sheet)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800))),
                if (helper != null) ...[
                  const SizedBox(height: 4),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(helper,
                          style: Theme.of(sheet).textTheme.bodySmall))
                ],
                const SizedBox(height: 16),
                TextField(
                    controller: amount,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: amountLabel)),
                const SizedBox(height: 10),
                TextField(
                    controller: note,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Note or reason')),
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () {
                          final value = double.tryParse(amount.text);
                          if (value == null || value < 0) {
                            ScaffoldMessenger.of(sheet).showSnackBar(
                                const SnackBar(
                                    content: Text('Enter a valid amount.')));
                            return;
                          }
                          Navigator.pop(sheet, true);
                        },
                        child: Text(actionLabel)))
              ]))) ??
      false;

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();
  String _date(String value) =>
      (DateTime.tryParse(value)?.toLocal().toString() ?? value)
          .substring(0, 16);
  String _php(num value) => 'PHP ${value.toStringAsFixed(2)}';
}

class _RegisterMetric extends StatelessWidget {
  const _RegisterMetric(
      {required this.label,
      required this.value,
      required this.icon,
      this.width,
      this.warning = false});
  final String label;
  final String value;
  final IconData icon;
  final double? width;
  final bool warning;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: width ?? 190,
      height: 112,
      child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
              padding: const EdgeInsets.all(14),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: warning
                            ? const Color(0xfffff4e5)
                            : const Color(0xffe9f5ec),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8))),
                    child: Icon(icon,
                        size: 19,
                        color: warning
                            ? const Color(0xffb45309)
                            : const Color(0xff16803d))),
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800))))
                    ]))
              ]))));
}
