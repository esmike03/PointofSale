import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_menu.dart';
import 'barcode_scanner_screen.dart';
import 'data/local/local_database.dart';
import 'dashboard_screen.dart';
import 'finance_screen.dart';
import 'inventory_screen.dart';
import 'login_screen.dart';
import 'module_fab.dart';
import 'pagination_controls.dart';
import 'products_screen.dart';
import 'register_screen.dart';
import 'receipt_image.dart';
import 'receipt_profile.dart';
import 'sale_tax.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await LocalDatabase.open();
  runApp(PosApp(database: database));
}

class PosApp extends StatelessWidget {
  const PosApp({super.key, required this.database});
  final LocalDatabase database;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Chirpy POS',
        debugShowCheckedModeBanner: false,
        // Scale all text down on narrower (mobile) screens so it isn't too
        // large, while respecting the device's accessibility text size.
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final width = media.size.width;
          final factor = width >= 800
              ? 1.0
              : width >= 600
                  ? 0.95
                  : width >= 400
                      ? 0.9
                      : 0.85;
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(media.textScaler.scale(1) * factor),
            ),
            child: child!,
          );
        },
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Manrope',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff16803d),
            brightness: Brightness.light,
            surface: const Color(0xfffbfdfb),
          ),
          scaffoldBackgroundColor: const Color(0xfff6f8f6),
          appBarTheme: const AppBarTheme(
              toolbarHeight: 72,
              backgroundColor: Color(0xfffbfdfb),
              foregroundColor: Color(0xff173323),
              elevation: 0,
              scrolledUnderElevation: 0,
              titleTextStyle: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff173323))),
          cardTheme: CardThemeData(
              elevation: 0,
              color: const Color(0xffffffff),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: const BorderSide(color: Color(0xffdfe9e1)))),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xffffffff),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xffcedbd1))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xffcedbd1))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      const BorderSide(color: Color(0xff16803d), width: 1.5))),
          dividerTheme:
              const DividerThemeData(color: Color(0xffdfe9e1), thickness: 1),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff16803d),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14))),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xff16803d),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)))),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff146c34),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6))),
                  side: const BorderSide(color: Color(0xff9cc9a7)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12))),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xff146c34),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6))),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10))),
          iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6))))),
          segmentedButtonTheme: SegmentedButtonThemeData(
              style: ButtonStyle(
                  shape: const WidgetStatePropertyAll(RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)))))),
          chipTheme: ChipThemeData(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              side: const BorderSide(color: Color(0xffcce2d0))),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xffffffff),
            surfaceTintColor: Colors.transparent,
            elevation: 4,
            showDragHandle: true,
            dragHandleColor: Color(0xffa7b8aa),
            dragHandleSize: Size(40, 4),
            constraints: BoxConstraints(maxWidth: 640),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
          ),
        ),
        home: _AuthGate(database: database),
      );
}

