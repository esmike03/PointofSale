import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chirpy_pos/data/local/local_database.dart';
import 'package:chirpy_pos/finance_screen.dart';
import 'package:chirpy_pos/inventory_screen.dart';
import 'package:chirpy_pos/main.dart' show PosScreen;
import 'package:chirpy_pos/products_screen.dart';
import 'package:chirpy_pos/reports_screen.dart';
import 'package:chirpy_pos/settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

/// Layout smoke tests for the redesigned module screens: they render real data
/// at phone and desktop widths and fail on any overflow.
void main() {
  late Database rawDatabase;
  late LocalDatabase database;

  setUp(() async {
    rawDatabase = await openTestDatabase();
    database = LocalDatabase(rawDatabase);

    final now = DateTime.now();
    for (var i = 0; i < 4; i++) {
      await rawDatabase.insert('products', {
        'id': 'product-$i',
        'sku': 'SKU-000$i',
        'name': 'Lucky Me Pancit Canton Chilimansi $i',
        'selling_price': 18.5 + i,
        'cost_price': 12 + i,
        'unit': 'piece',
        'quantity': i == 0 ? 2.0 : 40.0 + i,
        'reorder_level': 5,
      });
    }
    for (var i = 0; i < 3; i++) {
      final occurredAt =
          now.subtract(Duration(days: i)).toUtc().toIso8601String();
      await rawDatabase.insert('sales', {
        'id': 'sale-$i',
        'receipt_number': 'CHP-2026-000$i',
        'gross_amount': 1250.75,
        'net_amount': 1250.75,
        'occurred_at': occurredAt,
        'status': 'completed',
      });
      await rawDatabase.insert('sale_items', {
        'id': 'item-$i',
        'sale_id': 'sale-$i',
        'product_id': 'product-$i',
        'product_name': 'Lucky Me Pancit Canton Chilimansi $i',
        'quantity': 3,
        'unit_price': 18.5,
        'line_total': 55.5,
      });
      await rawDatabase.insert('payments', {
        'id': 'payment-$i',
        'sale_id': 'sale-$i',
        'method': i.isEven ? 'cash' : 'bank_transfer',
        'amount': 1250.75,
      });
    }
    await rawDatabase.insert('refunds', {
      'id': 'refund-1',
      'sale_id': 'sale-1',
      'refund_number': 'RFN-0001',
      'amount': 200,
      'method': 'cash',
      'reason': 'Damaged item',
      'occurred_at': now.toUtc().toIso8601String(),
    });
  });

  tearDown(() => rawDatabase.close());

  // Screens read from a real sqflite database, so real async work has to run
  // before the resulting frames are pumped.
  // pumpAndSettle can't be used here: a screen that is still loading shows a
  // spinner, which schedules frames forever. Interleave real-time waits with
  // pumps instead so database futures resolve between frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)));
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpAt(WidgetTester tester, Widget screen, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await settle(tester);
  }

  group('reports', () {
    testWidgets('lays out on a phone', (tester) async {
      await pumpAt(
          tester, ReportsScreen(database: database), const Size(360, 740));
      expect(find.text('NET SALES'), findsOneWidget);
      expect(find.text('Sales over time'), findsOneWidget);
      expect(find.text('Product performance'), findsOneWidget);
      expect(find.text('Payment mix'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switches range and lays out on a desktop', (tester) async {
      await pumpAt(
          tester, ReportsScreen(database: database), const Size(1280, 900));
      await tester.tap(find.text('30 days'));
      await settle(tester);
      expect(find.text('Last 30 days'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('products', () {
    testWidgets('lays out on a phone', (tester) async {
      await pumpAt(
          tester, ProductsScreen(database: database), const Size(360, 740));
      expect(find.text('Product catalog'), findsOneWidget);
      expect(find.text('Low stock'), findsOneWidget);
      expect(find.textContaining('Lucky Me Pancit Canton Chilimansi 0'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switches to archived and back', (tester) async {
      await pumpAt(
          tester, ProductsScreen(database: database), const Size(1024, 800));
      await tester.tap(find.text('Archived'));
      await settle(tester);
      expect(find.text('Nothing archived'), findsOneWidget);

      await tester.tap(find.text('Active'));
      await settle(tester);
      expect(find.text('Nothing archived'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the product editor', (tester) async {
      await pumpAt(
          tester, ProductsScreen(database: database), const Size(390, 820));
      await tester.tap(find.text('Lucky Me Pancit Canton Chilimansi 1'));
      await settle(tester);
      expect(find.text('Edit product'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('new sale catalog', () {
    testWidgets('pages through more than fifty products', (tester) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 51; i++) {
          await rawDatabase.insert('products', {
            'id': 'paged-product-$i',
            'sku': 'PAGE-${i.toString().padLeft(3, '0')}',
            'name': 'Paged Product ${i.toString().padLeft(3, '0')}',
            'selling_price': 10 + i,
            'quantity': 20,
          });
        }
      });

      await pumpAt(tester, PosScreen(database: database), const Size(390, 820));
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.byTooltip('Next page'), findsOneWidget);

      await tester.tap(find.byTooltip('Next page'));
      await settle(tester);

      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Paged Product 050'), findsOneWidget);
      expect(find.byTooltip('Previous page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('inventory sheets', () {
    testWidgets('offers the stock actions for a product', (tester) async {
      await pumpAt(
          tester, InventoryScreen(database: database), const Size(360, 900));
      await tester.tap(find.text('Lucky Me Pancit Canton Chilimansi 0'));
      await settle(tester);

      // Product 0 sits under its reorder level, so the sheet flags it.
      expect(find.text('Low stock'), findsWidgets);
      expect(find.text('Receive stock'), findsOneWidget);
      expect(find.text('Adjust stock'), findsOneWidget);
      expect(find.text('Record stock count'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('previews the new on-hand quantity while receiving',
        (tester) async {
      await pumpAt(
          tester, InventoryScreen(database: database), const Size(360, 900));
      await tester.tap(find.text('Lucky Me Pancit Canton Chilimansi 0'));
      await settle(tester);
      await tester.tap(find.text('Receive stock'));
      await settle(tester);

      // Quantity is the only TextFormField on the sheet; the rest are plain
      // TextFields.
      await tester.enterText(find.byType(TextFormField), '5');
      await settle(tester);
      expect(find.text('AFTER THIS ENTRY'), findsOneWidget);
      expect(find.text('7.00 piece'), findsOneWidget);
      expect(find.text('Record receipt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows adjustment reasons as pills', (tester) async {
      await pumpAt(
          tester, InventoryScreen(database: database), const Size(390, 820));
      await tester.tap(find.text('Lucky Me Pancit Canton Chilimansi 0'));
      await settle(tester);
      await tester.tap(find.text('Adjust stock'));
      await settle(tester);

      expect(find.text('REASON'), findsOneWidget);
      expect(find.text('Return to supplier'), findsOneWidget);
      await tester.tap(find.text('Damaged'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('books a variance on a stock count', (tester) async {
      await pumpAt(
          tester, InventoryScreen(database: database), const Size(1024, 800));
      await tester.tap(find.text('Lucky Me Pancit Canton Chilimansi 3'));
      await settle(tester);
      await tester.tap(find.text('Record stock count'));
      await settle(tester);

      // The field starts at the current on-hand figure, so the variance is zero
      // until the counter changes it.
      expect(find.text('VARIANCE'), findsOneWidget);
      expect(find.text('0.00 piece'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '40');
      await settle(tester);
      expect(find.text('-3.00 piece'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('finance', () {
    setUp(() async {
      final now = DateTime.now();
      await rawDatabase.insert('credits', {
        'id': 'credit-1',
        'receipt_number': 'CHP-2026-0001',
        'customer_name': 'Maria Dela Cruz Sari-Sari Store',
        'customer_contact': '0917 123 4567',
        'original_amount': 2500,
        'balance': 1500.75,
        'status': 'unpaid',
        'due_at':
            now.subtract(const Duration(days: 3)).toUtc().toIso8601String(),
        'note': 'Promised to settle after the weekend market.',
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      });
      await rawDatabase.insert('expenses', {
        'id': 'expense-1',
        'category': 'Electricity',
        'description': 'Monthly electric bill for the store',
        'amount': 3450.5,
        'payment_method': 'cash',
        'vendor': 'Meralco',
        'expense_date': now.toUtc().toIso8601String(),
        'note': 'Covers the billing period ending this month.',
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      });
    });

    testWidgets('lays out both tabs on a phone', (tester) async {
      await pumpAt(
          tester, FinanceScreen(database: database), const Size(360, 740));
      expect(find.text('OUTSTANDING CREDIT'), findsOneWidget);
      expect(find.text('Customer credit'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Mark paid'), findsOneWidget);

      await tester.tap(find.text('Expenses').first);
      await settle(tester);
      expect(find.text('Operating expenses'), findsOneWidget);
      expect(find.text('Monthly electric bill for the store'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out on a desktop', (tester) async {
      await pumpAt(
          tester, FinanceScreen(database: database), const Size(1280, 900));
      expect(find.text('Customer credit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('settings', () {
    testWidgets('lays out the signed-out state on a phone', (tester) async {
      await pumpAt(tester, SettingsScreen(database: database, onChanged: () {}),
          const Size(360, 740));
      expect(find.text('Store and invoice identity'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The rest of the page sits below the fold on a phone. Check each lazy
      // ListView section while it is mounted; the split sync panel is tall
      // enough that scrolling to it can recycle the connection panel above.
      await tester.scrollUntilVisible(find.text('Device connection'), 250,
          scrollable: find.byType(Scrollable).first);
      await settle(tester);
      expect(find.text('Device connection'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Offline sync'), 250,
          scrollable: find.byType(Scrollable).first);
      await settle(tester);
      expect(find.text('Business data'), findsOneWidget);
      expect(find.text('Products and items'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Reset server products'), 250,
          scrollable: find.byType(Scrollable).first);
      await settle(tester);
      expect(find.text('Reset products on server'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Reset app data'), 250,
          scrollable: find.byType(Scrollable).first);
      await settle(tester);
      expect(find.text('Reset all local data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the signed-in account and standalone mode',
        (tester) async {
      // Database writes must run outside the fake-async test zone.
      await tester.runAsync(() async {
        await database.saveSetting('deployment_mode', 'standalone');
        await database.saveSetting('user_name', 'Local Cashier');
      });
      await pumpAt(tester, SettingsScreen(database: database, onChanged: () {}),
          const Size(1024, 800));
      expect(find.text('Local account'), findsOneWidget);
      expect(find.text('Signed in locally'), findsOneWidget);
      // Standalone devices hide the server-only panels.
      expect(find.text('Device connection'), findsNothing);
      expect(find.text('Offline sync'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
