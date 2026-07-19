import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_menu.dart';
import 'async_dispose.dart';
import 'data/local/local_database.dart';
import 'module_fab.dart';
import 'pagination_controls.dart';

const _expenseCategories = [
  'Electricity',
  'Water',
  'Rent',
  'Transport / Fare',
  'Delivery',
  'Supplies',
  'Repairs',
  'Services',
  'Salaries / Wages',
  'Internet / Phone',
  'Other',
];

const _paymentMethods = {
  'cash': 'Cash',
  'card': 'Card',
  'gcash': 'GCash',
  'maya': 'Maya',
  'bank_transfer': 'Bank transfer',
};

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.database});

  final LocalDatabase database;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, num>> _summary;
  late final TabController _tabController;
  final _creditsKey = GlobalKey<_CreditsTabState>();
  final _expensesKey = GlobalKey<_ExpensesTabState>();
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _summary = widget.database.financeSummary();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (_selectedTab == _tabController.index) return;
    setState(() => _selectedTab = _tabController.index);
  }

  void _reloadSummary() {
    setState(() {
      _summary = widget.database.financeSummary();
    });
  }

  void _refreshAll() {
    _reloadSummary();
    _creditsKey.currentState?._reload();
    _expensesKey.currentState?._reload();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
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
              Text('Finance'),
              Text('Customer credit and operating costs',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          actions: [
            IconButton(
                onPressed: _refreshAll,
                tooltip: 'Refresh finance',
                icon: const Icon(LucideIcons.refreshCw)),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(children: [
          FutureBuilder<Map<String, num>>(
            future: _summary,
            builder: (context, snapshot) {
              final data = snapshot.data ?? const <String, num>{};
              final hPad = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 20.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 12),
                child: Row(children: [
                  _FinanceMetric(
                      icon: LucideIcons.handCoins,
                      label: 'Total credit issued',
                      value: _php(data['total_credit'] ?? 0)),
                  const SizedBox(width: 10),
                  _FinanceMetric(
                      icon: LucideIcons.clock3,
                      label: 'Outstanding credit',
                      value: _php(data['outstanding_credit'] ?? 0),
                      warning: (data['outstanding_credit'] ?? 0) > 0),
                  const SizedBox(width: 10),
                  _FinanceMetric(
                      icon: LucideIcons.circleCheck,
                      label: 'Collected credit',
                      value: _php(data['collected_credit'] ?? 0)),
                  const SizedBox(width: 10),
                  _FinanceMetric(
                      icon: LucideIcons.receipt,
                      label: 'Expenses this month',
                      value: _php(data['month_expenses'] ?? 0),
                      warning: (data['month_expenses'] ?? 0) > 0),
                  const SizedBox(width: 10),
                  _FinanceMetric(
                      icon: LucideIcons.chartNoAxesColumnIncreasing,
                      label: 'Total operating costs',
                      value: _php(data['total_expenses'] ?? 0),
                      warning: (data['total_expenses'] ?? 0) > 0),
                ]),
              );
            },
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(LucideIcons.handCoins), text: 'Credits / Utang'),
              Tab(icon: Icon(LucideIcons.receipt), text: 'Expenses'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CreditsTab(
                    key: _creditsKey,
                    database: widget.database,
                    onChanged: _reloadSummary),
                _ExpensesTab(
                    key: _expensesKey,
                    database: widget.database,
                    onChanged: _reloadSummary),
              ],
            ),
          ),
        ]),
        floatingActionButton: ModuleFab(
          onPressed: _selectedTab == 0
              ? () => _creditsKey.currentState?._addCredit()
              : () => _expensesKey.currentState?._addExpense(),
          icon: LucideIcons.plus,
          label: _selectedTab == 0 ? 'Add credit' : 'Add expense',
          heroTag: 'finance-add',
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
}

class _CreditsTab extends StatefulWidget {
  const _CreditsTab(
      {super.key, required this.database, required this.onChanged});

  final LocalDatabase database;
  final VoidCallback onChanged;

  @override
  State<_CreditsTab> createState() => _CreditsTabState();
}

class _CreditsTabState extends State<_CreditsTab> {
  static const _pageSize = 12;
  final _search = TextEditingController();
  late Future<_CreditPage> _data;
  String _status = 'all';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_CreditPage> _load() async => _CreditPage(
        rows: await widget.database.credits(
            query: _search.text,
            status: _status,
            limit: _pageSize,
            offset: _page * _pageSize),
        total: await widget.database
            .creditCount(query: _search.text, status: _status),
      );