/// Shows the login gate until a session token is stored, then the app shell.
class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.database});
  final LocalDatabase database;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await widget.database.setting('token');
    if (!mounted) return;
    setState(() => _token = token ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final token = _token;
    if (token == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (token.isEmpty) {
      return LoginScreen(database: widget.database, onSignedIn: _load);
    }
    return HomeShell(database: widget.database, onSignedOut: _load);
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.database, this.onSignedOut});
  final LocalDatabase database;
  final VoidCallback? onSignedOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _destinations = [
    (LucideIcons.shoppingCart, 'Sale'),
    (LucideIcons.receiptText, 'Sales'),
    (LucideIcons.banknote, 'Register'),
    (LucideIcons.trendingUp, 'Dashboard'),
    (LucideIcons.warehouse, 'Inventory'),
    (LucideIcons.package, 'Products'),
    (LucideIcons.walletCards, 'Finance'),
    (LucideIcons.settings, 'Settings'),
  ];

  // Which roles may open each module. An unknown/empty role (e.g. a device
  // signed in before roles existed) sees everything, so nobody is locked out
  // during the transition.
  static const _moduleRoles = <String, Set<String>>{
    'Sale': {
      'super_admin',
      'admin',
      'business_owner',
      'store_manager',
      'cashier'
    },
    'Sales': {
      'super_admin',
      'admin',
      'business_owner',
      'store_manager',
      'cashier',
      'auditor',
      'accountant'
    },
    'Register': {
      'super_admin',
      'admin',
      'business_owner',
      'store_manager',
      'cashier'
    },
    'Dashboard': {
      'super_admin',
      'admin',
      'business_owner',
      'store_manager',
      'auditor',
      'accountant'
    },
    'Inventory': {
      'super_admin',
      'admin',
      'business_owner',
      'store_manager',
      'inventory_staff'
    },
    'Products': {
      'super_admin',
      'admin',
      'business_owner',
      'store_manager',
      'inventory_staff'
    },
    'Finance': {
      'super_admin',
      'admin',
      'business_owner',
      'store_manager',
      'accountant',
      'auditor'
    },
    'Settings': {'super_admin', 'admin', 'business_owner'},
  };

  int selected = 0;
  int sidebarMode = 0;
  String? _role; // null until loaded
  List<int> _visible = List<int>.generate(_destinations.length, (i) => i);

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await widget.database.setting('user_role');
    if (!mounted) return;
    setState(() {
      _role = role ?? '';
      _visible = _visibleFor(_role!);
      if (!_visible.contains(selected)) {
        selected = _visible.isEmpty ? 0 : _visible.first;
      }
    });
  }

  List<int> _visibleFor(String role) {
    if (role.isEmpty) {
      return List<int>.generate(_destinations.length, (i) => i);
    }
    final result = <int>[];
    for (var i = 0; i < _destinations.length; i++) {
      if ((_moduleRoles[_destinations[i].$2] ?? const <String>{})
          .contains(role)) {
        result.add(i);
      }
    }
    return result;
  }

  List<(int, IconData, String)> get _visibleEntries => _visible
      .map((i) => (i, _destinations[i].$1, _destinations[i].$2))
      .toList();

  Future<void> _signOut() async {
    await widget.database.saveSetting('token', '');
    await widget.database.saveSetting('user_name', '');
    await widget.database.saveSetting('user_role', '');
    await widget.database.saveSetting('offline_session', '0');
    widget.onSignedOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final screens = <Widget>[
      PosScreen(
          database: widget.database,
          onRequestRegister: () => setState(() => selected = 2)),
      SalesHistoryScreen(database: widget.database),
      RegisterScreen(database: widget.database),
      DashboardScreen(database: widget.database),
      InventoryScreen(database: widget.database),
      ProductsScreen(database: widget.database),
      FinanceScreen(database: widget.database),
      SettingsScreen(
          database: widget.database,
          onChanged: () => setState(() {}),
          onSignedOut: widget.onSignedOut),
    ];
    if (MediaQuery.sizeOf(context).width >= 800) {
      return Scaffold(
        body: Row(children: [
          if (sidebarMode == 2)
            SizedBox(
              width: 44,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: IconButton(
                        onPressed: () => setState(() => sidebarMode = 0),
                        tooltip: 'Show sidebar',
                        icon: const Icon(LucideIcons.panelLeftOpen)),
                  ),
                ),
              ),
            )
          else ...[
            _DesktopSidebar(
              entries: _visibleEntries,
              selected: selected,
              compact: sidebarMode == 1,
              onSelect: (value) => setState(() => selected = value),
              onCompact: () =>
                  setState(() => sidebarMode = sidebarMode == 0 ? 1 : 0),
              onHide: () => setState(() => sidebarMode = 2),
              onSignOut: _signOut,
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: screens[selected]),
        ]),
      );
    }
    // The hamburger button lives to the left of each screen's AppBar title.
    // AppMenu exposes the opener to those AppBars via AppMenu.leadingOf(context).
    return AppMenu(
      onOpen: _showMobileNavigation,
      child: screens[selected],
    );
  }

  Future<void> _showMobileNavigation() async {
    final destination = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .78,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
              child: Row(children: [
                const Icon(LucideIcons.panelsTopLeft, color: Color(0xff16803d)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Modules',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    tooltip: 'Close navigation',
                    icon: const Icon(LucideIcons.x)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                itemCount: _visibleEntries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 3),
                itemBuilder: (_, i) {
                  final entry = _visibleEntries[i];
                  final isSelected = selected == entry.$1;
                  return ListTile(
                    selected: isSelected,
                    selectedColor: const Color(0xff146c34),
                    selectedTileColor: const Color(0xffe3f3e7),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(6))),
                    leading: Icon(entry.$2, size: 21),
                    title: Text(entry.$3,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: isSelected
                        ? const Icon(LucideIcons.check, size: 19)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, entry.$1),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: ListTile(
                leading:
                    const Icon(LucideIcons.logOut, color: Color(0xffb91c1c)),
                title: const Text('Sign out',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: Color(0xffb91c1c))),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _signOut();
                },
              ),
            ),
          ]),
        ),
      ),
    );
    if (destination != null && mounted) {
      setState(() => selected = destination);
    }
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar(
      {required this.entries,
      required this.selected,
      required this.compact,
      required this.onSelect,
      required this.onCompact,
      required this.onHide,
      required this.onSignOut});
  final List<(int, IconData, String)> entries;
  final int selected;
  final bool compact;
  final ValueChanged<int> onSelect;
  final VoidCallback onCompact;
  final VoidCallback onHide;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: compact ? 64 : 210,
      child: Material(
        color: const Color(0xfff1f7f2),
        child: SafeArea(
          child: Column(children: [
            SizedBox(
              height: 64,
              child: Row(
                  mainAxisAlignment: compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    // Expanded rather than Spacer: the title has to give way to
                    // the control button, not push it off the 210px sidebar.
                    if (!compact)
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: 14),
                          child: Text('Chirpy POS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    if (compact) const Spacer(),
                    _SidebarControl(
                        compact: compact, onCompact: onCompact, onHide: onHide),
                    if (compact) const Spacer() else const SizedBox(width: 6),
                  ]),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Scrolls rather than overflows when the window is too short to
            // show every module at once.
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [
                  for (final entry in entries)
                    _SidebarItem(
                      icon: entry.$2,
                      label: entry.$3,
                      selected: selected == entry.$1,
                      compact: compact,
                      onTap: () => onSelect(entry.$1),
                    ),
                ]),
              ),
            ),
            _SidebarItem(
              icon: LucideIcons.logOut,
              label: 'Sign out',
              selected: false,
              compact: compact,
              onTap: onSignOut,
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

class _SidebarControl extends StatelessWidget {
  const _SidebarControl(
      {required this.compact, required this.onCompact, required this.onHide});
  final bool compact;
  final VoidCallback onCompact;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: compact
            ? 'Click to show labels. Double-click to hide sidebar.'
            : 'Click for icons only. Double-click to hide sidebar.',
        child: GestureDetector(
          onTap: onCompact,
          onDoubleTap: onHide,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
                compact
                    ? LucideIcons.panelLeftOpen
                    : LucideIcons.panelLeftClose,
                size: 20),
          ),
        ),
      );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.compact,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 48,
        margin: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 2),
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
        // The sidebar animates its width, so for a few frames after expanding
        // the labels are laid out against the collapsed 64px. Clip and let the
        // label flex so those frames don't report an overflow.
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: selected ? null : Colors.transparent,
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xff16803d), Color(0xff36a85e)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight)
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
            mainAxisAlignment:
                compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon,
                  color: selected ? Colors.white : colors.onSurfaceVariant),
              if (!compact) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: selected ? Colors.white : colors.onSurface,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500)),
                ),
              ],
            ]),
      ),
    );
    return compact ? Tooltip(message: label, child: content) : content;
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: Color(0xffdfe9e1)));
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton(
      {required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: const Color(0xffedf7f2),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(icon, size: 16, color: const Color(0xff176f52)),
            ),
          ),
        ),
      );
}

/// Small caps label used to separate the sections of the payment sheet.
class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: Color(0xff7d918a),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      );
}

class _MethodPill extends StatelessWidget {
  const _MethodPill(
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
        color: selected ? const Color(0xff0e8a60) : const Color(0xfff4f8f6),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: selected
                      ? const Color(0xff0e8a60)
                      : const Color(0xffe1ebe6)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : const Color(0xff5c7d70)),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xff41645a),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ),
      );
}

/// Quick tender buttons so a cashier does not have to type the cash received.
class _TenderChip extends StatelessWidget {
  const _TenderChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xfff0f6f3),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xff37695a),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
}

class _PaymentPartRow extends StatelessWidget {
  const _PaymentPartRow(
      {required this.method, required this.amount, required this.onRemove});
  final String method;
  final double amount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: const Color(0xfff8fbf9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffe4ece8)),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              method.replaceAll('_', ' ').toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xff315c4f),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
              ),
            ),
          ),
          Text(
            'PHP ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
                color: Color(0xff126d50), fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove payment',
            icon: const Icon(LucideIcons.x, size: 16),
            color: const Color(0xff7b8f88),
          ),
        ]),
      );
}

