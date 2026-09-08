import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'async_dispose.dart';
import 'data/local/local_database.dart';
import 'module_fab.dart';
import 'pagination_controls.dart';
import 'ui_kit.dart';

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
        backgroundColor: kPageTop,
        appBar: ModuleAppBar(
          title: 'Finance',
          subtitle: 'Customer credit and operating costs',
          actions: [
            SoftIconButton(
              icon: LucideIcons.refreshCw,
              tooltip: 'Refresh finance',
              onPressed: _refreshAll,
            ),
          ],
        ),
        body: ModuleBody(
          child: Column(children: [
            FutureBuilder<Map<String, num>>(
              future: _summary,
              builder: (context, snapshot) {
                final data = snapshot.data ?? const <String, num>{};
                final outstanding = data['outstanding_credit'] ?? 0;
                final tiles = <Widget Function(double width)>[
                  (width) => StatTile(
                        width: width,
                        icon: LucideIcons.circleCheck,
                        label: 'Collected credit',
                        value: php(data['collected_credit'] ?? 0),
                      ),
                  (width) => StatTile(
                        width: width,
                        icon: LucideIcons.receipt,
                        label: 'Expenses this month',
                        value: php(data['month_expenses'] ?? 0),
                        tone: const Color(0xffd08118),
                      ),
                  (width) => StatTile(
                        width: width,
                        icon: LucideIcons.chartNoAxesColumnIncreasing,
                        label: 'Total operating costs',
                        value: php(data['total_expenses'] ?? 0),
                        tone: const Color(0xffd08118),
                      ),
                ];
                final compact = MediaQuery.sizeOf(context).width < 600;
                return Column(children: [
                  HighlightCard(
                    label: 'OUTSTANDING CREDIT',
                    value: php(outstanding),
                    caption:
                        '${php(data['collected_credit'] ?? 0)} collected  •  ${php(data['total_credit'] ?? 0)} issued',
                  ),
                  const SizedBox(height: 10),
                  // Phones keep the metrics on one scrollable line so the
                  // credit and expense lists below still get real height.
                  if (compact)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                          children: [
                        for (final tile in tiles) ...[
                          tile(172),
                          const SizedBox(width: 10)
                        ]
                      ]..removeLast()),
                    )
                  else
                    StatTileGrid(tiles: tiles),
                ]);
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterPillBar(children: [
                FilterPill(
                  label: 'Credits / Utang',
                  icon: LucideIcons.handCoins,
                  selected: _selectedTab == 0,
                  onTap: () => _tabController.animateTo(0),
                ),
                FilterPill(
                  label: 'Expenses',
                  icon: LucideIcons.receipt,
                  selected: _selectedTab == 1,
                  onTap: () => _tabController.animateTo(1),
                ),
              ]),
            ),
            const SizedBox(height: 12),
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
        ),
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
  Widget build(BuildContext context) => ModulePanel(
        fill: true,
        icon: LucideIcons.usersRound,
        title: 'Customer credit',
        subtitle: 'Track utang and collect balances',
        child: Expanded(
          child: Column(children: [
            ModuleSearchField(
              controller: _search,
              hint: 'Search customer, contact, or receipt',
              onChanged: (_) => _reload(firstPage: true),
            ),
            const SizedBox(height: 12),
            FilterPillBar(children: [
              for (final option in const [
                ('all', 'All', LucideIcons.handCoins),
                ('unpaid', 'Unpaid', LucideIcons.clock3),
                ('paid', 'Paid', LucideIcons.circleCheck),
              ])
                FilterPill(
                  label: option.$2,
                  icon: option.$3,
                  selected: _status == option.$1,
                  onTap: () {
                    _status = option.$1;
                    _reload(firstPage: true);
                  },
                ),
            ]),
            const SizedBox(height: 13),
            Expanded(
              child: FutureBuilder<_CreditPage>(
                future: _data,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!;
                  if (data.rows.isEmpty) {
                    return ModuleEmpty(
                      icon: LucideIcons.handCoins,
                      title: _search.text.isEmpty
                          ? 'No credit accounts yet'
                          : 'No credit matches your search',
                      message: _search.text.isEmpty
                          ? 'Credit sales and manual balances appear here.'
                          : 'Try another customer, contact or receipt.',
                    );
                  }
                  return Column(children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 2, bottom: 76),
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
                        onNext: (_page + 1) * _pageSize < data.total
                            ? () {
                                _page++;
                                _reload();
                              }
                            : null,
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ]),
        ),
      );

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
                16, 4, 16, MediaQuery.viewInsetsOf(sheetContext).bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SheetHeader(
                icon: LucideIcons.handCoins,
                title: 'Add customer credit',
                subtitle: 'Record a balance not linked to a sale',
                onClose: () => Navigator.pop(sheetContext),
              ),
              const SizedBox(height: 16),
              TextField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: moduleField(
                      hint: 'Customer name',
                      label: 'Customer name',
                      icon: LucideIcons.userRound)),
              const SizedBox(height: 10),
              TextField(
                  controller: contact,
                  keyboardType: TextInputType.phone,
                  decoration: moduleField(
                      hint: 'Mobile number',
                      label: 'Contact (optional)',
                      icon: LucideIcons.phone)),
              const SizedBox(height: 10),
              TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: moduleField(
                      hint: '0.00',
                      label: 'Credit amount',
                      icon: LucideIcons.philippinePeso)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: softButton(),
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
                  decoration: moduleField(
                      hint: 'Anything worth remembering',
                      label: 'Note (optional)',
                      icon: LucideIcons.notebookPen)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: accentButton(),
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
              16, 4, 16, MediaQuery.viewInsetsOf(sheetContext).bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SheetHeader(
              icon: LucideIcons.circleCheck,
              title: 'Mark credit paid',
              subtitle:
                  '${credit['customer_name']} pays ${php(credit['balance'] as num)}',
              onClose: () => Navigator.pop(sheetContext),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: moduleField(
                  hint: 'Payment method',
                  label: 'Payment method',
                  icon: LucideIcons.walletCards),
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
                decoration: moduleField(
                    hint: 'Reference or remark',
                    label: 'Payment note (optional)',
                    icon: LucideIcons.notebookPen)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: accentButton(),
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
  Widget build(BuildContext context) => ModulePanel(
        fill: true,
        icon: LucideIcons.receipt,
        title: 'Operating expenses',
        subtitle: 'Utilities, supplies, services and more',
        child: Expanded(
          child: Column(children: [
            ModuleSearchField(
              controller: _search,
              hint: 'Search description, vendor, or note',
              onChanged: (_) => _reload(firstPage: true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration:
                  moduleField(hint: 'All categories', icon: LucideIcons.tags),
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
            ),
            const SizedBox(height: 13),
            Expanded(
              child: FutureBuilder<_ExpensePage>(
                future: _data,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!;
                  if (data.rows.isEmpty) {
                    return ModuleEmpty(
                      icon: LucideIcons.receipt,
                      title: _search.text.isEmpty && _category == 'all'
                          ? 'No expenses recorded'
                          : 'No expenses match this view',
                      message: _search.text.isEmpty && _category == 'all'
                          ? 'Track utilities, rent and supplies here.'
                          : 'Try another search or category.',
                    );
                  }
                  return Column(children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 2, bottom: 76),
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
                        onNext: (_page + 1) * _pageSize < data.total
                            ? () {
                                _page++;
                                _reload();
                              }
                            : null,
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ]),
        ),
      );

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
                16, 4, 16, MediaQuery.viewInsetsOf(sheetContext).bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SheetHeader(
                icon: LucideIcons.receipt,
                title: 'Add operating expense',
                subtitle: 'Utilities, transport, services and other costs',
                onClose: () => Navigator.pop(sheetContext),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: null,
                isExpanded: true,
                decoration: moduleField(
                    hint: 'Select a category',
                    label: 'Expense category',
                    icon: LucideIcons.tags),
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
                  decoration: moduleField(
                      hint: 'Example: Monthly electric bill',
                      label: 'Description',
                      icon: LucideIcons.fileText)),
              const SizedBox(height: 10),
              TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: moduleField(
                      hint: '0.00',
                      label: 'Amount',
                      icon: LucideIcons.philippinePeso)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: method,
                isExpanded: true,
                decoration: moduleField(
                    hint: 'Payment method',
                    label: 'Payment method',
                    icon: LucideIcons.walletCards),
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
                  decoration: moduleField(
                      hint: 'Who was paid',
                      label: 'Vendor or payee (optional)',
                      icon: LucideIcons.building2)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: softButton(),
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
                  decoration: moduleField(
                      hint: 'Anything worth remembering',
                      label: 'Note (optional)',
                      icon: LucideIcons.notebookPen)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: accentButton(),
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
    final name = credit['customer_name']! as String;
    final meta = [
      if ((credit['customer_contact'] as String?)?.isNotEmpty == true)
        credit['customer_contact'],
      if ((credit['receipt_number'] as String?)?.isNotEmpty == true)
        credit['receipt_number'],
      if (due != null) 'Due ${_date(due)}',
    ].join('  •  ');
    return ModuleRow(
      child: Column(children: [
        Row(children: [
          RowIcon(
            icon: LucideIcons.userRound,
            color: paid
                ? kAccent
                : overdue
                    ? const Color(0xffd05b6f)
                    : const Color(0xffd08118),
          ),
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
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kInkSoft, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 116),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  php(credit['balance']! as num),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: paid ? kMoney : kWarning,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'of ${php(credit['original_amount']! as num)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: kInkSoft, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ]),
        if ((credit['note'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              credit['note']! as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kInkSoft, fontSize: 11.5),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          StatusBadge(
            label: paid
                ? 'Paid'
                : overdue
                    ? 'Overdue'
                    : 'Unpaid',
            color: paid
                ? kAccent
                : overdue
                    ? kDanger
                    : kWarning,
            background: paid
                ? kAccentSoft
                : overdue
                    ? kDangerSoft
                    : kWarningSoft,
          ),
          const Spacer(),
          if (!paid)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: onMarkPaid,
              icon: const Icon(LucideIcons.circleCheck, size: 15),
              label: const Text('Mark paid'),
            ),
        ]),
      ]),
    );
  }
}

class _ExpenseItem extends StatelessWidget {
  const _ExpenseItem({required this.expense});

  final Map<String, Object?> expense;

  @override
  Widget build(BuildContext context) => ModuleRow(
        child: Column(children: [
          Row(children: [
            const RowIcon(icon: LucideIcons.receipt, color: Color(0xffd08118)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense['description']! as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: kInkStrong, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Flexible(
                      child: StatusBadge(
                        label: expense['category']! as String,
                        color: kSoftControlInk,
                        background: const Color(0xffeef4f1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        [
                          _date(_tryDate(expense['expense_date']) ??
                              DateTime.now()),
                          _paymentMethods[expense['payment_method']] ??
                              expense['payment_method'],
                          if ((expense['vendor'] as String?)?.isNotEmpty ==
                              true)
                            expense['vendor'],
                        ].join('  •  '),
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
              constraints: const BoxConstraints(maxWidth: 112),
              child: Text(
                php(expense['amount']! as num),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: kWarning, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
          if ((expense['note'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                expense['note']! as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kInkSoft, fontSize: 11.5),
              ),
            ),
          ],
        ]),
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

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime? _tryDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

void _message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