  void _reload({bool firstPage = false}) {
    setState(() {
      if (firstPage) _page = 0;
      _data = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hPad = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 20.0;
    return Padding(
        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(LucideIcons.usersRound, size: 19),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Customer credit',
                    style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 680;
            final search = TextField(
              controller: _search,
              onChanged: (_) => _reload(firstPage: true),
              decoration: const InputDecoration(
                  prefixIcon: Icon(LucideIcons.search),
                  hintText: 'Search customer, contact, or receipt'),
            );
            final filter = SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'unpaid', label: Text('Unpaid')),
                ButtonSegment(value: 'paid', label: Text('Paid')),
              ],
              selected: {_status},
              onSelectionChanged: (value) {
                _status = value.first;
                _reload(firstPage: true);
              },
            );
            return narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        search,
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal, child: filter),
                      ])
                : Row(children: [
                    Expanded(child: search),
                    const SizedBox(width: 12),
                    filter,
                  ]);
          }),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<_CreditPage>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                if (data.rows.isEmpty) {
                  return const Center(
                      child: Text('No credit accounts match this view.'));
                }
                return Column(children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 76),
                      itemCount: data.rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) => _CreditItem(
                        credit: data.rows[index],
                        onMarkPaid: () => _markPaid(data.rows[index]),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PaginationControls(
                      page: _page,
                      hasNext: (_page + 1) * _pageSize < data.total,
                      onPrevious: _page == 0
                          ? null
                          : () {
                              _page--;
                              _reload();
                            },
                      onNext: () {
                        _page++;
                        _reload();
                      },
                    ),
                  ),
                ]);
              },
            ),
          ),
        ]));
  }

  Future<void> _addCredit() async {
    final name = TextEditingController();
    final contact = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    DateTime? dueAt;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _SheetTitle(
                  icon: LucideIcons.handCoins,
                  title: 'Add customer credit',
                  subtitle: 'Record an opening balance not linked to a sale.'),
              const SizedBox(height: 16),
              TextField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Customer name',
                      prefixIcon: Icon(LucideIcons.userRound))),
              const SizedBox(height: 10),
              TextField(
                  controller: contact,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Contact (optional)',
                      prefixIcon: Icon(LucideIcons.phone))),
              const SizedBox(height: 10),
              TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Credit amount',
                      prefixIcon: Icon(LucideIcons.philippinePeso))),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                        context: sheetContext,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                        initialDate: dueAt ?? DateTime.now());
                    if (selected != null) {
                      setSheetState(() => dueAt = selected);
                    }
                  },
                  icon: const Icon(LucideIcons.calendarDays, size: 18),
                  label: Text(dueAt == null
                      ? 'Set due date (optional)'
                      : 'Due ${_date(dueAt!)}'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon: Icon(LucideIcons.notebookPen))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final value = double.tryParse(amount.text) ?? 0;
                    if (name.text.trim().isEmpty || value <= 0) {
                      _message(sheetContext,
                          'Enter a customer name and a positive amount.');
                      return;
                    }
                    await widget.database.createCredit(
                        customerName: name.text,
                        customerContact: contact.text,
                        amount: value,
                        dueAt: dueAt,
                        note: note.text);
                    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                  },
                  icon: const Icon(LucideIcons.save, size: 18),
                  label: const Text('Save credit'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    disposeAfterClose([name, contact, amount, note]);
    if (saved == true && mounted) {
      _reload(firstPage: true);
      widget.onChanged();
    }
  }

  Future<void> _markPaid(Map<String, Object?> credit) async {
    var method = 'cash';
    final note = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _SheetTitle(
                icon: LucideIcons.circleCheck,
                title: 'Mark credit paid',
                subtitle:
                    '${credit['customer_name']} will pay ${_php(credit['balance'] as num)}.'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(
                  labelText: 'Payment method',
                  prefixIcon: Icon(LucideIcons.walletCards)),
              items: _paymentMethods.entries
                  .map((entry) => DropdownMenuItem(
                      value: entry.key, child: Text(entry.value)))
                  .toList(),
              onChanged: (value) {
                if (value != null) method = value;
              },
            ),
            const SizedBox(height: 10),
            TextField(
                controller: note,
                decoration: const InputDecoration(
                    labelText: 'Payment note (optional)',
                    prefixIcon: Icon(LucideIcons.notebookPen))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(LucideIcons.circleCheck, size: 18),
                label: const Text('Mark paid'),
              ),
            ),
          ]),
        ),
      ),
    );
    final paymentNote = note.text;
    disposeAfterClose([note]);
    if (confirmed != true || !mounted) return;
    try {
      await widget.database.markCreditPaid(credit['id']! as String,
          method: method, note: paymentNote);
      if (!mounted) return;
      _reload();
      widget.onChanged();
      _message(context, 'Credit marked as paid.');
    } catch (error) {
      if (mounted) _message(context, error.toString());
    }
  }
}

