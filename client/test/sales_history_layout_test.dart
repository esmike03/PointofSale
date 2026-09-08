import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chirpy_pos/data/local/local_database.dart';
import 'package:chirpy_pos/sales_history_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database rawDatabase;
  late LocalDatabase database;

  setUp(() async {
    sqfliteFfiInit();
    rawDatabase = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await rawDatabase.execute('''CREATE TABLE products (
      id TEXT PRIMARY KEY, sku TEXT, barcode TEXT, name TEXT NOT NULL,
      selling_price REAL NOT NULL DEFAULT 0, cost_price REAL NOT NULL DEFAULT 0,
      unit TEXT NOT NULL DEFAULT 'piece', quantity REAL NOT NULL,
      reorder_level REAL NOT NULL DEFAULT 0, allow_negative_stock INTEGER NOT NULL DEFAULT 0,
      tax_category TEXT NOT NULL DEFAULT 'vatable', archived_at TEXT, updated_at TEXT
    )''');
    await rawDatabase.execute('''CREATE TABLE sales (
      id TEXT PRIMARY KEY, receipt_number TEXT NOT NULL, gross_amount REAL NOT NULL,
      discount_amount REAL NOT NULL DEFAULT 0, discount_reason TEXT, receipt_name TEXT, net_amount REAL NOT NULL,
      tax_mode TEXT NOT NULL DEFAULT 'unregistered', vat_rate REAL NOT NULL DEFAULT 0,
      vatable_sales REAL NOT NULL DEFAULT 0, vat_amount REAL NOT NULL DEFAULT 0,
      vat_exempt_sales REAL NOT NULL DEFAULT 0, zero_rated_sales REAL NOT NULL DEFAULT 0,
      receipt_profile TEXT,
      occurred_at TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'completed'
    )''');
    await rawDatabase.execute('''CREATE TABLE sale_items (
      id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, product_id TEXT NOT NULL,
      product_name TEXT NOT NULL, quantity REAL NOT NULL, unit_price REAL NOT NULL,
      discount_amount REAL NOT NULL DEFAULT 0, line_total REAL NOT NULL,
      tax_category TEXT NOT NULL DEFAULT 'vatable'
    )''');
    await rawDatabase.execute('''CREATE TABLE payments (
      id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, method TEXT NOT NULL,
      amount REAL NOT NULL, reference TEXT
    )''');
    await rawDatabase.execute('''CREATE TABLE refunds (
      id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, refund_number TEXT NOT NULL,
      amount REAL NOT NULL, method TEXT NOT NULL, reason TEXT NOT NULL,
      occurred_at TEXT NOT NULL
    )''');
    await rawDatabase.execute('''CREATE TABLE refund_items (
      id TEXT PRIMARY KEY, refund_id TEXT NOT NULL, sale_item_id TEXT NOT NULL,
      product_id TEXT NOT NULL, product_name TEXT NOT NULL, quantity REAL NOT NULL,
      unit_price REAL NOT NULL, amount REAL NOT NULL
    )''');
    await rawDatabase.execute('''CREATE TABLE app_settings (
      key TEXT PRIMARY KEY, value TEXT NOT NULL
    )''');
    database = LocalDatabase(rawDatabase);

    final now = DateTime.now().toUtc();
    for (var i = 0; i < 6; i++) {
      await rawDatabase.insert('sales', {
        'id': 'sale-$i',
        'receipt_number': 'CHP-2026-000$i',
        'gross_amount': 1250.5 + i,
        'net_amount': 1250.5 + i,
        'receipt_name': i.isEven ? 'Maria Dela Cruz Sari-Sari Store' : null,
        'occurred_at':
            now.subtract(Duration(days: i, hours: i)).toIso8601String(),
        'status': 'completed',
      });
    }
    await rawDatabase.insert('refunds', {
      'id': 'refund-1',
      'sale_id': 'sale-1',
      'refund_number': 'RFN-0001',
      'amount': 200,
      'method': 'cash',
      'reason': 'Damaged item',
      'occurred_at': now.toIso8601String(),
    });
    await rawDatabase.insert('refunds', {
      'id': 'refund-2',
      'sale_id': 'sale-2',
      'refund_number': 'RFN-0002',
      'amount': 1252.5,
      'method': 'gcash',
      'reason': 'Wrong product delivered to the customer',
      'occurred_at': now.toIso8601String(),
    });
  });

  tearDown(() => rawDatabase.close());

  // The screen reads from a real sqflite database, so let real async work run
  // before pumping the resulting frames.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
  }

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: SalesHistoryScreen(database: database),
    ));
    await settle(tester);
  }

  testWidgets('sales history lays out on a phone', (tester) async {
    await pumpAt(tester, const Size(360, 740));
    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('SALES ON THIS PAGE'), findsOneWidget);
    expect(find.text('CHP-2026-0000'), findsOneWidget);
    expect(find.text('Refunded'), findsOneWidget);
    expect(find.text('Partial'), findsOneWidget);

    // The filter row scrolls horizontally, so bring the pill on screen first
    // (the test font is far wider than the app font).
    await tester.ensureVisible(find.text('Returned'));
    await tester.pump();
    await tester.tap(find.text('Returned'));
    await settle(tester);
    expect(find.text('CHP-2026-0000'), findsNothing);

    await tester.ensureVisible(find.text('Completed'));
    await tester.pump();
    await tester.tap(find.text('Completed'));
    await settle(tester);
    expect(find.text('CHP-2026-0000'), findsOneWidget);
    expect(find.text('Refunded'), findsNothing);
  });

  testWidgets('sales history lays out on a tablet', (tester) async {
    await pumpAt(tester, const Size(1280, 900));
    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('Return by receipt'), findsOneWidget);
  });

  testWidgets('receipt sheet opens with refund history', (tester) async {
    await pumpAt(tester, const Size(390, 820));
    await tester.tap(find.text('CHP-2026-0001'));
    await settle(tester);
    expect(find.text('Sale receipt'), findsOneWidget);
    expect(find.text('Refund history'), findsOneWidget);
    expect(find.text('RFN-0001'), findsOneWidget);
    expect(find.text('Return items and issue refund'), findsOneWidget);
  });

  testWidgets('empty search shows the styled empty state', (tester) async {
    await pumpAt(tester, const Size(360, 740));
    await tester.enterText(find.byType(TextField).first, 'CHP-NOPE');
    await settle(tester);
    expect(find.text('No receipts match your search'), findsOneWidget);
  });
}
