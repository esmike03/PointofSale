import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/data/local/local_database.dart';
import 'package:pos_client/receipt_image.dart';
import 'package:pos_client/receipt_profile.dart';
import 'package:pos_client/sale_tax.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database rawDatabase;
  late LocalDatabase database;

  setUp(() async {
    sqfliteFfiInit();
    rawDatabase = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await rawDatabase.execute('''CREATE TABLE held_sales (
      id TEXT PRIMARY KEY, label TEXT NOT NULL, discount_amount REAL NOT NULL DEFAULT 0,
      discount_reason TEXT, created_at TEXT NOT NULL
    )''');
    await rawDatabase.execute('''CREATE TABLE held_sale_items (
      id TEXT PRIMARY KEY, held_sale_id TEXT NOT NULL, product_id TEXT NOT NULL,
      product_name TEXT NOT NULL, quantity REAL NOT NULL, unit_price REAL NOT NULL,
      line_total REAL NOT NULL, tax_category TEXT NOT NULL DEFAULT 'vatable'
    )''');
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
    await rawDatabase.execute('''CREATE TABLE inventory_movements (
      id TEXT PRIMARY KEY, product_id TEXT NOT NULL, quantity_delta REAL NOT NULL,
      reason TEXT NOT NULL, note TEXT, occurred_at TEXT NOT NULL
    )''');
    await rawDatabase.execute('''CREATE TABLE sync_queue (
      operation_id TEXT PRIMARY KEY, type TEXT NOT NULL, payload TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT, created_at TEXT NOT NULL, synced_at TEXT
    )''');
    await rawDatabase.execute('''CREATE TABLE app_settings (
      key TEXT PRIMARY KEY, value TEXT NOT NULL
    )''');
    await rawDatabase.execute('''CREATE TABLE register_shifts (
      id TEXT PRIMARY KEY, opening_cash REAL NOT NULL, status TEXT NOT NULL,
      opened_at TEXT NOT NULL, closed_at TEXT, expected_cash REAL,
      actual_cash REAL, variance REAL, note TEXT
    )''');
    await rawDatabase.execute('''CREATE TABLE cash_movements (
      id TEXT PRIMARY KEY, shift_id TEXT NOT NULL, type TEXT NOT NULL,
      amount REAL NOT NULL, note TEXT, occurred_at TEXT NOT NULL
    )''');
    await rawDatabase.execute('''CREATE TABLE credits (
      id TEXT PRIMARY KEY, sale_id TEXT, receipt_number TEXT,
      customer_name TEXT NOT NULL, customer_contact TEXT,
      original_amount REAL NOT NULL, balance REAL NOT NULL,
      status TEXT NOT NULL DEFAULT 'unpaid', due_at TEXT, note TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL, paid_at TEXT
    )''');
    await rawDatabase.execute('''CREATE TABLE credit_payments (
      id TEXT PRIMARY KEY, credit_id TEXT NOT NULL, amount REAL NOT NULL,
      method TEXT NOT NULL, note TEXT, paid_at TEXT NOT NULL
    )''');
    await rawDatabase.execute('''CREATE TABLE expenses (
      id TEXT PRIMARY KEY, category TEXT NOT NULL, description TEXT NOT NULL,
      amount REAL NOT NULL, payment_method TEXT NOT NULL, vendor TEXT,
      expense_date TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    database = LocalDatabase(rawDatabase);
  });

  tearDown(() => rawDatabase.close());

  test('held sale preserves cart and discount until it is retrieved', () async {
    await database.holdSale(
      label: 'Table 4',
      discountAmount: 15,
      discountReason: 'Senior discount',
      items: [
        {
          'product_id': 'product-1',
          'product_name': 'Coffee',
          'quantity': 2.0,
          'unit_price': 75.0,
          'line_total': 150.0,
        },
      ],
    );

    final heldSales = await database.heldSales();
    expect(heldSales, hasLength(1));
    expect(heldSales.single['label'], 'Table 4');
    expect(heldSales.single['discount_amount'], 15.0);
    expect(heldSales.single['discount_reason'], 'Senior discount');
    expect(heldSales.single['total'], 135.0);

    final heldSaleId = heldSales.single['id']! as String;
    final items = await database.heldSaleItems(heldSaleId);
    expect(items.single['product_name'], 'Coffee');
    expect(items.single['quantity'], 2.0);

    await database.deleteHeldSale(heldSaleId);
    expect(await database.heldSales(), isEmpty);
    expect(await database.heldSaleItems(heldSaleId), isEmpty);
  });

  test('partial refund restores stock and cannot exceed sold quantity',
      () async {
    final now = DateTime.now().toUtc().toIso8601String();
    await rawDatabase.insert('products', {
      'id': 'product-1',
      'name': 'Coffee',
      'quantity': 8.0,
      'cost_price': 50.0
    });
    await rawDatabase.insert('products', {
      'id': 'product-2',
      'name': 'Tea',
      'quantity': 4.0,
      'cost_price': 40.0
    });
    await rawDatabase.insert('sales', {
      'id': 'sale-1',
      'receipt_number': 'TRX-001',
      'gross_amount': 300.0,
      'discount_amount': 30.0,
      'net_amount': 270.0,
      'occurred_at': now,
      'status': 'completed',
    });
    await rawDatabase.insert('sale_items', {
      'id': 'item-1',
      'sale_id': 'sale-1',
      'product_id': 'product-1',
      'product_name': 'Coffee',
      'quantity': 2.0,
      'unit_price': 100.0,
      'discount_amount': 0.0,
      'line_total': 200.0,
    });
    await rawDatabase.insert('sale_items', {
      'id': 'item-2',
      'sale_id': 'sale-1',
      'product_id': 'product-2',
      'product_name': 'Tea',
      'quantity': 1.0,
      'unit_price': 100.0,
      'discount_amount': 0.0,
      'line_total': 100.0,
    });

    await database.refundSale(
      saleId: 'sale-1',
      items: [
        {'sale_item_id': 'item-1', 'quantity': 1.0},
        {'sale_item_id': 'item-2', 'quantity': 1.0},
      ],
      method: 'cash',
      reason: 'Damaged item',
    );

    final receipt = await database.saleReceipt('sale-1');
    expect(
        receipt['items']!
            .firstWhere((item) => item['id'] == 'item-1')['returned_quantity'],
        1.0);
    expect(receipt['refunds']!.single['amount'], 180.0);
    final products = await rawDatabase.query('products', orderBy: 'id');
    expect(products[0]['quantity'], 9.0);
    expect(products[1]['quantity'], 5.0);
    expect((await database.salesSummaryToday())['refunds'], 180.0);
    expect(await database.recentSales(filter: 'returned'), hasLength(1));
    expect(await database.recentSales(filter: 'completed'), isEmpty);
    final movements = await rawDatabase.query('inventory_movements');
    expect(movements, hasLength(2));
    expect(
        movements.every((movement) => movement['reason'] == 'return'), isTrue);
    expect(
        (await rawDatabase.query('sync_queue')).single['type'], 'sale.refund');

    expect(
      () => database.refundSale(
        saleId: 'sale-1',
        items: [
          {'sale_item_id': 'item-1', 'quantity': 2.0}
        ],
        method: 'cash',
        reason: 'Too many',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('product archive hides active search and can be restored', () async {
    await rawDatabase.insert('products', {
      'id': 'product-archive',
      'sku': 'SEASONAL-1',
      'name': 'Seasonal Item',
      'quantity': 3.0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await database.setProductArchived('product-archive', true);
    expect(await database.searchProducts('Seasonal'), isEmpty);
    expect(await database.searchProducts('Seasonal', archived: true),
        hasLength(1));
    expect(await database.findByBarcodeOrSku('SEASONAL-1'), isNull);
    expect((await rawDatabase.query('sync_queue')).single['type'],
        'product.archive');

    await database.setProductArchived('product-archive', false);
    expect(await database.searchProducts('Seasonal'), hasLength(1));
    expect(await database.searchProducts('Seasonal', archived: true), isEmpty);
  });

  test('product referenced by a completed sale cannot be deleted', () async {
    final now = DateTime.now().toUtc().toIso8601String();
    await rawDatabase.insert('products', {
      'id': 'protected-product',
      'name': 'Historical Product',
      'quantity': 0.0,
      'archived_at': now,
      'updated_at': now,
    });
    await rawDatabase.insert('sales', {
      'id': 'protected-sale',
      'receipt_number': 'TRX-PROTECTED',
      'gross_amount': 50.0,
      'net_amount': 50.0,
      'occurred_at': now,
      'status': 'completed',
    });
    await rawDatabase.insert('sale_items', {
      'id': 'protected-item',
      'sale_id': 'protected-sale',
      'product_id': 'protected-product',
      'product_name': 'Historical Product',
      'quantity': 1.0,
      'unit_price': 50.0,
      'line_total': 50.0,
    });

    expect(
      () => database.deleteProduct('protected-product'),
      throwsA(isA<StateError>().having(
          (error) => error.message, 'message', contains('completed sales'))),
    );
    expect(await database.searchProducts('Historical', archived: true),
        hasLength(1));
  });

  test('unused archived product can be permanently deleted', () async {
    final now = DateTime.now().toUtc().toIso8601String();
    await rawDatabase.insert('products', {
      'id': 'unused-product',
      'name': 'Unused Product',
      'quantity': 0.0,
      'archived_at': now,
      'updated_at': now,
    });

    await database.deleteProduct('unused-product');

    expect(await database.searchProducts('Unused', archived: true), isEmpty);
    final operation = (await rawDatabase.query('sync_queue')).single;
    expect(operation['type'], 'product.delete');
  });

  test('TRX sale preserves optional receipt name in storage and sync',
      () async {
    final now = DateTime.now().toUtc().toIso8601String();
    await rawDatabase.insert('products', {
      'id': 'product-sale',
      'name': 'Coffee',
      'selling_price': 100.0,
      'quantity': 5.0,
      'updated_at': now,
    });

    await database.saveSale(
      receiptNumber: 'TRX-001',
      receiptName: 'Maria Santos',
      items: [
        {
          'product_id': 'product-sale',
          'product_name': 'Coffee',
          'quantity': 1.0,
          'unit_price': 100.0,
          'line_total': 100.0,
        },
      ],
      payments: [
        {'method': 'cash', 'amount': 100.0},
      ],
    );

    final sale = (await database.recentSales()).single;
    expect(sale['receipt_number'], 'TRX-001');
    expect(sale['receipt_name'], 'Maria Santos');
    expect((await database.saleByReceiptNumber('trx-001'))?['id'], sale['id']);
    expect(await database.saleByReceiptNumber('TRX-MISSING'), isNull);
    final operation = (await rawDatabase.query('sync_queue')).single;
    final payload =
        jsonDecode(operation['payload']! as String) as Map<String, dynamic>;
    expect(payload['receipt_name'], 'Maria Santos');
  });

  test('VAT sale stores tax-inclusive breakdown and receipt identity',
      () async {
    final now = DateTime.now().toUtc().toIso8601String();
    await database.saveSetting('tax_mode', 'vat');
    await database.saveSetting('vat_rate', '.12');
    await database.saveSetting('store_name', 'Sample Store');
    await database.saveSetting('tin', '123-456-789-000');
    await rawDatabase.insert('products', {
      'id': 'vat-product',
      'name': 'VATable Item',
      'selling_price': 112.0,
      'quantity': 3.0,
      'tax_category': 'vatable',
      'updated_at': now,
    });
    await rawDatabase.insert('products', {
      'id': 'exempt-product',
      'name': 'Exempt Item',
      'selling_price': 50.0,
      'quantity': 3.0,
      'tax_category': 'exempt',
      'updated_at': now,
    });

    await database.saveSale(
      receiptNumber: 'TRX-VAT-001',
      items: [
        {
          'product_id': 'vat-product',
          'product_name': 'VATable Item',
          'quantity': 1.0,
          'unit_price': 112.0,
          'line_total': 112.0,
          'tax_category': 'vatable',
        },
        {
          'product_id': 'exempt-product',
          'product_name': 'Exempt Item',
          'quantity': 1.0,
          'unit_price': 50.0,
          'line_total': 50.0,
          'tax_category': 'exempt',
        },
      ],
      payments: [
        {'method': 'cash', 'amount': 162.0},
      ],
    );

    final sale = (await database.saleByReceiptNumber('TRX-VAT-001'))!;
    expect(sale['tax_mode'], 'vat');
    expect(sale['vatable_sales'], closeTo(100, .001));
    expect(sale['vat_amount'], closeTo(12, .001));
    expect(sale['vat_exempt_sales'], closeTo(50, .001));
    expect(sale['zero_rated_sales'], 0.0);
    final profile =
        jsonDecode(sale['receipt_profile']! as String) as Map<String, dynamic>;
    expect(profile['store_name'], 'Sample Store');
    expect(profile['tin'], '123-456-789-000');
  });

  test('credit sale can be marked paid and updates finance and register',
      () async {
    final now = DateTime.now().toUtc().toIso8601String();
    await rawDatabase.insert('products', {
      'id': 'credit-product',
      'name': 'Rice',
      'selling_price': 250.0,
      'quantity': 5.0,
      'updated_at': now,
    });
    await rawDatabase.insert('register_shifts', {
      'id': 'shift-1',
      'opening_cash': 500.0,
      'status': 'open',
      'opened_at': now,
    });

    await database.saveSale(
      receiptNumber: 'TRX-CREDIT-1',
      items: const [
        {
          'product_id': 'credit-product',
          'product_name': 'Rice',
          'quantity': 1.0,
          'unit_price': 250.0,
          'line_total': 250.0,
        },
      ],
      payments: const [
        {'method': 'credit', 'amount': 250.0},
      ],
      credit: const {
        'customer_name': 'Juan Dela Cruz',
        'customer_contact': '09170000000',
        'amount': 250.0,
      },
    );

    final credit = (await database.credits()).single;
    expect(credit['receipt_number'], 'TRX-CREDIT-1');
    expect(credit['balance'], 250.0);
    expect((await database.financeSummary())['outstanding_credit'], 250.0);

    await database.markCreditPaid(credit['id']! as String, method: 'cash');

    final paid = (await database.credits(status: 'paid')).single;
    expect(paid['balance'], 0.0);
    expect(paid['status'], 'paid');
    final summary = await database.financeSummary();
    expect(summary['total_credit'], 250.0);
    expect(summary['outstanding_credit'], 0.0);
    expect(summary['collected_credit'], 250.0);
    expect(await rawDatabase.query('credit_payments'), hasLength(1));
    expect(
        (await rawDatabase.query('cash_movements')).single['type'], 'cash_in');
    final operations = await rawDatabase.query('sync_queue', orderBy: 'rowid');
    expect(
        operations.map((row) => row['type']),
        containsAll(
            ['sale.create', 'credit.payment', 'register.cash_movement']));
  });

  test('cash operating expense updates totals and register cash out', () async {
    final now = DateTime.now().toUtc().toIso8601String();
    await rawDatabase.insert('register_shifts', {
      'id': 'shift-expense',
      'opening_cash': 1000.0,
      'status': 'open',
      'opened_at': now,
    });

    await database.createExpense(
      category: 'Electricity',
      description: 'Monthly electric bill',
      amount: 650.0,
      paymentMethod: 'cash',
      expenseDate: DateTime.now(),
      vendor: 'Electric company',
    );

    final expense = (await database.expenses()).single;
    expect(expense['category'], 'Electricity');
    expect(expense['amount'], 650.0);
    expect((await database.financeSummary())['month_expenses'], 650.0);
    final movement = (await rawDatabase.query('cash_movements')).single;
    expect(movement['type'], 'cash_out');
    expect(movement['amount'], 650.0);
    final operationTypes =
        (await rawDatabase.query('sync_queue')).map((row) => row['type']);
    expect(operationTypes,
        containsAll(['expense.create', 'register.cash_movement']));
  });

  testWidgets('receipt image renders transaction details', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReceiptImage(
          receiptNumber: 'TRX-002',
          receiptName: 'Maria Santos',
          items: const [
            {
              'product_name': 'Coffee',
              'quantity': 2.0,
              'unit_price': 75.0,
              'line_total': 150.0
            },
          ],
          payments: const [
            {'method': 'cash', 'amount': 150.0},
          ],
          total: 150,
        ),
      ),
    ));

    expect(find.text('POS SALES SLIP'), findsOneWidget);
    expect(find.text('NOT VALID AS BIR INVOICE'), findsOneWidget);
    expect(find.text('TRX-002'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
  });

  testWidgets('permitted POS receipt prints invoice identifiers',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReceiptImage(
          receiptNumber: 'TRX-VAT-002',
          items: const [
            {
              'product_name': 'VATable Item',
              'quantity': 1.0,
              'unit_price': 112.0,
              'line_total': 112.0
            },
          ],
          payments: const [
            {'method': 'cash', 'amount': 112.0},
          ],
          total: 112,
          profile: const ReceiptProfile(
            storeName: 'Sample Store',
            registeredName: 'Sample Store Inc.',
            registeredAddress: 'Manila, Philippines',
            tin: '123-456-789-000',
            branchCode: '00001',
            taxMode: 'vat',
            posPermitStatus: 'permitted',
            vatRate: .12,
            permitNumber: 'PTU-001',
            machineIdentificationNumber: 'MIN-001',
            logoPath: '',
          ),
          tax: const SaleTaxSummary(
            mode: 'vat',
            vatRate: .12,
            vatableSales: 100,
            vatAmount: 12,
            vatExemptSales: 0,
            zeroRatedSales: 0,
          ),
        ),
      ),
    ));

    expect(find.text('VAT INVOICE'), findsOneWidget);
    expect(find.text('NOT VALID AS BIR INVOICE'), findsNothing);
    expect(find.text('PTU PTU-001'), findsOneWidget);
    expect(find.text('MIN MIN-001'), findsOneWidget);
  });

  test('server receipt cache makes a remote TRX receipt searchable', () async {
    await database.cacheServerReceipt({
      'sale': {
        'id': 'remote-sale',
        'receipt_number': 'TRX-REMOTE-1',
        'receipt_name': 'Remote Customer',
        'gross_amount': '120.0000',
        'discount_amount': '0.0000',
        'discount_reason': null,
        'net_amount': '120.0000',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'completed',
      },
      'items': [
        {
          'id': 'remote-item',
          'product_id': 'remote-product',
          'product_name': 'Remote Product',
          'quantity': '1.0000',
          'unit_price': '120.0000',
          'discount_amount': '0.0000',
          'line_total': '120.0000',
        },
      ],
      'payments': [
        {
          'id': 'remote-payment',
          'method': 'cash',
          'amount': '120.0000',
          'reference': null
        },
      ],
      'refunds': <Map<String, Object?>>[],
      'refund_items': <Map<String, Object?>>[],
    });

    final sale = await database.saleByReceiptNumber('TRX-REMOTE-1');
    expect(sale?['receipt_name'], 'Remote Customer');
    expect((await database.saleReceipt('remote-sale'))['items'], hasLength(1));
  });
}