class _ExpensesTab extends StatefulWidget {
  const _ExpensesTab(
      {super.key, required this.database, required this.onChanged});

  final LocalDatabase database;
  final VoidCallback onChanged;

  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab> {
  static const _pageSize = 12;
  final _search = TextEditingController();
  late Future<_ExpensePage> _data;
  String _category = 'all';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_ExpensePage> _load() async => _ExpensePage(
        rows: await widget.database.expenses(
            query: _search.text,
            category: _category,
            limit: _pageSize,
            offset: _page * _pageSize),
        total: await widget.database
            .expenseCount(query: _search.text, category: _category),
      );

  void _reload({bool firstPage = false}) {
    setState(() {
      if (firstPage) _page = 0;
      _data = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hPad = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 20.0;
    return Padding(
        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(LucideIcons.receipt, size: 19),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Operating expenses',
                    style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 680;
            final search = TextField(
                controller: _search,
                onChanged: (_) => _reload(firstPage: true),
                decoration: const InputDecoration(
                    prefixIcon: Icon(LucideIcons.search),
                    hintText: 'Search description, vendor, or note'));
            final category = DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(
                    value: 'all', child: Text('All categories')),
                ..._expenseCategories.map((value) =>
                    DropdownMenuItem(value: value, child: Text(value))),
              ],
              onChanged: (value) {
                if (value == null) return;
                _category = value;
                _reload(firstPage: true);
              },
            );
            return narrow
                ? Column(children: [
                    search,
                    const SizedBox(height: 10),
                    category,
                  ])
                : Row(children: [
                    Expanded(child: search),
                    const SizedBox(width: 12),
                    SizedBox(width: 230, child: category),
                  ]);
          }),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<_ExpensePage>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                if (data.rows.isEmpty) {
                  return const Center(
                      child: Text('No expenses match this view.'));
                }
                return Column(children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 76),
                      itemCount: data.rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) =>
                          _ExpenseItem(expense: data.rows[index]),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PaginationControls(
                      page: _page,
                      hasNext: (_page + 1) * _pageSize < data.total,
                      onPrevious: _page == 0
                          ? null
                          : () {
                              _page--;
                              _reload();
                            },
                      onNext: () {
                        _page++;
                        _reload();
                      },
                    ),
                  ),
                ]);
              },
            ),
          ),
        ]));
  }

  Future<void> _addExpense() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final vendor = TextEditingController();
    final note = TextEditingController();
    String? category;
    var method = 'cash';
    var expenseDate = DateTime.now();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const _SheetTitle(
                  icon: LucideIcons.receipt,
                  title: 'Add operating expense',
                  subtitle:
                      'Track utilities, transport, services, and other costs.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: null,
                decoration: const InputDecoration(
                    labelText: 'Expense category',
                    prefixIcon: Icon(LucideIcons.tags)),
                hint: const Text('Select a category'),
                items: _expenseCategories
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => category = value,
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: description,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Example: Monthly electric bill',
                      prefixIcon: Icon(LucideIcons.fileText))),
              const SizedBox(height: 10),
              TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(LucideIcons.philippinePeso))),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(
                    labelText: 'Payment method',
                    prefixIcon: Icon(LucideIcons.walletCards)),
                items: _paymentMethods.entries
                    .map((entry) => DropdownMenuItem(
                        value: entry.key, child: Text(entry.value)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) method = value;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: vendor,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Vendor or payee (optional)',
                      prefixIcon: Icon(LucideIcons.building2))),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                        context: sheetContext,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: expenseDate);
                    if (selected != null) {
                      setSheetState(() => expenseDate = selected);
                    }
                  },
                  icon: const Icon(LucideIcons.calendarDays, size: 18),
                  label: Text('Expense date: ${_date(expenseDate)}'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon: Icon(LucideIcons.notebookPen))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final value = double.tryParse(amount.text) ?? 0;
                    if (category == null ||
                        description.text.trim().isEmpty ||
                        value <= 0) {
                      _message(sheetContext,
                          'Select a category and enter a description and positive amount.');
                      return;
                    }
                    await widget.database.createExpense(
                        category: category!,
                        description: description.text,
                        amount: value,
                        paymentMethod: method,
                        expenseDate: expenseDate,
                        vendor: vendor.text,
                        note: note.text);
                    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                  },
                  icon: const Icon(LucideIcons.save, size: 18),
                  label: const Text('Save expense'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    disposeAfterClose([description, amount, vendor, note]);
    if (saved == true && mounted) {
      _reload(firstPage: true);
      widget.onChanged();
    }
  }
}