/// Cash amounts a cashier is likely to be handed for a sale of [due].
List<(String, double)> _tenderSuggestions(double due) {
  if (due <= 0) return const [];
  final options = <(String, double)>[
    ('Exact', double.parse(due.toStringAsFixed(2)))
  ];
  final seen = <double>{double.parse(due.toStringAsFixed(2))};
  void add(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    if (rounded > due + .004 && options.length < 5 && seen.add(rounded)) {
      options.add(('PHP ${rounded.toStringAsFixed(0)}', rounded));
    }
  }

  add((due / 50).ceil() * 50);
  add((due / 100).ceil() * 100);
  for (final note in const [100.0, 200.0, 500.0, 1000.0]) {
    add(note);
  }
  return options;
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 122,
            height: 108,
            child: Image.asset(
              'assets/branding/login_mascot.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              isAntiAlias: false,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready for a new order',
            style: TextStyle(
              color: Color(0xff173f34),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Tap a product or scan its barcode\nto start building the cart.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xff758b84), fontSize: 12),
          ),
        ]),
      );
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key, required this.database, this.onRequestRegister});
  final LocalDatabase database;
  final VoidCallback? onRequestRegister;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  static const _catalogPageSize = 50;

  final queryController = TextEditingController();
  final searchFocus = FocusNode();
  final List<Map<String, Object?>> cart = [];
  String _scanBuffer = '';
  DateTime? _lastScanKeyAt;
  bool _scannerSpeed = true;
  bool? _listCatalogView;
  int _catalogPage = 0;
  double _saleDiscount = 0;
  String? _saleDiscountReason;
  StateSetter? _cartSheetSetState;
  String? _userRole;
  bool _shiftLoaded = false;
  bool _hasOpenShift = false;

  void _rebuildCartSheet() => _cartSheetSetState?.call(() {});

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _loadGate();
  }

  // Cashiers must open a register shift before they can make sales.
  Future<void> _loadGate() async {
    final role = await widget.database.setting('user_role');
    final shift = await widget.database.activeRegisterShift();
    if (!mounted) return;
    setState(() {
      _userRole = role;
      _hasOpenShift = shift != null;
      _shiftLoaded = true;
    });
  }

  Widget _registerGate() => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xffe0ebe6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16164c3d),
                blurRadius: 32,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xfffff3cf),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(LucideIcons.lockKeyhole,
                  size: 28, color: Color(0xffad6b00)),
            ),
            const SizedBox(height: 18),
            Text('Open the register to begin',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xff173f34),
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Start a shift before making sales so cash totals and drawer activity stay accurate.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff6f8580), height: 1.45),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff0e8a60),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => widget.onRequestRegister?.call(),
                icon: const Icon(LucideIcons.banknote, size: 18),
                label: const Text('Open Register'),
              ),
            ),
          ]),
        ),
      );

  @override
  void dispose() {
    queryController.dispose();
    searchFocus.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  // Dispose controllers owned by a modal sheet/dialog only after its exit and
  // keyboard-hide animations finish. Disposing them the instant the sheet
  // closes crashes, because the still-animating TextFields keep rebuilding
  // against a controller that is already disposed.
  void _disposeAfterClose(List<TextEditingController> controllers) {
    Future.delayed(const Duration(milliseconds: 400), () {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final wide = screenWidth >= 900;
    final compact = screenWidth < 430;
    final gated = _shiftLoaded && _userRole == 'cashier' && !_hasOpenShift;
    return Scaffold(
      backgroundColor: const Color(0xfff3f8f5),
      appBar: AppBar(
        backgroundColor: const Color(0xfff3f8f5),
        surfaceTintColor: Colors.transparent,
        leading: AppMenu.leadingOf(context),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New sale'),
            Text(
              'Build an order and check out',
              style: TextStyle(
                color: Color(0xff6c827a),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (!Platform.isAndroid)
            IconButton(
                onPressed: () => searchFocus.requestFocus(),
                tooltip: 'Focus barcode input',
                icon: const Icon(LucideIcons.scanBarcode)),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xffe5f7ee),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xffc5e9d8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.circleCheck,
                        size: 15, color: Color(0xff0e8a60)),
                    const SizedBox(width: 6),
                    Text(
                      compact ? 'Ready' : 'Offline ready',
                      style: const TextStyle(
                        color: Color(0xff176f52),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
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
            colors: [Color(0xfff3f8f5), Color(0xfff8fbf6)],
          ),
        ),
        child: !_shiftLoaded
            ? const Center(child: CircularProgressIndicator())
            : gated
                ? _registerGate()
                : wide
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                        child: Row(children: [
                          Expanded(child: _catalog()),
                          const SizedBox(width: 18),
                          SizedBox(width: 410, child: _cart())
                        ]),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                        child: _catalog(),
                      ),
      ),
      bottomNavigationBar:
          (wide || gated || !_shiftLoaded) ? null : _mobileCartBar(),
      floatingActionButton: (Platform.isAndroid && _shiftLoaded && !gated)
          ? ModuleFab(
              onPressed: _openCameraScanner,
              icon: LucideIcons.qrCode,
              heroTag: 'sale-camera-scanner',
              tooltip: 'Scan barcode with camera',
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Color _productAccent(Map<String, Object?> product) {
    const accents = [
      Color(0xff0e8a60),
      Color(0xff1686a8),
      Color(0xffd08118),
      Color(0xff7a65b5),
      Color(0xffd05b6f),
    ];
    final name = product['name']?.toString() ?? '';
    final score = name.codeUnits.fold<int>(0, (total, code) => total + code);
    return accents[score % accents.length];
  }

  Widget _catalog() {
    final listCatalogView =
        _listCatalogView ?? MediaQuery.sizeOf(context).width < 800;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xffe1ebe7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xffe4f7ef),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.package,
                size: 20, color: Color(0xff0e8a60)),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product catalog',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xff173f34),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Tap an item to add it to the order',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xff74877f), fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: listCatalogView ? 'Card view' : 'List view',
            child: Material(
              color: const Color(0xfff0f5f2),
              borderRadius: BorderRadius.circular(12),
              child: IconButton(
                onPressed: () =>
                    setState(() => _listCatalogView = !listCatalogView),
                icon: Icon(listCatalogView
                    ? LucideIcons.layoutGrid
                    : LucideIcons.list),
                color: const Color(0xff37695a),
                iconSize: 19,
              ),
            ),
          ),
          if (!Platform.isAndroid) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => searchFocus.requestFocus(),
              icon: const Icon(LucideIcons.scanBarcode, size: 18),
              label: const Text('Scan item'),
            ),
          ],
        ]),
        const SizedBox(height: 15),
        TextField(
          controller: queryController,
          focusNode: searchFocus,
          autofocus: MediaQuery.sizeOf(context).width >= 900,
          onChanged: (_) => setState(() => _catalogPage = 0),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xfff4f8f6),
            prefixIcon: const Icon(LucideIcons.search,
                size: 20, color: Color(0xff5f7b72)),
            hintText: 'Search products, SKU, or barcode',
            hintStyle: const TextStyle(color: Color(0xff8ca099)),
            suffixIcon: queryController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      queryController.clear();
                      setState(() => _catalogPage = 0);
                    },
                    icon: const Icon(LucideIcons.x, size: 18),
                  )
                : Platform.isAndroid
                    ? IconButton(
                        tooltip: 'Scan with camera',
                        onPressed: _openCameraScanner,
                        icon: const Icon(LucideIcons.qrCode, size: 19),
                      )
                    : null,
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
        const SizedBox(height: 13),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: widget.database.searchProducts(
              queryController.text,
              limit: _catalogPageSize + 1,
              offset: _catalogPage * _catalogPageSize,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snapshot.data ?? [];
              final products = rows.take(_catalogPageSize).toList();
              final hasNext = rows.length > _catalogPageSize;
              if (products.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xfff0f6f3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(LucideIcons.searchX,
                            color: Color(0xff6e867e), size: 26),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No products found',
                        style: TextStyle(
                          color: Color(0xff274b41),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try another search or add products first.',
                        style:
                            TextStyle(color: Color(0xff7b8f88), fontSize: 12),
                      ),
                    ],
                  ),
                );
              }
              if (listCatalogView) {
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final product = products[index];
                          final accent = _productAccent(product);
                          final quantity =
                              (product['quantity'] as num).toDouble();
                          final lowStock = quantity <=
                              (product['reorder_level'] as num).toDouble();
                          return Material(
                            color: const Color(0xfffbfdfc),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(color: Color(0xffe6eeea)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _addToCart(product),
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
                                    child: Icon(LucideIcons.package,
                                        size: 21, color: accent),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['name']! as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xff203f36),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${product['sku'] ?? 'No SKU'}  •  ${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} ${product['unit']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: lowStock
                                                ? const Color(0xffb26b00)
                                                : const Color(0xff74877f),
                                            fontSize: 11.5,
                                            fontWeight: lowStock
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PHP ${(product['selling_price'] as num).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xff126d50),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff0e8a60),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(LucideIcons.plus,
                                        color: Colors.white, size: 18),
                                  ),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    PaginationControls(
                      page: _catalogPage,
                      hasNext: hasNext,
                      onPrevious: _catalogPage == 0
                          ? null
                          : () => setState(() => _catalogPage--),
                      onNext:
                          hasNext ? () => setState(() => _catalogPage++) : null,
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: 198,
                      ),
                      itemCount: products.length,
                      itemBuilder: (_, index) {
                        final product = products[index];
                        final accent = _productAccent(product);
                        final quantity =
                            (product['quantity'] as num).toDouble();
                        final lowStock = quantity <=
                            (product['reorder_level'] as num).toDouble();
                        return Material(
                          color: const Color(0xfffbfdfc),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: Color(0xffe4ece8)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Tooltip(
                            message: product['name']! as String,
                            waitDuration: const Duration(milliseconds: 400),
                            child: InkWell(
                              onTap: () => _addToCart(product),
                              child: Padding(
                                padding: const EdgeInsets.all(13),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: .11),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        child: Icon(LucideIcons.package,
                                            size: 21, color: accent),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: lowStock
                                              ? const Color(0xfffff1d8)
                                              : const Color(0xffedf6f1),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          lowStock
                                              ? 'Low stock'
                                              : '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} ${product['unit']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: lowStock
                                                ? const Color(0xffa86100)
                                                : const Color(0xff52756a),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: Text(
                                        product['name']! as String,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xff203f36),
                                          fontWeight: FontWeight.w800,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      product['sku']?.toString().isNotEmpty ==
                                              true
                                          ? product['sku']! as String
                                          : 'No SKU',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Color(0xff8a9b95),
                                          fontSize: 10.5),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Expanded(
                                        child: Text(
                                          'PHP ${(product['selling_price'] as num).toStringAsFixed(2)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xff126d50),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xff0e8a60),
                                          borderRadius:
                                              BorderRadius.circular(11),
                                        ),
                                        child: const Icon(LucideIcons.plus,
                                            color: Colors.white, size: 17),
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  PaginationControls(
                    page: _catalogPage,
                    hasNext: hasNext,
                    onPrevious: _catalogPage == 0
                        ? null
                        : () => setState(() => _catalogPage--),
                    onNext:
                        hasNext ? () => setState(() => _catalogPage++) : null,
                  ),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _cart({bool sheet = false}) {
    if (sheet) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Column(children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xffcfddd7),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(child: _cartColumn()),
          ]),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xffdfeae5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14153f33),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: _cartColumn(),
    );
  }

  Widget _cartColumn() {
    final grossTotal = cart.fold<double>(
        0, (sum, item) => sum + (item['line_total'] as num).toDouble());
    final discount = _saleDiscount.clamp(0, grossTotal).toDouble();
    final total = grossTotal - discount;
    final itemCount = cart.fold<double>(
        0, (sum, item) => sum + (item['quantity'] as num).toDouble());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xffe4f7ef),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(LucideIcons.shoppingCart,
              size: 20, color: Color(0xff0e8a60)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order summary',
                style: TextStyle(
                  color: Color(0xff173f34),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                cart.isEmpty
                    ? 'Waiting for the first item'
                    : '${itemCount.toStringAsFixed(itemCount % 1 == 0 ? 0 : 1)} items in this order',
                style:
                    const TextStyle(color: Color(0xff788b84), fontSize: 11.5),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: cart.isEmpty ? null : _holdCurrentSale,
          tooltip: 'Hold current sale',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xfffff4db),
            foregroundColor: const Color(0xff9d6508),
          ),
          icon: const Icon(LucideIcons.pause, size: 17),
        ),
        IconButton(
          onPressed: _showHeldSales,
          tooltip: 'View held sales',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xffedf4f1),
            foregroundColor: const Color(0xff426e61),
          ),
          icon: const Icon(LucideIcons.history, size: 17),
        ),
      ]),
      const SizedBox(height: 12),
      Expanded(
        child: cart.isEmpty
            ? const _EmptyCart()
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: cart.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final item = cart[index];
                  final quantity = item['quantity'] as num;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8fbf9),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: const Color(0xffe4ece8)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['product_name']! as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xff24473c),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'PHP ${(item['unit_price'] as num).toStringAsFixed(2)} each',
                                    style: const TextStyle(
                                      color: Color(0xff81918c),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'PHP ${(item['line_total'] as num).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xff126d50),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _QuantityButton(
                              icon: LucideIcons.minus,
                              tooltip: 'Remove one',
                              onPressed: () => _changeQuantity(index, -1),
                            ),
                            InkWell(
                              onTap: () => _editQuantity(index),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 42),
                                height: 32,
                                alignment: Alignment.center,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xffdce8e3)),
                                ),
                                child: Text(
                                  quantity.toStringAsFixed(
                                      quantity % 1 == 0 ? 0 : 1),
                                  style: const TextStyle(
                                    color: Color(0xff315c4f),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            _QuantityButton(
                              icon: LucideIcons.plus,
                              tooltip: 'Add one',
                              onPressed: () => _changeQuantity(index, 1),
                            ),
                            const Spacer(),
                            const Text(
                              'Tap quantity to edit',
                              style: TextStyle(
                                color: Color(0xff8a9b95),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      const SizedBox(height: 10),
      if (cart.isNotEmpty) ...[
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff426e61),
                side: const BorderSide(color: Color(0xffd4e4dd)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              onPressed: () => _setDiscount(grossTotal),
              icon: const Icon(LucideIcons.tag, size: 16),
              label: Text(discount > 0
                  ? 'Discount: PHP ${discount.toStringAsFixed(2)}'
                  : 'Add order discount'),
            ),
          ),
          if (discount > 0) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: () {
                setState(() {
                  _saleDiscount = 0;
                  _saleDiscountReason = null;
                });
                _rebuildCartSheet();
              },
              tooltip: 'Remove discount',
              icon: const Icon(LucideIcons.x, size: 18),
            ),
          ],
        ]),
        const SizedBox(height: 10),
      ],
      Container(
        padding: const EdgeInsets.all(16),
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
                  'AMOUNT DUE',
                  style: TextStyle(
                    color: Color(0xffb8ded0),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                if (discount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'PHP ${grossTotal.toStringAsFixed(2)} before discount${_saleDiscountReason == null ? '' : ' • $_saleDiscountReason'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xffd2e9e0),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'PHP ${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 54,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xffffc53d),
            foregroundColor: const Color(0xff463100),
            disabledBackgroundColor: const Color(0xffffe8ad),
            disabledForegroundColor: const Color(0xff9a8551),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          ),
          onPressed: cart.isEmpty ? null : () => _checkout(total),
          icon: const Icon(LucideIcons.creditCard, size: 19),
          label: Text(
            cart.isEmpty
                ? 'Add an item to continue'
                : 'Charge PHP ${total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ]);
  }

  Widget _mobileCartBar() {
    final grossTotal = cart.fold<double>(
        0, (sum, item) => sum + (item['line_total'] as num).toDouble());
    final discount = _saleDiscount.clamp(0, grossTotal).toDouble();
    final total = grossTotal - discount;
    final itemCount = cart.fold<double>(
        0, (sum, item) => sum + (item['quantity'] as num).toDouble());
    final empty = cart.isEmpty;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 5, 10, 8),
          decoration: BoxDecoration(
            color: empty ? Colors.white : const Color(0xff173f38),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: empty ? const Color(0xffdce8e2) : const Color(0xff285d52),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2915372f),
                blurRadius: 24,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: empty ? null : _openCartSheet,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 9, 10),
                child: Row(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: empty
                            ? const Color(0xffeef5f1)
                            : const Color(0xff2b5f54),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        LucideIcons.shoppingCart,
                        size: 20,
                        color: empty
                            ? const Color(0xff668078)
                            : const Color(0xffffcf55),
                      ),
                    ),
                    if (!empty)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          constraints: const BoxConstraints(minWidth: 20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xffffc53d),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xff173f38), width: 1.5),
                          ),
                          child: Text(
                            itemCount
                                .toStringAsFixed(itemCount % 1 == 0 ? 0 : 1),
                            style: const TextStyle(
                              color: Color(0xff493400),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          empty
                              ? 'Your cart is ready'
                              : 'PHP ${total.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                empty ? const Color(0xff264b40) : Colors.white,
                            fontSize: empty ? 13 : 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          empty
                              ? 'Tap a product to begin'
                              : 'Review order and take payment',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: empty
                                ? const Color(0xff7c9089)
                                : const Color(0xffb9d8cf),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _showHeldSales,
                    tooltip: 'Held sales',
                    color: empty
                        ? const Color(0xff4e7167)
                        : const Color(0xffd2e8e1),
                    icon: const Icon(LucideIcons.history, size: 19),
                  ),
                  if (!empty)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffffc53d),
                        foregroundColor: const Color(0xff493400),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: _openCartSheet,
                      child: const Text(
                        'Review',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCartSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          _cartSheetSetState = setSheetState;
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: _cart(sheet: true),
            ),
          );
        },
      ),
    );
    _cartSheetSetState = null;
  }

  void _addToCart(Map<String, Object?> product) {
    final index =
        cart.indexWhere((item) => item['product_id'] == product['id']);
    setState(() {
      if (index == -1) {
        cart.add({
          'product_id': product['id'],
          'product_name': product['name'],
          'quantity': 1.0,
          'unit_price': product['selling_price'],
          'tax_category': product['tax_category'] ?? 'vatable',
          'line_total': (product['selling_price'] as num).toDouble()
        });
      } else {
        final item = cart[index];
        final quantity = (item['quantity'] as num).toDouble() + 1;
        item['quantity'] = quantity;
        item['line_total'] = quantity * (item['unit_price'] as num).toDouble();
      }
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final now = DateTime.now();
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final barcode = _scanBuffer;
      final scannedRapidly = _scannerSpeed;
      _scanBuffer = '';
      _lastScanKeyAt = null;
      _scannerSpeed = true;
      if (scannedRapidly && barcode.length >= 3) {
        unawaited(_addScannedProduct(barcode));
      }
      return false;
    }
    final character = event.character;
    if (character == null ||
        character.length != 1 ||
        character.trim().isEmpty) {
      return false;
    }
    final previous = _lastScanKeyAt;
    if (previous == null || now.difference(previous).inMilliseconds > 120) {
      _scanBuffer = character;
      _scannerSpeed = true;
    } else {
      _scanBuffer += character;
    }
    _lastScanKeyAt = now;
    return false;
  }

  Future<void> _addScannedProduct(String barcode) async {
    final product = await widget.database.findByBarcodeOrSku(barcode);
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No product found for barcode $barcode.')));
      return;
    }
    _addToCart(product);
    queryController.clear();
  }

  Future<void> _openCameraScanner() async {
    // The scanner stays open and keeps ringing items up, so a whole basket can
    // be scanned in one pass instead of reopening the camera per item.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
          builder: (_) => BarcodeScannerScreen(onBarcode: _scanIntoCart)),
    );
    if (mounted) queryController.clear();
  }

  /// Adds a camera-scanned barcode to the cart and describes what happened so
  /// the scanner can show it without closing.
  Future<ScanFeedback> _scanIntoCart(String barcode) async {
    final product = await widget.database.findByBarcodeOrSku(barcode);
    if (product == null) {
      return ScanFeedback(
          key: barcode,
          found: false,
          label: barcode,
          detail: 'No product uses this barcode');
    }
    _addToCart(product);
    final id = product['id']! as String;
    final quantity = cart
        .where((item) => item['product_id'] == id)
        .fold<double>(0, (total, item) => total + (item['quantity'] as num));
    final price = (product['selling_price'] as num).toDouble();
    return ScanFeedback(
      // Keyed by product, so a second scan of the same item updates that row.
      key: id,
      found: true,
      label: product['name']! as String,
      detail: 'PHP ${price.toStringAsFixed(2)}  •  '
          '${quantity == quantity.roundToDouble() ? quantity.toInt() : quantity} in cart',
    );
  }

  void _changeQuantity(int index, int change) {
    setState(() {
      final item = cart[index];
      final quantity = (item['quantity'] as num).toDouble() + change;
      if (quantity <= 0) {
        cart.removeAt(index);
      } else {
        item['quantity'] = quantity;
        item['line_total'] = quantity * (item['unit_price'] as num).toDouble();
      }
    });
    _rebuildCartSheet();
  }

  // Tap the quantity in the cart to type an exact amount (supports decimals
  // for weighed items), instead of only the +/- buttons.
  Future<void> _editQuantity(int index) async {
    final item = cart[index];
    final current = item['quantity'] as num;
    final controller = TextEditingController(
        text: current % 1 == 0 ? current.toInt().toString() : '$current');
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Quantity — ${item['product_name']}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Quantity', helperText: 'Set 0 to remove the item'),
          onSubmitted: (_) =>
              Navigator.pop(dialogContext, double.tryParse(controller.text)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  dialogContext, double.tryParse(controller.text)),
              child: const Text('Set')),
        ],
      ),
    );
    _disposeAfterClose([controller]);
    if (result == null) return;
    setState(() {
      if (result <= 0) {
        cart.removeAt(index);
      } else {
        item['quantity'] = result;
        item['line_total'] = result * (item['unit_price'] as num).toDouble();
      }
    });
    _rebuildCartSheet();
  }

  Future<void> _holdCurrentSale() async {
    if (cart.isEmpty) return;
    final label = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(LucideIcons.pause, color: Color(0xff16803d)),
                  const SizedBox(width: 10),
                  Text('Hold current sale',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                Text('Park this cart and continue with another customer.',
                    style: Theme.of(sheetContext).textTheme.bodyMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: label,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                      labelText: 'Order label or customer name',
                      hintText: 'Example: Table 4 or Maria'),
                  onSubmitted: (_) => Navigator.pop(sheetContext, true),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(LucideIcons.pause, size: 18),
                    label: const Text('Hold sale')),
              ]),
        ),
      ),
    );
    final saleLabel = label.text.trim();
    _disposeAfterClose([label]);
    if (confirmed != true || !mounted) return;
    final grossTotal = cart.fold<double>(
        0, (sum, item) => sum + (item['line_total'] as num).toDouble());
    try {
      await widget.database.holdSale(
        label: saleLabel,
        items: List<Map<String, Object?>>.from(cart),
        discountAmount: _saleDiscount.clamp(0, grossTotal).toDouble(),
        discountReason: _saleDiscountReason,
      );
      if (!mounted) return;
      setState(() {
        cart.clear();
        _saleDiscount = 0;
        _saleDiscountReason = null;
      });
      if (_cartSheetSetState != null) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Sale held. The cart is ready for the next customer.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _showHeldSales() async {
    var page = 0;
    const pageSize = 8;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => FractionallySizedBox(
          heightFactor: 0.82,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(LucideIcons.history, color: Color(0xff16803d)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('Held sales',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800))),
                      IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          tooltip: 'Close',
                          icon: const Icon(LucideIcons.x)),
                    ]),
                    Text('Retrieve a parked cart and continue the sale.',
                        style: Theme.of(sheetContext).textTheme.bodyMedium),
                    const SizedBox(height: 14),
                    const _SoftDivider(),
                    Expanded(
                      child: FutureBuilder<List<Map<String, Object?>>>(
                        future: widget.database.heldSales(
                            limit: pageSize + 1, offset: page * pageSize),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                                child: Text(snapshot.error.toString()));
                          }
                          final rows =
                              snapshot.data ?? const <Map<String, Object?>>[];
                          final heldSales = rows.take(pageSize).toList();
                          if (heldSales.isEmpty) {
                            return Center(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  const Icon(LucideIcons.pause,
                                      size: 34, color: Color(0xff7d9181)),
                                  const SizedBox(height: 10),
                                  Text(page == 0
                                      ? 'No held sales yet.'
                                      : 'No sales on this page.'),
                                ]));
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: heldSales.length,
                            separatorBuilder: (_, __) => const _SoftDivider(),
                            itemBuilder: (_, index) {
                              final sale = heldSales[index];
                              final createdAt = DateTime.tryParse(
                                      sale['created_at'] as String? ?? '')
                                  ?.toLocal();
                              final dateLabel = createdAt == null
                                  ? ''
                                  : '${createdAt.month}/${createdAt.day}/${createdAt.year}  ${TimeOfDay.fromDateTime(createdAt).format(sheetContext)}';
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 5),
                                leading: Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                      color: Color(0xffe9f5ec),
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(6))),
                                  child: const Icon(LucideIcons.shoppingCart,
                                      size: 18, color: Color(0xff16803d)),
                                ),
                                title: Text(sale['label']! as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                subtitle: Text(
                                    '${sale['item_count']} products  |  $dateLabel',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                          'PHP ${(sale['total'] as num).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xff146c34))),
                                      const SizedBox(width: 6),
                                      const Icon(LucideIcons.chevronRight,
                                          size: 18),
                                    ]),
                                onTap: () =>
                                    _restoreHeldSale(sale, sheetContext),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    FutureBuilder<List<Map<String, Object?>>>(
                      future: widget.database.heldSales(
                          limit: pageSize + 1, offset: page * pageSize),
                      builder: (_, snapshot) => PaginationControls(
                        page: page,
                        hasNext: (snapshot.data?.length ?? 0) > pageSize,
                        onPrevious: page == 0
                            ? null
                            : () => setSheetState(() => page--),
                        onNext: (snapshot.data?.length ?? 0) > pageSize
                            ? () => setSheetState(() => page++)
                            : null,
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restoreHeldSale(
      Map<String, Object?> sale, BuildContext sheetContext) async {
    if (cart.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Complete or hold the current sale before retrieving another cart.')));
      return;
    }
    try {
      final items = await widget.database.heldSaleItems(sale['id']! as String);
      if (items.isEmpty) {
        throw StateError('This held sale does not contain any products.');
      }
      await widget.database.deleteHeldSale(sale['id']! as String);
      if (!mounted || !sheetContext.mounted) return;
      setState(() {
        cart
          ..clear()
          ..addAll(items.map((item) => <String, Object?>{
                'product_id': item['product_id'],
                'product_name': item['product_name'],
                'quantity': item['quantity'],
                'unit_price': item['unit_price'],
                'line_total': item['line_total'],
              }));
        _saleDiscount = (sale['discount_amount'] as num?)?.toDouble() ?? 0;
        _saleDiscountReason = sale['discount_reason'] as String?;
      });
      _rebuildCartSheet();
      Navigator.pop(sheetContext);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${sale['label']} restored to the cart.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _setDiscount(double grossTotal) async {
    const commonReasons = [
      'Senior citizen',
      'Person with disability (PWD)',
      'Promotional offer',
      'Loyalty reward',
      'Employee discount',
      'Manager-approved adjustment',
      'Price match',
      'Damaged packaging',
    ];
    final controller = TextEditingController(
        text: _saleDiscount == 0 ? '' : _saleDiscount.toStringAsFixed(2));
    final reason = TextEditingController(text: _saleDiscountReason ?? '');
    final saved = await showModalBottomSheet<Map<String, Object?>>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.viewInsetsOf(sheet).bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Transaction discount',
                  style: Theme.of(sheet)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Discount amount',
                      hintText: 'Up to PHP ${grossTotal.toStringAsFixed(2)}')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                  initialValue: null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Common reason',
                      prefixIcon: Icon(LucideIcons.listFilter)),
                  hint: const Text('Select a common reason (optional)'),
                  items: commonReasons
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    reason
                      ..text = value
                      ..selection =
                          TextSelection.collapsed(offset: reason.text.length);
                  }),
              const SizedBox(height: 10),
              TextField(
                  controller: reason,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Discount reason',
                      hintText: 'Type a reason or edit the selected option')),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () {
                        final amount = double.tryParse(controller.text) ?? -1;
                        if (amount < 0 || amount > grossTotal) {
                          ScaffoldMessenger.of(sheet).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Enter a valid discount amount.')));
                          return;
                        }
                        Navigator.pop(sheet, {
                          'amount': amount,
                          'reason': reason.text.trim().isEmpty
                              ? null
                              : reason.text.trim()
                        });
                      },
                      child: const Text('Apply discount')))
            ])));
    _disposeAfterClose([controller, reason]);
    if (saved != null && mounted) {
      setState(() {
        _saleDiscount = saved['amount']! as double;
        _saleDiscountReason = saved['reason'] as String?;
      });
      _rebuildCartSheet();
    }
  }

  Future<void> _checkout(double total) async {
    var method = 'cash';
    final amount = TextEditingController(text: total.toStringAsFixed(2));
    final receiptName = TextEditingController();
    final creditCustomer = TextEditingController();
    final creditContact = TextEditingController();
    final creditNote = TextEditingController();
    DateTime? creditDueAt;
    var splitPayment = false;
    final payments = <Map<String, Object?>>[];
    final complete = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final allocated = payments.fold<double>(
              0, (sum, payment) => sum + (payment['amount'] as num).toDouble());
          final remaining = total - allocated;
          final hasCredit = method == 'credit' ||
              payments.any((payment) => payment['method'] == 'credit');
          final received = double.tryParse(amount.text) ?? 0;
          final cashOnly = method == 'cash' && !splitPayment;
          final change = received - total;
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: FractionallySizedBox(
              heightFactor: .9,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xffe4f7ef),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(LucideIcons.creditCard,
                            size: 20, color: Color(0xff0e8a60)),
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Take payment',
                                style: TextStyle(
                                  color: Color(0xff173f34),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                )),
                            Text('Choose how the customer pays',
                                style: TextStyle(
                                    color: Color(0xff74877f), fontSize: 11.5)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        tooltip: 'Close',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xfff0f5f2),
                          foregroundColor: const Color(0xff37695a),
                        ),
                        icon: const Icon(LucideIcons.x, size: 18),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView(
                          padding: const EdgeInsets.only(bottom: 4),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xff173f38),
                                    Color(0xff0d7457)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Expanded(
                                      child: Text(
                                        'AMOUNT DUE',
                                        style: TextStyle(
                                          color: Color(0xffb8ded0),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'PHP ${total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -.5,
                                      ),
                                    ),
                                  ]),
                                  if (splitPayment ||
                                      (cashOnly && received > 0)) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 11, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0x1fffffff),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(children: [
                                        Expanded(
                                          child: Text(
                                            splitPayment
                                                ? 'Remaining to allocate'
                                                : change >= 0
                                                    ? 'Change due'
                                                    : 'Still short',
                                            style: const TextStyle(
                                              color: Color(0xffd2e9e0),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'PHP ${(splitPayment ? remaining : change.abs()).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: !splitPayment && change < 0
                                                ? const Color(0xffffc9c2)
                                                : const Color(0xffffd97a),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _SheetLabel('PAYMENT METHOD'),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final option in const [
                                ('cash', 'Cash', LucideIcons.banknote),
                                ('card', 'Card', LucideIcons.creditCard),
                                ('gcash', 'GCash', LucideIcons.smartphone),
                                ('maya', 'Maya', LucideIcons.wallet),
                                ('credit', 'Utang', LucideIcons.handCoins),
                              ])
                                _MethodPill(
                                  label: option.$2,
                                  icon: option.$3,
                                  selected: method == option.$1,
                                  onTap: () => setSheetState(() {
                                    method = option.$1;
                                    if (!splitPayment) {
                                      amount.text = total.toStringAsFixed(2);
                                    }
                                  }),
                                ),
                            ]),
                            const SizedBox(height: 16),
                            _SheetLabel(splitPayment
                                ? 'AMOUNT FOR THIS PART'
                                : method == 'credit'
                                    ? 'CREDIT AMOUNT'
                                    : 'AMOUNT RECEIVED'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: amount,
                              enabled: splitPayment || method == 'cash',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (_) => setSheetState(() {}),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff173f34),
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xfff4f8f6),
                                prefixIcon: const Icon(LucideIcons.banknote,
                                    size: 20, color: Color(0xff5f7b72)),
                                prefixText: 'PHP  ',
                                prefixStyle: const TextStyle(
                                  color: Color(0xff5f7b72),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(17),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(17),
                                  borderSide: const BorderSide(
                                      color: Color(0xffe1ebe6)),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(17),
                                  borderSide: const BorderSide(
                                      color: Color(0xffe8eeeb)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(17),
                                  borderSide: const BorderSide(
                                      color: Color(0xff15a675), width: 1.5),
                                ),
                              ),
                            ),
                            if (splitPayment || method == 'cash') ...[
                              const SizedBox(height: 10),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final tender in _tenderSuggestions(
                                    splitPayment ? remaining : total))
                                  _TenderChip(
                                    label: tender.$1,
                                    onTap: () => setSheetState(() => amount
                                        .text = tender.$2.toStringAsFixed(2)),
                                  ),
                              ]),
                            ],
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                              decoration: BoxDecoration(
                                color: const Color(0xfffbfdfc),
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: const Color(0xffe6eeea)),
                              ),
                              child: Row(children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Split payment',
                                          style: TextStyle(
                                            color: Color(0xff203f36),
                                            fontWeight: FontWeight.w800,
                                          )),
                                      SizedBox(height: 2),
                                      Text('Pay with more than one method',
                                          style: TextStyle(
                                              color: Color(0xff81918c),
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: splitPayment,
                                  activeThumbColor: Colors.white,
                                  activeTrackColor: const Color(0xff0e8a60),
                                  onChanged: (value) => setSheetState(() {
                                    splitPayment = value;
                                    payments.clear();
                                    amount.text = total.toStringAsFixed(2);
                                  }),
                                ),
                              ]),
                            ),
                            if (splitPayment) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xff426e61),
                                    side: const BorderSide(
                                        color: Color(0xffd4e4dd)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                  ),
                                  onPressed: () {
                                    final value =
                                        double.tryParse(amount.text) ?? 0;
                                    if (value <= 0 ||
                                        value > remaining + .005) {
                                      ScaffoldMessenger.of(sheetContext)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Enter an amount up to the remaining balance.')));
                                      return;
                                    }
                                    setSheetState(() {
                                      payments.add(
                                          {'method': method, 'amount': value});
                                      amount.text = (remaining - value)
                                          .toStringAsFixed(2);
                                    });
                                  },
                                  icon: const Icon(LucideIcons.circlePlus,
                                      size: 18),
                                  label: const Text('Add payment part'),
                                ),
                              ),
                              for (var index = 0;
                                  index < payments.length;
                                  index++) ...[
                                const SizedBox(height: 8),
                                _PaymentPartRow(
                                  method: payments[index]['method']! as String,
                                  amount: (payments[index]['amount'] as num)
                                      .toDouble(),
                                  onRemove: () => setSheetState(
                                      () => payments.removeAt(index)),
                                ),
                              ],
                            ],
                            if (hasCredit) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xfff7fbf9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xffe1ebe6)),
                                ),
                                child: Column(children: [
                                  Row(children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xfffff4db),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(LucideIcons.handCoins,
                                          size: 17, color: Color(0xff9d6508)),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text('Credit customer',
                                          style: TextStyle(
                                            color: Color(0xff173f34),
                                            fontWeight: FontWeight.w800,
                                          )),
                                    ),
                                  ]),
                                  const SizedBox(height: 12),
                                  TextField(
                                      controller: creditCustomer,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: const InputDecoration(
                                          labelText: 'Customer name',
                                          prefixIcon:
                                              Icon(LucideIcons.userRound))),
                                  const SizedBox(height: 10),
                                  TextField(
                                      controller: creditContact,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                          labelText: 'Contact (optional)',
                                          prefixIcon: Icon(LucideIcons.phone))),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xff426e61),
                                        side: const BorderSide(
                                            color: Color(0xffd4e4dd)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 13),
                                      ),
                                      onPressed: () async {
                                        final selected = await showDatePicker(
                                            context: sheetContext,
                                            firstDate: DateTime.now(),
                                            lastDate: DateTime.now().add(
                                                const Duration(days: 3650)),
                                            initialDate:
                                                creditDueAt ?? DateTime.now());
                                        if (selected != null) {
                                          setSheetState(
                                              () => creditDueAt = selected);
                                        }
                                      },
                                      icon: const Icon(LucideIcons.calendarDays,
                                          size: 18),
                                      label: Text(creditDueAt == null
                                          ? 'Set due date (optional)'
                                          : 'Due ${MaterialLocalizations.of(sheetContext).formatMediumDate(creditDueAt!)}'),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                      controller: creditNote,
                                      decoration: const InputDecoration(
                                          labelText: 'Credit note (optional)',
                                          prefixIcon:
                                              Icon(LucideIcons.notebookPen))),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 16),
                            const _SheetLabel('RECEIPT NAME (OPTIONAL)'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: receiptName,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xfff4f8f6),
                                hintText: 'Customer or company name',
                                hintStyle:
                                    const TextStyle(color: Color(0xff8ca099)),
                                prefixIcon: const Icon(LucideIcons.userRound,
                                    size: 20, color: Color(0xff5f7b72)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(17),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(17),
                                  borderSide: const BorderSide(
                                      color: Color(0xffe1ebe6)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(17),
                                  borderSide: const BorderSide(
                                      color: Color(0xff15a675), width: 1.5),
                                ),
                              ),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffffc53d),
                          foregroundColor: const Color(0xff463100),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17)),
                        ),
                        icon: const Icon(LucideIcons.circleCheck, size: 19),
                        label: Text(
                          'Complete sale • PHP ${total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onPressed: () {
                          final received = method == 'cash'
                              ? double.tryParse(amount.text) ?? 0
                              : total;
                          if ((splitPayment && remaining.abs() > .005) ||
                              (!splitPayment && received < total)) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Payment is less than the sale total.')));
                            return;
                          }
                          final completedPayments = splitPayment
                              ? List<Map<String, Object?>>.from(payments)
                              : <Map<String, Object?>>[
                                  {'method': method, 'amount': total}
                                ];
                          final creditAmount = completedPayments
                              .where((payment) => payment['method'] == 'credit')
                              .fold<double>(
                                  0,
                                  (sum, payment) =>
                                      sum +
                                      (payment['amount'] as num).toDouble());
                          if (creditAmount > 0 &&
                              creditCustomer.text.trim().isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Customer name is required for Credit / Utang.')));
                            return;
                          }
                          Navigator.pop(sheetContext, {
                            'payments': completedPayments,
                            'credit': creditAmount <= 0
                                ? null
                                : <String, Object?>{
                                    'customer_name': creditCustomer.text.trim(),
                                    'customer_contact':
                                        creditContact.text.trim(),
                                    'amount': creditAmount,
                                    'due_at':
                                        creditDueAt?.toUtc().toIso8601String(),
                                    'note': creditNote.text.trim(),
                                  },
                          });
                        },
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
    final savedReceiptName =
        receiptName.text.trim().isEmpty ? null : receiptName.text.trim();
    final completedPayments = complete == null
        ? null
        : (complete['payments']! as List<dynamic>).cast<Map<String, Object?>>();
    final credit = complete?['credit'] as Map<String, Object?>?;
    _disposeAfterClose(
        [amount, receiptName, creditCustomer, creditContact, creditNote]);
    if (complete == null || completedPayments == null) return;
    try {
      final receiptNumber = 'CHP-${DateTime.now().millisecondsSinceEpoch}';
      final receiptItems = List<Map<String, Object?>>.from(cart);
      final discount = _saleDiscount;
      final discountReason = _saleDiscountReason;
      await widget.database.saveSale(
          receiptNumber: receiptNumber,
          items: receiptItems,
          payments: completedPayments,
          receiptName: savedReceiptName,
          discountAmount: discount,
          discountReason: discountReason,
          credit: credit);
      if (mounted) {
        setState(() {
          cart.clear();
          _saleDiscount = 0;
          _saleDiscountReason = null;
        });
        if (_cartSheetSetState != null) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                const Text('Sale saved locally. It will sync when connected.'),
            action: SnackBarAction(
                label: 'View receipt',
                onPressed: () => _showReceipt(
                    receiptNumber: receiptNumber,
                    items: receiptItems,
                    payments: completedPayments,
                    receiptName: savedReceiptName,
                    discount: discount,
                    discountReason: discountReason))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _showReceipt(
      {required String receiptNumber,
      required List<Map<String, Object?>> items,
      required List<Map<String, Object?>> payments,
      String? receiptName,
      required double discount,
      String? discountReason}) async {
    final gross = items.fold<double>(
        0, (sum, item) => sum + (item['line_total'] as num).toDouble());
    final total = gross - discount;
    final savedSale =
        await widget.database.saleByReceiptNumber(receiptNumber) ?? {};
    final profile = savedSale['receipt_profile'] == null
        ? await ReceiptProfile.load(widget.database)
        : ReceiptProfile.fromSale(savedSale);
    final tax = SaleTaxSummary.fromSale(savedSale);
    if (!mounted) return;
    final boundaryKey = GlobalKey();
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
                  Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xffe4f7ef),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(LucideIcons.receiptText,
                          size: 20, color: Color(0xff0e8a60)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sale receipt',
                              style: TextStyle(
                                color: Color(0xff173f34),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              )),
                          Text(receiptNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xff74877f), fontSize: 11.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheet),
                      tooltip: 'Close',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xfff0f5f2),
                        foregroundColor: const Color(0xff37695a),
                      ),
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      // A tinted backdrop so the torn paper edges read as paper.
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xffeef4f1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: RepaintBoundary(
                          key: boundaryKey,
                          child: ReceiptImage(
                            receiptNumber: receiptNumber,
                            receiptName: receiptName,
                            items: items,
                            payments: payments,
                            total: total,
                            discount: discount,
                            discountReason: discountReason,
                            profile: profile,
                            tax: tax,
                          ),
                        ),
                      ),
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
                        final path =
                            await saveReceiptPng(boundaryKey, receiptNumber);
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
                ]),
          ),
        ),
      ),
    );
  }
}
