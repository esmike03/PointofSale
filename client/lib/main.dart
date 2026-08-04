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
                    if (!compact) ...[
                      const Padding(
                          padding: EdgeInsets.only(left: 18),
                          child: Text('Chirpy POS',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700))),
                      const Spacer(),
                    ],
                    if (compact) const Spacer(),
                    _SidebarControl(
                        compact: compact, onCompact: onCompact, onHide: onHide),
                    if (compact) const Spacer() else const SizedBox(width: 8),
                  ]),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (final entry in entries)
              _SidebarItem(
                icon: entry.$2,
                label: entry.$3,
                selected: selected == entry.$1,
                compact: compact,
                onTap: () => onSelect(entry.$1),
              ),
            const Spacer(),
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
                Text(label,
                    style: TextStyle(
                        color: selected ? Colors.white : colors.onSurface,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500))
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
        child: SizedBox(
          width: 30,
          height: 30,
          child: IconButton(
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: Icon(icon, size: 16),
          ),
        ),
      );
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Color(0xffeff8f1),
                borderRadius: BorderRadius.all(Radius.circular(6))),
            child:
                const Icon(LucideIcons.shoppingCart, color: Color(0xff16803d)),
          ),
          const SizedBox(height: 12),
          const Text('Your cart is empty',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Select a product or scan a barcode.',
              style: Theme.of(context).textTheme.bodySmall),
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
  final queryController = TextEditingController();
  final searchFocus = FocusNode();
  final List<Map<String, Object?>> cart = [];
  String _scanBuffer = '';
  DateTime? _lastScanKeyAt;
  bool _scannerSpeed = true;
  bool? _listCatalogView;
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.lockKeyhole,
                size: 44, color: Color(0xffb45309)),
            const SizedBox(height: 14),
            Text('Open the cash register first',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
                'Start a register shift before making sales so your cash drawer stays accurate.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => widget.onRequestRegister?.call(),
              icon: const Icon(LucideIcons.banknote, size: 18),
              label: const Text('Go to Register'),
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
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final gated = _shiftLoaded && _userRole == 'cashier' && !_hasOpenShift;
    return Scaffold(
      appBar: AppBar(
        leading: AppMenu.leadingOf(context),
        title: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sale'),
              Text('Counter checkout',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
        actions: [
          if (!Platform.isAndroid)
            IconButton(
                onPressed: () => searchFocus.requestFocus(),
                tooltip: 'Focus barcode input',
                icon: const Icon(LucideIcons.scanBarcode)),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                avatar: Icon(LucideIcons.circleCheck,
                    size: 15, color: Color(0xff16803d)),
                label: Text('Offline ready'),
              ),
            ),
          ),
        ],
      ),
      body: !_shiftLoaded
          ? const Center(child: CircularProgressIndicator())
          : gated
              ? _registerGate()
              : wide
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Row(children: [
                        Expanded(child: _catalog()),
                        const SizedBox(width: 20),
                        SizedBox(width: 390, child: _cart())
                      ]),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: _catalog(),
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

  Widget _catalog() {
    final listCatalogView =
        _listCatalogView ?? MediaQuery.sizeOf(context).width < 800;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(LucideIcons.package, size: 19),
        const SizedBox(width: 8),
        Flexible(
          child: Text('Products',
              style: Theme.of(context).textTheme.titleLarge,
              overflow: TextOverflow.ellipsis),
        ),
        const Spacer(),
        Tooltip(
          message: listCatalogView ? 'Card view' : 'List view',
          child: IconButton(
            // On mobile the toggle is the last element in the row, so pin its
            // icon to the right edge instead of leaving the tap-target's gap
            // (on desktop the 'Scan item' button sits to its right).
            alignment:
                Platform.isAndroid ? Alignment.centerRight : Alignment.center,
            onPressed: () =>
                setState(() => _listCatalogView = !listCatalogView),
            icon: Icon(
                listCatalogView ? LucideIcons.layoutGrid : LucideIcons.list),
          ),
        ),
        if (!Platform.isAndroid)
          TextButton.icon(
              onPressed: () => searchFocus.requestFocus(),
              icon: const Icon(LucideIcons.scanBarcode, size: 18),
              label: const Text('Scan item')),
      ]),
      const SizedBox(height: 14),
      TextField(
        controller: queryController,
        focusNode: searchFocus,
        // Don't pop the keyboard open on mobile; only autofocus on desktop.
        autofocus: MediaQuery.sizeOf(context).width >= 800,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
            prefixIcon: Icon(LucideIcons.search),
            hintText: 'Search by name, SKU, or barcode',
            border: OutlineInputBorder()),
      ),
      const SizedBox(height: 14),
      Expanded(
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: widget.database.searchProducts(queryController.text),
          builder: (context, snapshot) {
            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return const Center(
                  child: Text(
                      'No products match your search. Add products from the Products tab.'));
            }
            if (listCatalogView) {
              return ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, __) => const _SoftDivider(),
                itemBuilder: (_, index) {
                  final product = products[index];
                  final quantity = (product['quantity'] as num).toDouble();
                  final lowStock =
                      quantity <= (product['reorder_level'] as num).toDouble();
                  return InkWell(
                    onTap: () => _addToCart(product),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 4),
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
                                size: 19, color: Color(0xff16803d))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(product['name']! as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                  '${product['sku'] ?? 'No SKU'}  |  ${quantity.toStringAsFixed(2)} ${product['unit']}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: lowStock
                                              ? const Color(0xffb45309)
                                              : null))
                            ])),
                        const SizedBox(width: 12),
                        Text(
                            'PHP ${(product['selling_price'] as num).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xff146c34))),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.circlePlus,
                            color: Color(0xff16803d), size: 20),
                      ]),
                    ),
                  );
                },
              );
            }
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 230,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 158),
              itemCount: products.length,
              itemBuilder: (_, index) {
                final product = products[index];
                final quantity = (product['quantity'] as num).toDouble();
                final lowStock =
                    quantity <= (product['reorder_level'] as num).toDouble();
                return Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Tooltip(
                    message: product['name']! as String,
                    waitDuration: const Duration(milliseconds: 400),
                    child: InkWell(
                      onTap: () => _addToCart(product),
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
                                  decoration: const BoxDecoration(
                                      color: Color(0xffe9f5ec),
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(6))),
                                  child: const Icon(LucideIcons.package,
                                      size: 18, color: Color(0xff16803d)),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => _addToCart(product),
                                  tooltip: 'Add to cart',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                      maxHeight: 34),
                                  icon: const Icon(LucideIcons.circlePlus,
                                      color: Color(0xff16803d)),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Text(product['name']! as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                              Text(
                                  'PHP ${(product['selling_price'] as num).toStringAsFixed(2)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          color: const Color(0xff16803d),
                                          fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                '${product['quantity']} ${product['unit']} available',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: lowStock
                                            ? const Color(0xffb45309)
                                            : null),
                              ),
                            ]),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _cart({bool sheet = false}) {
    if (sheet) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: const BoxDecoration(
                    color: Color(0xffdfe9e1),
                    borderRadius: BorderRadius.all(Radius.circular(3)))),
            Expanded(child: _cartColumn()),
          ]),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(16), child: _cartColumn()),
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
        const Icon(LucideIcons.shoppingCart,
            size: 19, color: Color(0xff16803d)),
        const SizedBox(width: 8),
        Text('Current sale',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const Spacer(),
        IconButton(
          onPressed: cart.isEmpty ? null : _holdCurrentSale,
          tooltip: 'Hold current sale',
          visualDensity: VisualDensity.compact,
          icon: const Icon(LucideIcons.pause, size: 18),
        ),
        IconButton(
          onPressed: _showHeldSales,
          tooltip: 'View held sales',
          visualDensity: VisualDensity.compact,
          icon: const Icon(LucideIcons.history, size: 18),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const BoxDecoration(
              color: Color(0xffe9f5ec),
              borderRadius: BorderRadius.all(Radius.circular(6))),
          child: Text(
              '${itemCount.toStringAsFixed(itemCount % 1 == 0 ? 0 : 1)} items',
              style: const TextStyle(
                  color: Color(0xff146c34),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 14),
      const _SoftDivider(),
      const SizedBox(height: 4),
      Expanded(
        child: cart.isEmpty
            ? const _EmptyCart()
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: cart.length,
                separatorBuilder: (_, __) => const _SoftDivider(),
                itemBuilder: (_, index) {
                  final item = cart[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['product_name']! as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(
                                      'PHP ${(item['unit_price'] as num).toStringAsFixed(2)} each',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ]),
                          ),
                          const SizedBox(width: 8),
                          _QuantityButton(
                              icon: LucideIcons.minus,
                              tooltip: 'Remove one',
                              onPressed: () => _changeQuantity(index, -1)),
                          InkWell(
                              onTap: () => _editQuantity(index),
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                  width: 36,
                                  height: 30,
                                  child: Center(
                                      child: Text(
                                          (item['quantity'] as num)
                                              .toStringAsFixed(
                                                  (item['quantity'] as num) %
                                                              1 ==
                                                          0
                                                      ? 0
                                                      : 1),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationStyle:
                                                  TextDecorationStyle
                                                      .dotted))))),
                          _QuantityButton(
                              icon: LucideIcons.plus,
                              tooltip: 'Add one',
                              onPressed: () => _changeQuantity(index, 1)),
                          const SizedBox(width: 8),
                          SizedBox(
                              width: 74,
                              child: Text(
                                  'PHP ${(item['line_total'] as num).toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))),
                        ]),
                  );
                },
              ),
      ),
      const _SoftDivider(),
      const SizedBox(height: 12),
      if (cart.isNotEmpty)
        Row(children: [
          Expanded(
              child: TextButton.icon(
                  onPressed: () => _setDiscount(grossTotal),
                  icon: const Icon(LucideIcons.tag, size: 17),
                  label: Text(discount > 0
                      ? 'Discount PHP ${discount.toStringAsFixed(2)}'
                      : 'Add discount'))),
          if (discount > 0)
            IconButton(
                onPressed: () {
                  setState(() {
                    _saleDiscount = 0;
                    _saleDiscountReason = null;
                  });
                  _rebuildCartSheet();
                },
                tooltip: 'Remove discount',
                icon: const Icon(LucideIcons.x, size: 18))
        ]),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
            color: Color(0xffeff8f1),
            borderRadius: BorderRadius.all(Radius.circular(6))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (discount > 0)
              Text(
                  'PHP ${grossTotal.toStringAsFixed(2)} before discount${_saleDiscountReason == null ? '' : '  |  $_saleDiscountReason'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall)
          ]),
          const Spacer(),
          Text('PHP ${total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xff146c34), fontWeight: FontWeight.w800)),
        ]),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: cart.isEmpty ? null : () => _checkout(total),
          icon: const Icon(LucideIcons.creditCard, size: 19),
          label: const Text('Proceed to payment'),
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
      color: Theme.of(context).colorScheme.surface,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: empty ? null : _openCartSheet,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: empty
                          ? const Color(0xffeef2ef)
                          : const Color(0xffe9f5ec),
                      borderRadius: const BorderRadius.all(Radius.circular(8))),
                  child: Icon(LucideIcons.shoppingCart,
                      size: 20,
                      color: empty
                          ? const Color(0xff7d9181)
                          : const Color(0xff16803d)),
                ),
                if (!empty)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 20),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: Color(0xff16803d),
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                      child: Text(
                          itemCount.toStringAsFixed(itemCount % 1 == 0 ? 0 : 1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: empty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            const Text('Cart is empty',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            Text('Tap a product to start a sale',
                                style: Theme.of(context).textTheme.bodySmall),
                          ])
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text('PHP ${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: Color(0xff146c34))),
                            Text('Tap to review and pay',
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showHeldSales,
                tooltip: 'Held sales',
                icon: const Icon(LucideIcons.history),
              ),
              if (!empty)
                FilledButton.icon(
                  onPressed: _openCartSheet,
                  icon: const Icon(LucideIcons.creditCard, size: 18),
                  label: const Text('View cart'),
                ),
            ]),
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
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null) return;
    await _addScannedProduct(barcode);
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
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 12, 16,
                  MediaQuery.viewInsetsOf(sheetContext).bottom + 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Take payment',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: receiptName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Receipt name (optional)',
                    hintText: 'Customer or company name',
                    prefixIcon: Icon(LucideIcons.userRound),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'cash', label: Text('Cash')),
                      ButtonSegment(value: 'card', label: Text('Card')),
                      ButtonSegment(value: 'gcash', label: Text('GCash')),
                      ButtonSegment(value: 'maya', label: Text('Maya')),
                      ButtonSegment(value: 'credit', label: Text('Utang')),
                    ],
                    selected: {method},
                    onSelectionChanged: (value) => setSheetState(() {
                      method = value.first;
                      if (!splitPayment) amount.text = total.toStringAsFixed(2);
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Split payment'),
                    value: splitPayment,
                    onChanged: (value) => setSheetState(() {
                          splitPayment = value;
                          payments.clear();
                          amount.text = total.toStringAsFixed(2);
                        })),
                TextField(
                    controller: amount,
                    enabled: splitPayment || method == 'cash',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: splitPayment
                            ? 'Amount for this payment'
                            : method == 'credit'
                                ? 'Credit amount'
                                : 'Amount received',
                        border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                if (hasCredit) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xfff1f7f2),
                        border: Border.all(color: const Color(0xffcce2d0)),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(6))),
                    child: Column(children: [
                      Row(children: [
                        const Icon(LucideIcons.handCoins,
                            size: 18, color: Color(0xff16803d)),
                        const SizedBox(width: 8),
                        Text('Credit customer',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 10),
                      TextField(
                          controller: creditCustomer,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                              labelText: 'Customer name',
                              prefixIcon: Icon(LucideIcons.userRound))),
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
                          onPressed: () async {
                            final selected = await showDatePicker(
                                context: sheetContext,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 3650)),
                                initialDate: creditDueAt ?? DateTime.now());
                            if (selected != null) {
                              setSheetState(() => creditDueAt = selected);
                            }
                          },
                          icon: const Icon(LucideIcons.calendarDays, size: 18),
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
                              prefixIcon: Icon(LucideIcons.notebookPen))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                if (splitPayment) ...[
                  SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                          onPressed: () {
                            final value = double.tryParse(amount.text) ?? 0;
                            if (value <= 0 || value > remaining + .005) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Enter an amount up to the remaining balance.')));
                              return;
                            }
                            setSheetState(() {
                              payments.add({'method': method, 'amount': value});
                              amount.text =
                                  (remaining - value).toStringAsFixed(2);
                            });
                          },
                          icon: const Icon(LucideIcons.circlePlus, size: 18),
                          label: const Text('Add payment part'))),
                  const SizedBox(height: 8),
                  for (var index = 0; index < payments.length; index++)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text((payments[index]['method']! as String)
                            .toUpperCase()),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                              'PHP ${(payments[index]['amount'] as num).toStringAsFixed(2)}'),
                          IconButton(
                              onPressed: () =>
                                  setSheetState(() => payments.removeAt(index)),
                              tooltip: 'Remove payment',
                              icon: const Icon(LucideIcons.x, size: 18))
                        ])),
                ],
                Text(
                    splitPayment
                        ? 'Remaining: PHP ${remaining.toStringAsFixed(2)}'
                        : 'Total: PHP ${total.toStringAsFixed(2)}',
                    style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 16),
                FilledButton(
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
                                sum + (payment['amount'] as num).toDouble());
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
                              'customer_contact': creditContact.text.trim(),
                              'amount': creditAmount,
                              'due_at': creditDueAt?.toUtc().toIso8601String(),
                              'note': creditNote.text.trim(),
                            },
                    });
                  },
                  child: const Text('Complete sale'),
                ),
              ]),
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('Sale receipt',
                            style: Theme.of(sheet)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800))),
                    IconButton(
                        onPressed: () => Navigator.pop(sheet),
                        tooltip: 'Close',
                        icon: const Icon(LucideIcons.x)),
                  ]),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
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