class _CreditItem extends StatelessWidget {
  const _CreditItem({required this.credit, required this.onMarkPaid});

  final Map<String, Object?> credit;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final paid = credit['status'] == 'paid';
    final due = _tryDate(credit['due_at']);
    final overdue = !paid && due != null && due.isBefore(DateTime.now());
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 620;
          final details =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                  child: Text(credit['customer_name']! as String,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              const SizedBox(width: 8),
              _StatusChip(paid: paid, overdue: overdue),
            ]),
            const SizedBox(height: 5),
            Text(
                [
                  if ((credit['customer_contact'] as String?)?.isNotEmpty ==
                      true)
                    credit['customer_contact'],
                  if ((credit['receipt_number'] as String?)?.isNotEmpty == true)
                    credit['receipt_number'],
                  if (due != null) 'Due ${_date(due)}',
                ].join('  |  '),
                style: Theme.of(context).textTheme.bodySmall),
            if ((credit['note'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(credit['note']! as String,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]);
          final amount = Column(
              crossAxisAlignment:
                  narrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text('Balance', style: Theme.of(context).textTheme.bodySmall),
                _MoneyText(value: credit['balance']! as num, warning: !paid),
                Text('of ${_php(credit['original_amount']! as num)}',
                    style: Theme.of(context).textTheme.bodySmall),
                if (!paid) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                      onPressed: onMarkPaid,
                      icon: const Icon(LucideIcons.circleCheck, size: 17),
                      label: const Text('Mark paid')),
                ],
              ]);
          return narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      details,
                      const Divider(height: 22),
                      amount,
                    ])
              : Row(children: [
                  Expanded(child: details),
                  const SizedBox(width: 16),
                  amount,
                ]);
        }),
      ),
    );
  }
}

class _ExpenseItem extends StatelessWidget {
  const _ExpenseItem({required this.expense});

  final Map<String, Object?> expense;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Color(0xfffff4e5),
                    borderRadius: BorderRadius.all(Radius.circular(6))),
                child: const Icon(LucideIcons.receipt,
                    size: 19, color: Color(0xffb45309))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(expense['description']! as String,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      [
                        expense['category'],
                        _date(_tryDate(expense['expense_date']) ??
                            DateTime.now()),
                        _paymentMethods[expense['payment_method']] ??
                            expense['payment_method'],
                        if ((expense['vendor'] as String?)?.isNotEmpty == true)
                          expense['vendor'],
                      ].join('  |  '),
                      style: Theme.of(context).textTheme.bodySmall),
                  if ((expense['note'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(expense['note']! as String,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ])),
            const SizedBox(width: 12),
            _MoneyText(value: expense['amount']! as num, warning: true),
          ]),
        ),
      );
}

class _FinanceMetric extends StatelessWidget {
  const _FinanceMetric(
      {required this.icon,
      required this.label,
      required this.value,
      this.warning = false});

  final IconData icon;
  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 208,
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
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(value,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800))),
                  ])),
            ]),
          ),
        ),
      );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Color(0xffe9f5ec),
                borderRadius: BorderRadius.all(Radius.circular(6))),
            child: Icon(icon, color: const Color(0xff16803d), size: 20)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ])),
      ]);
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.paid, required this.overdue});

  final bool paid;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final label = paid
        ? 'Paid'
        : overdue
            ? 'Overdue'
            : 'Unpaid';
    final color = paid
        ? const Color(0xff16803d)
        : overdue
            ? const Color(0xffb91c1c)
            : const Color(0xffb45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          border: Border.all(color: color.withValues(alpha: .35)),
          borderRadius: const BorderRadius.all(Radius.circular(6))),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _MoneyText extends StatelessWidget {
  const _MoneyText({required this.value, this.warning = false});

  final num value;
  final bool warning;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(_php(value),
              style: TextStyle(
                  color: warning
                      ? const Color(0xffb45309)
                      : const Color(0xff16803d),
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
        ),
      );
}

class _CreditPage {
  const _CreditPage({required this.rows, required this.total});
  final List<Map<String, Object?>> rows;
  final int total;
}

class _ExpensePage {
  const _ExpensePage({required this.rows, required this.total});
  final List<Map<String, Object?>> rows;
  final int total;
}

String _php(num value) => 'PHP ${value.toStringAsFixed(2)}';

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime? _tryDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

void _message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
