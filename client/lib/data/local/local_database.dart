import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../sale_tax.dart';

class LocalDatabase {
  LocalDatabase(this._database);
  final Database _database;

  static Future<LocalDatabase> open() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final path = join(await getDatabasesPath(), 'pos.sqlite');
    final database =
        await openDatabase(path, version: 13, onCreate: (db, _) async {
      await db.execute('''CREATE TABLE products (
        id TEXT PRIMARY KEY, sku TEXT, barcode TEXT, name TEXT NOT NULL,
        selling_price REAL NOT NULL, cost_price REAL NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'piece',
        quantity REAL NOT NULL DEFAULT 0, reorder_level REAL NOT NULL DEFAULT 0,
        allow_negative_stock INTEGER NOT NULL DEFAULT 0,
        tax_category TEXT NOT NULL DEFAULT 'vatable', archived_at TEXT, updated_at TEXT NOT NULL
      )''');
      await db.execute('''CREATE TABLE sales (
        id TEXT PRIMARY KEY, receipt_number TEXT NOT NULL, gross_amount REAL NOT NULL,
        discount_amount REAL NOT NULL DEFAULT 0, discount_reason TEXT, receipt_name TEXT, net_amount REAL NOT NULL,
        tax_mode TEXT NOT NULL DEFAULT 'unregistered', vat_rate REAL NOT NULL DEFAULT 0,
        vatable_sales REAL NOT NULL DEFAULT 0, vat_amount REAL NOT NULL DEFAULT 0,
        vat_exempt_sales REAL NOT NULL DEFAULT 0, zero_rated_sales REAL NOT NULL DEFAULT 0,
        receipt_profile TEXT,
        occurred_at TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'completed'
      )''');
      await db.execute('''CREATE TABLE sale_items (
        id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, product_id TEXT NOT NULL,
        product_name TEXT NOT NULL, quantity REAL NOT NULL, unit_price REAL NOT NULL,
        discount_amount REAL NOT NULL DEFAULT 0, line_total REAL NOT NULL,
        tax_category TEXT NOT NULL DEFAULT 'vatable'
      )''');
      await db.execute('''CREATE TABLE payments (
        id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, method TEXT NOT NULL,
        amount REAL NOT NULL, reference TEXT
      )''');
      await db.execute('''CREATE TABLE sync_queue (
        operation_id TEXT PRIMARY KEY, type TEXT NOT NULL, payload TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT, created_at TEXT NOT NULL, synced_at TEXT
      )''');
      await db.execute('''CREATE TABLE app_settings (
        key TEXT PRIMARY KEY, value TEXT NOT NULL
      )''');
      await db.execute('''CREATE TABLE inventory_movements (
        id TEXT PRIMARY KEY, product_id TEXT NOT NULL, quantity_delta REAL NOT NULL,
        reason TEXT NOT NULL, note TEXT, occurred_at TEXT NOT NULL
      )''');
      await _createRegisterTables(db);
      await _createHeldSaleTables(db);
      await _createRefundTables(db);
      await _createFinanceTables(db);
      await _createCredentialTable(db);
      await _createStaffTable(db);
    }, onUpgrade: (db, oldVersion, _) async {
      if (oldVersion < 2) {
        await db.execute(
            'ALTER TABLE products ADD COLUMN allow_negative_stock INTEGER NOT NULL DEFAULT 0');
        await db.execute('''CREATE TABLE inventory_movements (
          id TEXT PRIMARY KEY, product_id TEXT NOT NULL, quantity_delta REAL NOT NULL,
          reason TEXT NOT NULL, note TEXT, occurred_at TEXT NOT NULL
        )''');
      }
      if (oldVersion < 3) {
        await db.execute(
            'ALTER TABLE products ADD COLUMN reorder_level REAL NOT NULL DEFAULT 0');
      }
      if (oldVersion < 4) {
        await db.execute(
            'ALTER TABLE products ADD COLUMN cost_price REAL NOT NULL DEFAULT 0');
      }
      if (oldVersion < 5) {
        await db.execute('ALTER TABLE sales ADD COLUMN discount_reason TEXT');
      }
      if (oldVersion < 6) {
        await _createRegisterTables(db);
      }
      if (oldVersion < 7) {
        await _createHeldSaleTables(db);
      }
      if (oldVersion < 8) {
        await _createRefundTables(db);
      }
      if (oldVersion < 9) {
        await db.execute('ALTER TABLE products ADD COLUMN archived_at TEXT');
        await db.execute('ALTER TABLE sales ADD COLUMN receipt_name TEXT');
      }
      if (oldVersion < 10) {
        await _createFinanceTables(db);
      }
      if (oldVersion < 11) {
        await db.execute(
            "ALTER TABLE products ADD COLUMN tax_category TEXT NOT NULL DEFAULT 'vatable'");
        await db.execute(
            "ALTER TABLE sale_items ADD COLUMN tax_category TEXT NOT NULL DEFAULT 'vatable'");
        await db.execute(
            "ALTER TABLE held_sale_items ADD COLUMN tax_category TEXT NOT NULL DEFAULT 'vatable'");
        await db.execute(
            "ALTER TABLE sales ADD COLUMN tax_mode TEXT NOT NULL DEFAULT 'unregistered'");
        await db.execute(
            'ALTER TABLE sales ADD COLUMN vat_rate REAL NOT NULL DEFAULT 0');
        await db.execute(
            'ALTER TABLE sales ADD COLUMN vatable_sales REAL NOT NULL DEFAULT 0');
        await db.execute(
            'ALTER TABLE sales ADD COLUMN vat_amount REAL NOT NULL DEFAULT 0');
        await db.execute(
            'ALTER TABLE sales ADD COLUMN vat_exempt_sales REAL NOT NULL DEFAULT 0');
        await db.execute(
            'ALTER TABLE sales ADD COLUMN zero_rated_sales REAL NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE sales ADD COLUMN receipt_profile TEXT');
      }
      if (oldVersion < 12) {
        await _createCredentialTable(db);
      }
      if (oldVersion < 13) {
        // Added after some devices had already migrated to v12, so this runs
        // as its own step to reach every install.
        await _createStaffTable(db);
      }
    });
    return LocalDatabase(database);
  }

  // Stores a salted password hash for each user who has signed in online on
  // this device, so they can still sign in while the server is unreachable.
  static Future<void> _createCredentialTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE cached_credentials (
      username TEXT PRIMARY KEY, password_salt TEXT NOT NULL,
      password_hash TEXT NOT NULL, user_name TEXT NOT NULL,
      user_role TEXT NOT NULL, branch_id TEXT NOT NULL, token TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
  }

  // Local mirror of the server's staff list, so an admin can view and manage
  // staff while the server is unreachable. Mutations are applied here and
  // queued in sync_queue to push on reconnect.
  static Future<void> _createStaffTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS staff_users (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT, username TEXT,
      role TEXT NOT NULL, deactivated_at TEXT, updated_at TEXT NOT NULL
    )''');
  }

  static Future<void> _createRegisterTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE register_shifts (
      id TEXT PRIMARY KEY, opening_cash REAL NOT NULL, status TEXT NOT NULL,
      opened_at TEXT NOT NULL, closed_at TEXT, expected_cash REAL,
      actual_cash REAL, variance REAL, note TEXT
    )''');
    await db.execute('''CREATE TABLE cash_movements (
      id TEXT PRIMARY KEY, shift_id TEXT NOT NULL, type TEXT NOT NULL,
      amount REAL NOT NULL, note TEXT, occurred_at TEXT NOT NULL
    )''');
  }

  static Future<void> _createHeldSaleTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE held_sales (
      id TEXT PRIMARY KEY, label TEXT NOT NULL, discount_amount REAL NOT NULL DEFAULT 0,
      discount_reason TEXT, created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE held_sale_items (
      id TEXT PRIMARY KEY, held_sale_id TEXT NOT NULL, product_id TEXT NOT NULL,
      product_name TEXT NOT NULL, quantity REAL NOT NULL, unit_price REAL NOT NULL,
      line_total REAL NOT NULL, tax_category TEXT NOT NULL DEFAULT 'vatable'
    )''');
  }

  static Future<void> _createRefundTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE refunds (
      id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, refund_number TEXT NOT NULL,
      amount REAL NOT NULL, method TEXT NOT NULL, reason TEXT NOT NULL,
      occurred_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE refund_items (
      id TEXT PRIMARY KEY, refund_id TEXT NOT NULL, sale_item_id TEXT NOT NULL,
      product_id TEXT NOT NULL, product_name TEXT NOT NULL, quantity REAL NOT NULL,
      unit_price REAL NOT NULL, amount REAL NOT NULL
    )''');
  }

  static Future<void> _createFinanceTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE credits (
      id TEXT PRIMARY KEY, sale_id TEXT, receipt_number TEXT,
      customer_name TEXT NOT NULL, customer_contact TEXT,
      original_amount REAL NOT NULL, balance REAL NOT NULL,
      status TEXT NOT NULL DEFAULT 'unpaid', due_at TEXT, note TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL, paid_at TEXT
    )''');
    await db.execute('''CREATE TABLE credit_payments (
      id TEXT PRIMARY KEY, credit_id TEXT NOT NULL, amount REAL NOT NULL,
      method TEXT NOT NULL, note TEXT, paid_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE expenses (
      id TEXT PRIMARY KEY, category TEXT NOT NULL, description TEXT NOT NULL,
      amount REAL NOT NULL, payment_method TEXT NOT NULL, vendor TEXT,
      expense_date TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    await db.execute(
        'CREATE INDEX idx_credits_status_created ON credits(status, created_at DESC)');
    await db.execute(
        'CREATE INDEX idx_expenses_date ON expenses(expense_date DESC)');
  }

  Future<List<Map<String, Object?>>> searchProducts(String query,
          {bool archived = false, int limit = 50, int offset = 0}) =>
      _database.query(
        'products',
        where:
            '(name LIKE ? OR sku LIKE ? OR barcode LIKE ?) AND archived_at IS ${archived ? 'NOT ' : ''}NULL',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'name',
        limit: limit,
        offset: offset,
      );

  /// Name + barcode of every product (archived included), used to reject
  /// duplicate rows during a bulk CSV import.
  Future<List<Map<String, Object?>>> allProductIdentifiers() =>
      _database.query('products', columns: ['name', 'barcode']);

  Future<Map<String, Object?>?> findByBarcodeOrSku(String code) async {
    final products = await _database.query('products',
        where: '(barcode = ? OR sku = ?) AND archived_at IS NULL',
        whereArgs: [code, code],
        limit: 1);
    return products.isEmpty ? null : products.single;
  }

  Future<Map<String, num>> inventorySummary() async {
    final rows = await _database.rawQuery('''
      SELECT
        COUNT(*) AS product_count,
        COALESCE(SUM(quantity), 0) AS total_quantity,
        COALESCE(SUM(CASE WHEN quantity <= reorder_level THEN 1 ELSE 0 END), 0) AS low_stock_count,
        COALESCE(SUM(quantity * cost_price), 0) AS stock_value
      FROM products WHERE archived_at IS NULL
    ''');
    final row = rows.single;
    return {
      'product_count': (row['product_count'] as num?) ?? 0,
      'total_quantity': (row['total_quantity'] as num?) ?? 0,
      'low_stock_count': (row['low_stock_count'] as num?) ?? 0,
      'stock_value': (row['stock_value'] as num?) ?? 0,
    };
  }

  Future<Map<String, num>> salesSummaryToday() async {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final end =
        DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();
    final rows = await _database.rawQuery('''
      SELECT
        COUNT(*) AS transaction_count,
        COALESCE(SUM(net_amount), 0) AS net_sales,
        COALESCE(SUM(gross_amount), 0) AS gross_sales,
        (
          SELECT COALESCE(SUM(sale_items.line_total - (sale_items.quantity * products.cost_price)), 0)
          FROM sale_items
          INNER JOIN sales AS item_sales ON item_sales.id = sale_items.sale_id
          LEFT JOIN products ON products.id = sale_items.product_id
          WHERE item_sales.status = 'completed' AND item_sales.occurred_at >= ? AND item_sales.occurred_at < ?
        ) AS estimated_profit
      FROM sales
      WHERE sales.status = 'completed' AND sales.occurred_at >= ? AND sales.occurred_at < ?
    ''', [start, end, start, end]);
    final row = rows.single;
    final refundRows = await _database.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(amount), 0) FROM refunds
          WHERE occurred_at >= ? AND occurred_at < ?) AS amount,
        (SELECT COALESCE(SUM(refund_items.amount - (refund_items.quantity * products.cost_price)), 0)
          FROM refund_items INNER JOIN refunds ON refunds.id = refund_items.refund_id
          LEFT JOIN products ON products.id = refund_items.product_id
          WHERE refunds.occurred_at >= ? AND refunds.occurred_at < ?) AS profit_reversal
    ''', [start, end, start, end]);
    final refunds = (refundRows.single['amount'] as num?) ?? 0;
    final profitReversal = (refundRows.single['profit_reversal'] as num?) ?? 0;
    return {
      'transaction_count': (row['transaction_count'] as num?) ?? 0,
      'net_sales': ((row['net_sales'] as num?) ?? 0) - refunds,
      'gross_sales': (row['gross_sales'] as num?) ?? 0,
      'refunds': refunds,
      'estimated_profit':
          ((row['estimated_profit'] as num?) ?? 0) - profitReversal,
    };
  }

  Future<List<Map<String, Object?>>> salesTrend({int days = 7}) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day - days + 1)
        .toUtc()
        .toIso8601String();
    return _database.rawQuery('''
      SELECT activity_day AS sale_day, COALESCE(SUM(amount), 0) AS amount
      FROM (
        SELECT substr(occurred_at, 1, 10) AS activity_day, net_amount AS amount
        FROM sales WHERE status = 'completed' AND occurred_at >= ?
        UNION ALL
        SELECT substr(occurred_at, 1, 10) AS activity_day, -amount AS amount
        FROM refunds WHERE occurred_at >= ?
      )
      GROUP BY activity_day
      ORDER BY sale_day ASC
    ''', [start, start]);
  }

  Future<List<Map<String, Object?>>> topSellingProducts({int limit = 5}) async {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final end =
        DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();
    return _database.rawQuery('''
      SELECT sale_items.product_name, COALESCE(SUM(sale_items.quantity), 0) AS quantity, COALESCE(SUM(sale_items.line_total), 0) AS amount
      FROM sale_items
      INNER JOIN sales ON sales.id = sale_items.sale_id
      WHERE sales.status = 'completed' AND sales.occurred_at >= ? AND sales.occurred_at < ?
      GROUP BY sale_items.product_id, sale_items.product_name
      ORDER BY amount DESC
      LIMIT ?
    ''', [start, end, limit]);
  }

  Future<List<Map<String, Object?>>> salesByPaymentMethod() async {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final end =
        DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();
    return _database.rawQuery('''
      SELECT method, COALESCE(SUM(amount), 0) AS amount FROM (
        SELECT payments.method, payments.amount
        FROM payments INNER JOIN sales ON sales.id = payments.sale_id
        WHERE sales.status = 'completed' AND sales.occurred_at >= ? AND sales.occurred_at < ?
        UNION ALL
        SELECT method, -amount FROM refunds WHERE occurred_at >= ? AND occurred_at < ?
      ) GROUP BY method
      ORDER BY amount DESC
    ''', [start, end, start, end]);
  }

  Future<List<Map<String, Object?>>> lowStockProducts({int limit = 5}) =>
      _database.query(
        'products',
        where: 'quantity <= reorder_level AND archived_at IS NULL',
        orderBy: 'quantity ASC, name ASC',
        limit: limit,
      );

  Future<List<Map<String, Object?>>> recentSales(
          {String query = '',
          String filter = 'all',
          int limit = 50,
          int offset = 0}) =>
      _database.rawQuery('''
        SELECT sales.*, COALESCE(SUM(refunds.amount), 0) AS refunded_amount
        FROM sales LEFT JOIN refunds ON refunds.sale_id = sales.id
        WHERE sales.receipt_number LIKE ?
        GROUP BY sales.id
        ${filter == 'completed' ? 'HAVING COALESCE(SUM(refunds.amount), 0) = 0' : filter == 'returned' ? 'HAVING COALESCE(SUM(refunds.amount), 0) > 0' : ''}
        ORDER BY sales.occurred_at DESC
        LIMIT ? OFFSET ?
      ''', ['%${query.trim()}%', limit, offset]);

  Future<Map<String, Object?>?> saleByReceiptNumber(
      String receiptNumber) async {
    final rows = await _database.rawQuery('''
      SELECT sales.*, COALESCE(SUM(refunds.amount), 0) AS refunded_amount
      FROM sales LEFT JOIN refunds ON refunds.sale_id = sales.id
      WHERE UPPER(sales.receipt_number) = UPPER(?)
      GROUP BY sales.id LIMIT 1
    ''', [receiptNumber.trim()]);
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> cacheServerReceipt(Map<String, dynamic> receipt) async {
    final sale = receipt['sale']! as Map<String, dynamic>;
    final items =
        (receipt['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final payments = (receipt['payments'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final refunds = (receipt['refunds'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final refundItems = (receipt['refund_items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    await _database.transaction((txn) async {
      await txn.insert(
          'sales',
          {
            'id': sale['id'],
            'receipt_number': sale['receipt_number'],
            'receipt_name': sale['receipt_name'],
            'gross_amount': _number(sale['gross_amount']),
            'discount_amount': _number(sale['discount_amount']),
            'discount_reason': sale['discount_reason'],
            'net_amount': _number(sale['net_amount']),
            'tax_mode': sale['tax_mode'] ?? 'unregistered',
            'vat_rate': _number(sale['vat_rate'] ?? 0),
            'vatable_sales': _number(sale['vatable_sales'] ?? 0),
            'vat_amount': _number(sale['vat_amount'] ?? 0),
            'vat_exempt_sales': _number(sale['vat_exempt_sales'] ?? 0),
            'zero_rated_sales': _number(sale['zero_rated_sales'] ?? 0),
            'receipt_profile': sale['receipt_profile'] is String
                ? sale['receipt_profile']
                : jsonEncode(sale['receipt_profile']),
            'occurred_at': sale['occurred_at'],
            'status': sale['status'] ?? 'completed',
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      final localItemIds = <String, String>{};
      for (final item in items) {
        final existing = await txn.query('sale_items',
            where: 'sale_id = ? AND product_id = ?',
            whereArgs: [sale['id'], item['product_id']],
            limit: 1);
        final localId = existing.isEmpty
            ? item['id']! as String
            : existing.single['id']! as String;
        localItemIds[item['product_id']! as String] = localId;
        await txn.insert(
            'sale_items',
            {
              'id': localId,
              'sale_id': sale['id'],
              'product_id': item['product_id'],
              'product_name': item['product_name'],
              'quantity': _number(item['quantity']),
              'unit_price': _number(item['unit_price']),
              'discount_amount': _number(item['discount_amount']),
              'line_total': _number(item['line_total']),
              'tax_category': item['tax_category'] ?? 'vatable',
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final localPayments = await txn.query('payments',
          where: 'sale_id = ?', whereArgs: [sale['id']], limit: 1);
      if (localPayments.isEmpty) {
        for (final payment in payments) {
          await txn.insert('payments', {
            'id': payment['id'],
            'sale_id': sale['id'],
            'method': payment['method'],
            'amount': _number(payment['amount']),
            'reference': payment['reference'],
          });
        }
      }
      for (final refund in refunds) {
        await txn.insert(
            'refunds',
            {
              'id': refund['id'],
              'sale_id': sale['id'],
              'refund_number': refund['refund_number'],
              'amount': _number(refund['amount']),
              'method': refund['method'],
              'reason': refund['reason'],
              'occurred_at': refund['occurred_at'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final item in refundItems) {
        final localSaleItemId = localItemIds[item['product_id']];
        if (localSaleItemId == null) continue;
        final existing = await txn.query('refund_items',
            where: 'refund_id = ? AND product_id = ?',
            whereArgs: [item['refund_id'], item['product_id']],
            limit: 1);
        await txn.insert(
            'refund_items',
            {
              'id': existing.isEmpty ? item['id'] : existing.single['id'],
              'refund_id': item['refund_id'],
              'sale_item_id': localSaleItemId,
              'product_id': item['product_id'],
              'product_name': items.firstWhere((saleItem) =>
                  saleItem['product_id'] == item['product_id'])['product_name'],
              'quantity': _number(item['quantity']),
              'unit_price': _number(items.firstWhere((saleItem) =>
                  saleItem['product_id'] == item['product_id'])['unit_price']),
              'amount': _number(item['amount']),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.parse(value.toString());

  Future<Map<String, List<Map<String, Object?>>>> saleReceipt(
          String saleId) async =>
      {
        'items': await _database.rawQuery('''
          SELECT sale_items.*,
            COALESCE((SELECT SUM(refund_items.quantity) FROM refund_items
              INNER JOIN refunds ON refunds.id = refund_items.refund_id
              WHERE refund_items.sale_item_id = sale_items.id), 0) AS returned_quantity
          FROM sale_items WHERE sale_items.sale_id = ?
        ''', [saleId]),
        'payments': await _database
            .query('payments', where: 'sale_id = ?', whereArgs: [saleId]),
        'refunds': await _database.query('refunds',
            where: 'sale_id = ?',
            whereArgs: [saleId],
            orderBy: 'occurred_at DESC'),
      };

  Future<Map<String, Object?>?> activeRegisterShift() async {
    final rows = await _database.query('register_shifts',
        where: 'status = ?',
        whereArgs: ['open'],
        orderBy: 'opened_at DESC',
        limit: 1);
    return rows.isEmpty ? null : rows.single;
  }

  Future<List<Map<String, Object?>>> registerShifts(
          {int limit = 20, int offset = 0}) =>
      _database.query('register_shifts',
          orderBy: 'opened_at DESC', limit: limit, offset: offset);

  Future<List<Map<String, Object?>>> cashMovements(String shiftId) =>
      _database.query('cash_movements',
          where: 'shift_id = ?',
          whereArgs: [shiftId],
          orderBy: 'occurred_at DESC');

  Future<Map<String, num>> registerSummary(Map<String, Object?> shift) async {
    final shiftId = shift['id']! as String;
    final openedAt = shift['opened_at']! as String;
    final cashSalesRows = await _database.rawQuery('''
      SELECT COALESCE(SUM(payments.amount), 0) AS amount
      FROM payments INNER JOIN sales ON sales.id = payments.sale_id
      WHERE payments.method = 'cash' AND sales.status = 'completed' AND sales.occurred_at >= ?
    ''', [openedAt]);
    final cashRefundRows = await _database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS amount FROM refunds
      WHERE method = 'cash' AND occurred_at >= ?
    ''', [openedAt]);
    final movementRows = await _database.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'cash_in' THEN amount ELSE 0 END), 0) AS cash_in,
        COALESCE(SUM(CASE WHEN type = 'cash_out' THEN amount ELSE 0 END), 0) AS cash_out
      FROM cash_movements WHERE shift_id = ?
    ''', [shiftId]);
    final opening = (shift['opening_cash'] as num).toDouble();
    final cashSales = (cashSalesRows.single['amount'] as num).toDouble();
    final cashRefunds = (cashRefundRows.single['amount'] as num).toDouble();
    final cashIn = (movementRows.single['cash_in'] as num).toDouble();
    final cashOut = (movementRows.single['cash_out'] as num).toDouble();
    return {
      'opening_cash': opening,
      'cash_sales': cashSales,
      'cash_refunds': cashRefunds,
      'cash_in': cashIn,
      'cash_out': cashOut,
      'expected_cash': opening + cashSales + cashIn - cashOut - cashRefunds
    };
  }

  Future<void> openRegister({required double openingCash, String? note}) async {
    if (openingCash < 0) {
      throw ArgumentError.value(
          openingCash, 'openingCash', 'must not be negative');
    }
    if (await activeRegisterShift() != null) {
      throw StateError('A register shift is already open.');
    }
    const uuid = Uuid();
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'id': id,
      'opening_cash': openingCash,
      'note': note,
      'opened_at': now
    };
    await _database.transaction((txn) async {
      await txn.insert('register_shifts', {
        'id': id,
        'opening_cash': openingCash,
        'status': 'open',
        'opened_at': now,
        'note': note
      });
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'register.open',
        'payload': jsonEncode(payload),
        'created_at': now
      });
    });
  }

  Future<void> addCashMovement(
      {required String shiftId,
      required String type,
      required double amount,
      String? note}) async {
    if (!['cash_in', 'cash_out'].contains(type) || amount <= 0) {
      throw ArgumentError('Invalid cash movement.');
    }
    const uuid = Uuid();
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'id': id,
      'shift_id': shiftId,
      'type': type,
      'amount': amount,
      'note': note,
      'occurred_at': now
    };
    await _database.transaction((txn) async {
      final shift = await txn.query('register_shifts',
          where: 'id = ? AND status = ?',
          whereArgs: [shiftId, 'open'],
          limit: 1);
      if (shift.isEmpty) throw StateError('The register shift is not open.');
      await txn.insert('cash_movements', payload);
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'register.cash_movement',
        'payload': jsonEncode(payload),
        'created_at': now
      });
    });
  }

  Future<Map<String, num>> closeRegister(
      {required String shiftId,
      required double actualCash,
      String? note}) async {
    if (actualCash < 0) {
      throw ArgumentError.value(
          actualCash, 'actualCash', 'must not be negative');
    }
    final shift = await activeRegisterShift();
    if (shift == null || shift['id'] != shiftId) {
      throw StateError('The register shift is not open.');
    }
    final summary = await registerSummary(shift);
    final expected = summary['expected_cash']!.toDouble();
    final variance = actualCash - expected;
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'id': shiftId,
      'expected_cash': expected,
      'actual_cash': actualCash,
      'variance': variance,
      'note': note,
      'closed_at': now
    };
    await _database.transaction((txn) async {
      await txn.update(
          'register_shifts',
          {
            'status': 'closed',
            'expected_cash': expected,
            'actual_cash': actualCash,
            'variance': variance,
            'closed_at': now,
            if (note != null) 'note': note
          },
          where: 'id = ?',
          whereArgs: [shiftId]);
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'register.close',
        'payload': jsonEncode(payload),
        'created_at': now
      });
    });
    return {
      'expected_cash': expected,
      'actual_cash': actualCash,
      'variance': variance
    };
  }

  Future<void> holdSale(
      {required String label,
      required List<Map<String, Object?>> items,
      double discountAmount = 0,
      String? discountReason}) async {
    if (items.isEmpty) throw StateError('Cannot hold an empty sale.');
    const uuid = Uuid();
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      await txn.insert('held_sales', {
        'id': id,
        'label': label.trim().isEmpty ? 'Held sale' : label.trim(),
        'discount_amount': discountAmount,
        'discount_reason': discountReason,
        'created_at': now
      });
      for (final item in items) {
        await txn.insert('held_sale_items', {
          'id': uuid.v4(),
          'held_sale_id': id,
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'line_total': item['line_total'],
          'tax_category': item['tax_category'] ?? 'vatable'
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> heldSales(
          {int limit = 20, int offset = 0}) =>
      _database.rawQuery('''
        SELECT held_sales.*, COUNT(held_sale_items.id) AS item_count,
          COALESCE(SUM(held_sale_items.line_total), 0) - held_sales.discount_amount AS total
        FROM held_sales LEFT JOIN held_sale_items ON held_sale_items.held_sale_id = held_sales.id
        GROUP BY held_sales.id ORDER BY held_sales.created_at DESC LIMIT ? OFFSET ?
      ''', [limit, offset]);

  Future<List<Map<String, Object?>>> heldSaleItems(String heldSaleId) =>
      _database.query('held_sale_items',
          where: 'held_sale_id = ?', whereArgs: [heldSaleId]);

  Future<void> deleteHeldSale(String heldSaleId) async {
    await _database.transaction((txn) async {
      await txn.delete('held_sale_items',
          where: 'held_sale_id = ?', whereArgs: [heldSaleId]);
      await txn.delete('held_sales', where: 'id = ?', whereArgs: [heldSaleId]);
    });
  }

  Future<String> refundSale({
    required String saleId,
    required List<Map<String, Object?>> items,
    required String method,
    required String reason,
  }) async {
    if (items.isEmpty) throw StateError('Select at least one item to return.');
    if (reason.trim().isEmpty) throw StateError('Enter a refund reason.');
    if (!['cash', 'card', 'gcash', 'maya', 'bank_transfer'].contains(method)) {
      throw StateError('Select a valid refund method.');
    }
    const uuid = Uuid();
    final refundId = uuid.v4();
    final refundNumber = 'REF-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final sales = await txn.query('sales',
          where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (sales.isEmpty) throw StateError('The original sale was not found.');
      final sale = sales.single;
      final grossAmount = (sale['gross_amount'] as num).toDouble();
      final netAmount = (sale['net_amount'] as num).toDouble();
      final discountRatio = grossAmount == 0 ? 1.0 : netAmount / grossAmount;
      final existingRefunds = await txn.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) AS amount FROM refunds WHERE sale_id = ?',
          [saleId]);
      final remainingRefund =
          netAmount - (existingRefunds.single['amount'] as num).toDouble();
      final refundItems = <Map<String, Object?>>[];
      var refundAmount = 0.0;
      for (final requested in items) {
        final saleItemId = requested['sale_item_id']! as String;
        final quantity = (requested['quantity'] as num).toDouble();
        if (quantity <= 0) {
          throw StateError('Return quantities must be positive.');
        }
        final soldRows = await txn.query('sale_items',
            where: 'id = ? AND sale_id = ?',
            whereArgs: [saleItemId, saleId],
            limit: 1);
        if (soldRows.isEmpty) {
          throw StateError('A selected sale item was not found.');
        }
        final sold = soldRows.single;
        final returnedRows = await txn.rawQuery('''
          SELECT COALESCE(SUM(refund_items.quantity), 0) AS quantity
          FROM refund_items INNER JOIN refunds ON refunds.id = refund_items.refund_id
          WHERE refund_items.sale_item_id = ? AND refunds.sale_id = ?
        ''', [saleItemId, saleId]);
        final alreadyReturned =
            (returnedRows.single['quantity'] as num).toDouble();
        final soldQuantity = (sold['quantity'] as num).toDouble();
        if (quantity > soldQuantity - alreadyReturned + .0001) {
          throw StateError(
              'Return quantity exceeds the remaining quantity for ${sold['product_name']}.');
        }
        final itemAmount = _money(
            quantity * (sold['unit_price'] as num).toDouble() * discountRatio);
        refundAmount += itemAmount;
        refundItems.add({
          'id': uuid.v4(),
          'refund_id': refundId,
          'sale_item_id': saleItemId,
          'product_id': sold['product_id'],
          'product_name': sold['product_name'],
          'quantity': quantity,
          'unit_price': sold['unit_price'],
          'amount': itemAmount,
        });
      }
      refundAmount = _money(refundAmount);
      if (refundAmount > remainingRefund) {
        refundAmount = _money(remainingRefund);
      }
      if (refundAmount <= 0) {
        throw StateError('This sale is already fully refunded.');
      }
      final allocated = refundItems.fold<double>(
          0, (sum, item) => sum + (item['amount'] as num).toDouble());
      refundItems.last['amount'] = _money(
          (refundItems.last['amount'] as num).toDouble() +
              refundAmount -
              allocated);
      await txn.insert('refunds', {
        'id': refundId,
        'sale_id': saleId,
        'refund_number': refundNumber,
        'amount': refundAmount,
        'method': method,
        'reason': reason.trim(),
        'occurred_at': now,
      });
      for (final item in refundItems) {
        await txn.insert('refund_items', item);
        await txn.rawUpdate(
            'UPDATE products SET quantity = quantity + ? WHERE id = ?',
            [item['quantity'], item['product_id']]);
        await txn.insert('inventory_movements', {
          'id': uuid.v4(),
          'product_id': item['product_id'],
          'quantity_delta': item['quantity'],
          'reason': 'return',
          'note': '$refundNumber: ${reason.trim()}',
          'occurred_at': now,
        });
      }
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'sale.refund',
        'payload': jsonEncode({
          'id': refundId,
          'sale_id': saleId,
          'refund_number': refundNumber,
          'amount': refundAmount,
          'method': method,
          'reason': reason.trim(),
          'occurred_at': now,
          'items': refundItems
              .map((item) => {
                    'id': item['id'],
                    'product_id': item['product_id'],
                    'quantity': item['quantity'],
                    'amount': item['amount'],
                  })
              .toList(),
        }),
        'created_at': now,
      });
    });
    return refundNumber;
  }

  static double _money(double value) => (value * 100).round() / 100;

  Future<Map<String, num>> salesSummaryForRange(
      {required DateTime start, required DateTime end}) async {
    final rows = await _database.rawQuery('''
      SELECT
        COUNT(*) AS transaction_count,
        COALESCE(SUM(net_amount), 0) AS net_sales,
        COALESCE(SUM(gross_amount), 0) AS gross_sales,
        (
          SELECT COALESCE(SUM(sale_items.line_total - (sale_items.quantity * products.cost_price)), 0)
          FROM sale_items
          INNER JOIN sales AS item_sales ON item_sales.id = sale_items.sale_id
          LEFT JOIN products ON products.id = sale_items.product_id
          WHERE item_sales.status = 'completed' AND item_sales.occurred_at >= ? AND item_sales.occurred_at < ?
        ) AS estimated_profit
      FROM sales
      WHERE status = 'completed' AND occurred_at >= ? AND occurred_at < ?
    ''', [
      start.toUtc().toIso8601String(),
      end.toUtc().toIso8601String(),
      start.toUtc().toIso8601String(),
      end.toUtc().toIso8601String()
    ]);
    final row = rows.single;
    final refundRows = await _database.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(amount), 0) FROM refunds
          WHERE occurred_at >= ? AND occurred_at < ?) AS amount,
        (SELECT COALESCE(SUM(refund_items.amount - (refund_items.quantity * products.cost_price)), 0)
          FROM refund_items INNER JOIN refunds ON refunds.id = refund_items.refund_id
          LEFT JOIN products ON products.id = refund_items.product_id
          WHERE refunds.occurred_at >= ? AND refunds.occurred_at < ?) AS profit_reversal
    ''', [
      start.toUtc().toIso8601String(),
      end.toUtc().toIso8601String(),
      start.toUtc().toIso8601String(),
      end.toUtc().toIso8601String(),
    ]);
    final refunds = (refundRows.single['amount'] as num?) ?? 0;
    final profitReversal = (refundRows.single['profit_reversal'] as num?) ?? 0;
    return {
      'transaction_count': (row['transaction_count'] as num?) ?? 0,
      'net_sales': ((row['net_sales'] as num?) ?? 0) - refunds,
      'gross_sales': (row['gross_sales'] as num?) ?? 0,
      'refunds': refunds,
      'estimated_profit':
          ((row['estimated_profit'] as num?) ?? 0) - profitReversal,
    };
  }

  Future<List<Map<String, Object?>>> salesTrendForRange(
          {required DateTime start, required DateTime end}) =>
      _database.rawQuery('''
    SELECT activity_day AS sale_day, COALESCE(SUM(amount), 0) AS amount FROM (
      SELECT substr(occurred_at, 1, 10) AS activity_day, net_amount AS amount
      FROM sales WHERE status = 'completed' AND occurred_at >= ? AND occurred_at < ?
      UNION ALL
      SELECT substr(occurred_at, 1, 10) AS activity_day, -amount AS amount
      FROM refunds WHERE occurred_at >= ? AND occurred_at < ?
    ) GROUP BY activity_day
    ORDER BY sale_day ASC
  ''', [
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String()
      ]);

  Future<List<Map<String, Object?>>> topSellingProductsForRange(
          {required DateTime start, required DateTime end, int limit = 8}) =>
      _database.rawQuery('''
    SELECT sale_items.product_name, COALESCE(SUM(sale_items.quantity), 0) AS quantity, COALESCE(SUM(sale_items.line_total), 0) AS amount
    FROM sale_items
    INNER JOIN sales ON sales.id = sale_items.sale_id
    WHERE sales.status = 'completed' AND sales.occurred_at >= ? AND sales.occurred_at < ?
    GROUP BY sale_items.product_id, sale_items.product_name
    ORDER BY amount DESC
    LIMIT ?
  ''', [start.toUtc().toIso8601String(), end.toUtc().toIso8601String(), limit]);

  Future<List<Map<String, Object?>>> salesByPaymentMethodForRange(
          {required DateTime start, required DateTime end}) =>
      _database.rawQuery('''
    SELECT method, COALESCE(SUM(amount), 0) AS amount FROM (
      SELECT payments.method, payments.amount
      FROM payments INNER JOIN sales ON sales.id = payments.sale_id
      WHERE sales.status = 'completed' AND sales.occurred_at >= ? AND sales.occurred_at < ?
      UNION ALL
      SELECT method, -amount FROM refunds WHERE occurred_at >= ? AND occurred_at < ?
    ) GROUP BY method
    ORDER BY amount DESC
  ''', [
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String()
      ]);

  Future<void> saveProduct(
      {required String name,
      required double sellingPrice,
      required String unit,
      String? sku,
      String? barcode,
      double reorderLevel = 0,
      double costPrice = 0,
      bool allowNegativeStock = false,
      String taxCategory = 'vatable'}) async {
    const uuid = Uuid();
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final product = {
      'id': id,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'selling_price': sellingPrice,
      'cost_price': costPrice,
      'unit': unit,
      'reorder_level': reorderLevel,
      'tax_category': taxCategory,
      'allow_negative_stock': allowNegativeStock,
      'updated_at': now,
    };
    await _database.transaction((txn) async {
      await txn.insert('products', {
        ...product,
        'quantity': 0,
        'allow_negative_stock': allowNegativeStock ? 1 : 0
      });
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'product.create',
        'payload': jsonEncode(product),
        'created_at': now
      });
    });
  }

  /// Bulk-inserts imported products in a single transaction (far faster than
  /// one transaction per row) and queues a `product.create` op for each.
  /// Each item uses the same keys as [saveProduct]'s parameters
  /// (name, sellingPrice, unit, sku, barcode, reorderLevel, costPrice,
  /// taxCategory). Returns the number of products inserted.
  Future<int> importProducts(List<Map<String, Object?>> items) async {
    if (items.isEmpty) return 0;
    const uuid = Uuid();
    var inserted = 0;
    await _database.transaction((txn) async {
      for (final item in items) {
        final id = uuid.v4();
        final now = DateTime.now().toUtc().toIso8601String();
        final product = {
          'id': id,
          'name': item['name'],
          'sku': item['sku'],
          'barcode': item['barcode'],
          'selling_price': (item['sellingPrice'] as num?)?.toDouble() ?? 0,
          'cost_price': (item['costPrice'] as num?)?.toDouble() ?? 0,
          'unit': (item['unit'] as String?) ?? 'piece',
          'reorder_level': (item['reorderLevel'] as num?)?.toDouble() ?? 0,
          'tax_category': (item['taxCategory'] as String?) ?? 'vatable',
          'updated_at': now,
        };
        await txn.insert('products',
            {...product, 'quantity': 0, 'allow_negative_stock': 0});
        await txn.insert('sync_queue', {
          'operation_id': uuid.v4(),
          'type': 'product.create',
          'payload': jsonEncode(product),
          'created_at': now,
        });
        inserted++;
      }
    });
    return inserted;
  }

  Future<void> setProductArchived(String productId, bool archived) async {
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final rows = await txn.query('products',
          where: 'id = ?', whereArgs: [productId], limit: 1);
      if (rows.isEmpty) throw StateError('Product not found.');
      await txn.update(
          'products', {'archived_at': archived ? now : null, 'updated_at': now},
          where: 'id = ?', whereArgs: [productId]);
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': archived ? 'product.archive' : 'product.restore',
        'payload': jsonEncode({'id': productId, 'updated_at': now}),
        'created_at': now,
      });
    });
  }

  Future<void> updateProduct(
      {required String productId,
      required String name,
      required double sellingPrice,
      required String unit,
      String? sku,
      String? barcode,
      double reorderLevel = 0,
      double costPrice = 0,
      String taxCategory = 'vatable'}) async {
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    final product = {
      'id': productId,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'selling_price': sellingPrice,
      'cost_price': costPrice,
      'unit': unit,
      'reorder_level': reorderLevel,
      'tax_category': taxCategory,
      'updated_at': now,
    };
    await _database.transaction((txn) async {
      final rows = await txn.query('products',
          where: 'id = ?', whereArgs: [productId], limit: 1);
      if (rows.isEmpty) throw StateError('Product not found.');
      await txn
          .update('products', product, where: 'id = ?', whereArgs: [productId]);
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'product.update',
        'payload': jsonEncode(product),
        'created_at': now,
      });
    });
  }

  Future<void> deleteProduct(String productId) async {
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final rows = await txn.query('products',
          where: 'id = ?', whereArgs: [productId], limit: 1);
      if (rows.isEmpty) throw StateError('Product not found.');
      final product = rows.single;
      if (product['archived_at'] == null) {
        throw StateError('Archive this product before deleting it.');
      }
      if ((product['quantity'] as num).toDouble() != 0) {
        throw StateError(
            'This product still has stock. Adjust its quantity to zero and keep the stock history before deleting it.');
      }
      const references = [
        ('sale_items', 'completed sales'),
        ('refund_items', 'returns'),
        ('held_sale_items', 'held sales'),
        ('inventory_movements', 'inventory history'),
      ];
      for (final reference in references) {
        final result = await txn.rawQuery(
            'SELECT COUNT(*) AS reference_count FROM ${reference.$1} WHERE product_id = ?',
            [productId]);
        final count = (result.single['reference_count'] as num).toInt();
        if (count > 0) {
          throw StateError(
              'This product is referenced by ${reference.$2} and cannot be permanently deleted. Keep it archived to preserve business records.');
        }
      }
      await txn.delete('products', where: 'id = ?', whereArgs: [productId]);
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'product.delete',
        'payload': jsonEncode({'id': productId, 'updated_at': now}),
        'created_at': now,
      });
    });
  }

  Future<void> saveSale({
    required String receiptNumber,
    required List<Map<String, Object?>> items,
    required List<Map<String, Object?>> payments,
    String? receiptName,
    double discountAmount = 0,
    String? discountReason,
    Map<String, Object?>? credit,
  }) async {
    const uuid = Uuid();
    final saleId = uuid.v4();
    final grossAmount = items.fold<double>(
        0, (sum, item) => sum + (item['line_total'] as num).toDouble());
    if (discountAmount < 0 || discountAmount > grossAmount) {
      throw ArgumentError.value(
          discountAmount, 'discountAmount', 'must be within the sale total');
    }
    final netAmount = grossAmount - discountAmount;
    final paymentTotal = payments.fold<double>(
        0, (sum, payment) => sum + (payment['amount'] as num).toDouble());
    if ((paymentTotal - netAmount).abs() > .005) {
      throw ArgumentError('Payment total must match the sale total.');
    }
    final operationId = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final taxMode = await setting('tax_mode') ?? 'unregistered';
    final configuredVatRate =
        double.tryParse(await setting('vat_rate') ?? '') ?? .12;
    final tax = SaleTaxSummary.calculate(
        items: items,
        grossAmount: grossAmount,
        discountAmount: discountAmount,
        mode: taxMode,
        vatRate: configuredVatRate);
    final receiptProfile = <String, Object?>{
      'store_name': await setting('store_name') ?? '',
      'registered_name': await setting('registered_name') ?? '',
      'registered_address': await setting('registered_address') ?? '',
      'tin': await setting('tin') ?? '',
      'branch_code': await setting('branch_code') ?? '',
      'tax_mode': taxMode,
      'pos_permit_status':
          await setting('pos_permit_status') ?? 'not_permitted',
      'vat_rate': configuredVatRate,
      'permit_number': await setting('permit_number') ?? '',
      'machine_identification_number':
          await setting('machine_identification_number') ?? '',
      'logo_path': await setting('logo_path') ?? '',
    };
    Map<String, Object?>? creditPayload;
    if (credit != null) {
      final customerName = (credit['customer_name'] as String?)?.trim() ?? '';
      final amount = (credit['amount'] as num?)?.toDouble() ?? 0;
      if (customerName.isEmpty || amount <= 0 || amount > netAmount + .005) {
        throw ArgumentError('Valid customer and credit amount are required.');
      }
      creditPayload = {
        'id': uuid.v4(),
        'sale_id': saleId,
        'receipt_number': receiptNumber,
        'customer_name': customerName,
        'customer_contact': _trimmedOrNull(credit['customer_contact']),
        'original_amount': amount,
        'balance': amount,
        'status': 'unpaid',
        'due_at': credit['due_at'],
        'note': _trimmedOrNull(credit['note']),
        'created_at': now,
        'updated_at': now,
      };
    }
    await _database.transaction((txn) async {
      await txn.insert('sales', {
        'id': saleId,
        'receipt_number': receiptNumber,
        'gross_amount': grossAmount,
        'discount_amount': discountAmount,
        'discount_reason': discountReason,
        'receipt_name': receiptName,
        'net_amount': netAmount,
        'tax_mode': tax.mode,
        'vat_rate': tax.vatRate,
        'vatable_sales': tax.vatableSales,
        'vat_amount': tax.vatAmount,
        'vat_exempt_sales': tax.vatExemptSales,
        'zero_rated_sales': tax.zeroRatedSales,
        'receipt_profile': jsonEncode(receiptProfile),
        'occurred_at': now,
        'status': 'completed'
      });
      for (final item in items) {
        final product = await txn.query('products',
            where: 'id = ?', whereArgs: [item['product_id']], limit: 1);
        if (product.isEmpty) {
          throw StateError('One of the products is no longer available.');
        }
        final current = (product.single['quantity'] as num).toDouble();
        final quantity = (item['quantity'] as num).toDouble();
        if (current - quantity < 0 &&
            product.single['allow_negative_stock'] != 1) {
          throw StateError('Insufficient stock for ${product.single['name']}.');
        }
        await txn.insert('sale_items', {
          ...item,
          'id': uuid.v4(),
          'sale_id': saleId,
          'tax_category': item['tax_category'] ??
              product.single['tax_category'] ??
              'vatable'
        });
        await txn.rawUpdate(
            'UPDATE products SET quantity = quantity - ? WHERE id = ?',
            [quantity, item['product_id']]);
      }
      for (final payment in payments) {
        await txn.insert(
            'payments', {...payment, 'id': uuid.v4(), 'sale_id': saleId});
      }
      if (creditPayload != null) {
        await txn.insert('credits', creditPayload);
      }
      await txn.insert('sync_queue', {
        'operation_id': operationId,
        'type': 'sale.create',
        'payload': _salePayload(
            saleId,
            receiptNumber,
            grossAmount,
            netAmount,
            discountAmount,
            discountReason,
            receiptName,
            now,
            items,
            payments,
            creditPayload,
            tax,
            receiptProfile),
        'created_at': now,
      });
    });
  }

  String _salePayload(
      String saleId,
      String receiptNumber,
      double grossAmount,
      double netAmount,
      double discountAmount,
      String? discountReason,
      String? receiptName,
      String occurredAt,
      List<Map<String, Object?>> items,
      List<Map<String, Object?>> payments,
      Map<String, Object?>? credit,
      SaleTaxSummary tax,
      Map<String, Object?> receiptProfile) {
    // Encoding stays at the local boundary; UI code works with typed values only.
    return jsonEncode({
      'id': saleId,
      'receipt_number': receiptNumber,
      'gross_amount': grossAmount,
      'discount_amount': discountAmount,
      'discount_reason': discountReason,
      'receipt_name': receiptName,
      'net_amount': netAmount,
      'tax_mode': tax.mode,
      'vat_rate': tax.vatRate,
      'vatable_sales': tax.vatableSales,
      'vat_amount': tax.vatAmount,
      'vat_exempt_sales': tax.vatExemptSales,
      'zero_rated_sales': tax.zeroRatedSales,
      'receipt_profile': receiptProfile,
      'occurred_at': occurredAt,
      'items': items,
      'payments': payments,
      'credit': credit,
    });
  }

  Future<Map<String, num>> financeSummary() async {
    final creditRows = await _database.rawQuery('''
      SELECT
        COALESCE(SUM(original_amount), 0) AS total_credit,
        COALESCE(SUM(balance), 0) AS outstanding_credit,
        COALESCE(SUM(original_amount - balance), 0) AS collected_credit,
        COALESCE(SUM(CASE WHEN status = 'unpaid' THEN 1 ELSE 0 END), 0) AS open_credit_count
      FROM credits
    ''');
    final month = DateTime.now().toUtc().toIso8601String().substring(0, 7);
    final expenseRows = await _database.rawQuery('''
      SELECT
        COALESCE(SUM(amount), 0) AS total_expenses,
        COALESCE(SUM(CASE WHEN substr(expense_date, 1, 7) = ? THEN amount ELSE 0 END), 0) AS month_expenses
      FROM expenses
    ''', [month]);
    final credit = creditRows.single;
    final expense = expenseRows.single;
    return {
      'total_credit': (credit['total_credit'] as num?) ?? 0,
      'outstanding_credit': (credit['outstanding_credit'] as num?) ?? 0,
      'collected_credit': (credit['collected_credit'] as num?) ?? 0,
      'open_credit_count': (credit['open_credit_count'] as num?) ?? 0,
      'total_expenses': (expense['total_expenses'] as num?) ?? 0,
      'month_expenses': (expense['month_expenses'] as num?) ?? 0,
    };
  }

  Future<List<Map<String, Object?>>> credits(
      {String query = '',
      String status = 'all',
      int limit = 12,
      int offset = 0}) {
    final clauses = <String>[
      '(customer_name LIKE ? OR customer_contact LIKE ? OR receipt_number LIKE ?)'
    ];
    final args = <Object?>['%$query%', '%$query%', '%$query%'];
    if (status != 'all') {
      clauses.add('status = ?');
      args.add(status);
    }
    return _database.query('credits',
        where: clauses.join(' AND '),
        whereArgs: args,
        orderBy: "CASE status WHEN 'unpaid' THEN 0 ELSE 1 END, created_at DESC",
        limit: limit,
        offset: offset);
  }

  Future<int> creditCount({String query = '', String status = 'all'}) async {
    final clauses = <String>[
      '(customer_name LIKE ? OR customer_contact LIKE ? OR receipt_number LIKE ?)'
    ];
    final args = <Object?>['%$query%', '%$query%', '%$query%'];
    if (status != 'all') {
      clauses.add('status = ?');
      args.add(status);
    }
    final rows = await _database.rawQuery(
        'SELECT COUNT(*) AS total FROM credits WHERE ${clauses.join(' AND ')}',
        args);
    return (rows.single['total'] as num).toInt();
  }

  Future<List<Map<String, Object?>>> creditPayments(String creditId) =>
      _database.query('credit_payments',
          where: 'credit_id = ?',
          whereArgs: [creditId],
          orderBy: 'paid_at DESC');

  Future<void> createCredit({
    required String customerName,
    required double amount,
    String? customerContact,
    DateTime? dueAt,
    String? note,
  }) async {
    final name = customerName.trim();
    if (name.isEmpty || amount <= 0) {
      throw ArgumentError('Customer name and a positive amount are required.');
    }
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'id': uuid.v4(),
      'sale_id': null,
      'receipt_number': null,
      'customer_name': name,
      'customer_contact': _trimmedOrNull(customerContact),
      'original_amount': amount,
      'balance': amount,
      'status': 'unpaid',
      'due_at': dueAt?.toUtc().toIso8601String(),
      'note': _trimmedOrNull(note),
      'created_at': now,
      'updated_at': now,
    };
    await _database.transaction((txn) async {
      await txn.insert('credits', payload);
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'credit.create',
        'payload': jsonEncode(payload),
        'created_at': now,
      });
    });
  }

  Future<void> markCreditPaid(String creditId,
      {required String method, String? note}) async {
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final rows = await txn.query('credits',
          where: 'id = ?', whereArgs: [creditId], limit: 1);
      if (rows.isEmpty) throw StateError('Credit account not found.');
      final credit = rows.single;
      final balance = (credit['balance'] as num).toDouble();
      if (balance <= .005 || credit['status'] == 'paid') {
        throw StateError('This credit is already paid.');
      }
      final payment = <String, Object?>{
        'id': uuid.v4(),
        'credit_id': creditId,
        'amount': balance,
        'method': method,
        'note': _trimmedOrNull(note),
        'paid_at': now,
      };
      await txn.insert('credit_payments', payment);
      await txn.update('credits',
          {'balance': 0, 'status': 'paid', 'paid_at': now, 'updated_at': now},
          where: 'id = ?', whereArgs: [creditId]);
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'credit.payment',
        'payload': jsonEncode(payment),
        'created_at': now,
      });
      if (method == 'cash') {
        await _recordFinanceCashMovement(txn,
            uuid: uuid,
            type: 'cash_in',
            amount: balance,
            note: 'Credit payment - ${credit['customer_name']}',
            occurredAt: now);
      }
    });
  }

  Future<List<Map<String, Object?>>> expenses(
      {String query = '',
      String category = 'all',
      int limit = 12,
      int offset = 0}) {
    final clauses = <String>[
      '(description LIKE ? OR vendor LIKE ? OR note LIKE ?)'
    ];
    final args = <Object?>['%$query%', '%$query%', '%$query%'];
    if (category != 'all') {
      clauses.add('category = ?');
      args.add(category);
    }
    return _database.query('expenses',
        where: clauses.join(' AND '),
        whereArgs: args,
        orderBy: 'expense_date DESC, created_at DESC',
        limit: limit,
        offset: offset);
  }

  Future<int> expenseCount({String query = '', String category = 'all'}) async {
    final clauses = <String>[
      '(description LIKE ? OR vendor LIKE ? OR note LIKE ?)'
    ];
    final args = <Object?>['%$query%', '%$query%', '%$query%'];
    if (category != 'all') {
      clauses.add('category = ?');
      args.add(category);
    }
    final rows = await _database.rawQuery(
        'SELECT COUNT(*) AS total FROM expenses WHERE ${clauses.join(' AND ')}',
        args);
    return (rows.single['total'] as num).toInt();
  }

  Future<void> createExpense({
    required String category,
    required String description,
    required double amount,
    required String paymentMethod,
    required DateTime expenseDate,
    String? vendor,
    String? note,
  }) async {
    final cleanCategory = category.trim();
    final cleanDescription = description.trim();
    if (cleanCategory.isEmpty || cleanDescription.isEmpty || amount <= 0) {
      throw ArgumentError(
          'Category, description, and a positive amount are required.');
    }
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'id': uuid.v4(),
      'category': cleanCategory,
      'description': cleanDescription,
      'amount': amount,
      'payment_method': paymentMethod,
      'vendor': _trimmedOrNull(vendor),
      'expense_date': expenseDate.toUtc().toIso8601String(),
      'note': _trimmedOrNull(note),
      'created_at': now,
      'updated_at': now,
    };
    await _database.transaction((txn) async {
      await txn.insert('expenses', payload);
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'expense.create',
        'payload': jsonEncode(payload),
        'created_at': now,
      });
      if (paymentMethod == 'cash') {
        await _recordFinanceCashMovement(txn,
            uuid: uuid,
            type: 'cash_out',
            amount: amount,
            note: 'Expense - $cleanDescription',
            occurredAt: now);
      }
    });
  }

  Future<void> _recordFinanceCashMovement(DatabaseExecutor txn,
      {required Uuid uuid,
      required String type,
      required double amount,
      required String note,
      required String occurredAt}) async {
    final shifts = await txn.query('register_shifts',
        where: 'status = ?',
        whereArgs: ['open'],
        orderBy: 'opened_at DESC',
        limit: 1);
    if (shifts.isEmpty) return;
    final payload = <String, Object?>{
      'id': uuid.v4(),
      'shift_id': shifts.single['id'],
      'type': type,
      'amount': amount,
      'note': note,
      'occurred_at': occurredAt,
    };
    await txn.insert('cash_movements', payload);
    await txn.insert('sync_queue', {
      'operation_id': uuid.v4(),
      'type': 'register.cash_movement',
      'payload': jsonEncode(payload),
      'created_at': occurredAt,
    });
  }

  static String? _trimmedOrNull(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<List<Map<String, Object?>>> pendingOperations() =>
      _database.query('sync_queue',
          where: 'status = ?', whereArgs: ['pending'], orderBy: 'created_at');

  Future<Map<String, num>> syncSummary() async {
    final rows = await _database.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN status = 'pending' AND last_error IS NULL THEN 1 ELSE 0 END), 0) AS pending_count,
        COALESCE(SUM(CASE WHEN status = 'pending' AND last_error IS NOT NULL THEN 1 ELSE 0 END), 0) AS failed_count,
        COALESCE(SUM(CASE WHEN status = 'synced' THEN 1 ELSE 0 END), 0) AS synced_count
      FROM sync_queue
    ''');
    final row = rows.single;
    return {
      'pending_count': (row['pending_count'] as num?) ?? 0,
      'failed_count': (row['failed_count'] as num?) ?? 0,
      'synced_count': (row['synced_count'] as num?) ?? 0,
    };
  }

  Future<List<Map<String, Object?>>> syncIssues() => _database.query(
        'sync_queue',
        where: 'status = ? AND last_error IS NOT NULL',
        whereArgs: ['pending'],
        orderBy: 'created_at DESC',
        limit: 5,
      );

  Future<void> adjustInventory(
      {required String branchId,
      required String productId,
      required double quantityDelta,
      required String reason,
      String? note}) async {
    if (quantityDelta == 0) {
      throw ArgumentError.value(
          quantityDelta, 'quantityDelta', 'must not be zero');
    }
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final product = await txn.query('products',
          where: 'id = ?', whereArgs: [productId], limit: 1);
      if (product.isEmpty) {
        throw StateError('Product is not available on this device.');
      }
      final current = (product.single['quantity'] as num).toDouble();
      final allowsNegative = product.single['allow_negative_stock'] == 1;
      if (current + quantityDelta < 0 && !allowsNegative) {
        throw StateError('This adjustment would make stock negative.');
      }
      await txn.update(
          'products', {'quantity': current + quantityDelta, 'updated_at': now},
          where: 'id = ?', whereArgs: [productId]);
      await txn.insert('inventory_movements', {
        'id': uuid.v4(),
        'product_id': productId,
        'quantity_delta': quantityDelta,
        'reason': reason,
        'note': note,
        'occurred_at': now
      });
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'inventory.adjust',
        'payload': jsonEncode({
          'branch_id': branchId,
          'product_id': productId,
          'quantity_delta': quantityDelta,
          'reason': reason,
          'note': note
        }),
        'created_at': now,
      });
    });
  }

  Future<void> receiveInventory(
      {required String branchId,
      required String productId,
      required double quantity,
      double unitCost = 0,
      String? reference,
      String? note}) async {
    if (quantity <= 0) {
      throw ArgumentError.value(
          quantity, 'quantity', 'must be greater than zero');
    }
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final product = await txn.query('products',
          where: 'id = ?', whereArgs: [productId], limit: 1);
      if (product.isEmpty) {
        throw StateError('Product is not available on this device.');
      }
      final current = (product.single['quantity'] as num).toDouble();
      await txn.update(
          'products',
          {
            'quantity': current + quantity,
            if (unitCost > 0) 'cost_price': unitCost,
            'updated_at': now
          },
          where: 'id = ?',
          whereArgs: [productId]);
      await txn.insert('inventory_movements', {
        'id': uuid.v4(),
        'product_id': productId,
        'quantity_delta': quantity,
        'reason': 'receive',
        'note': note,
        'occurred_at': now
      });
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'inventory.receive',
        'payload': jsonEncode({
          'branch_id': branchId,
          'reference': reference,
          'note': note,
          'received_at': now,
          'items': [
            {
              'product_id': productId,
              'quantity': quantity,
              'unit_cost': unitCost
            }
          ],
        }),
        'created_at': now,
      });
    });
  }

  Future<void> countInventory(
      {required String branchId,
      required String productId,
      required double countedQuantity,
      String? reference,
      String? note}) async {
    if (countedQuantity < 0) {
      throw ArgumentError.value(
          countedQuantity, 'countedQuantity', 'must not be negative');
    }
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final product = await txn.query('products',
          where: 'id = ?', whereArgs: [productId], limit: 1);
      if (product.isEmpty) {
        throw StateError('Product is not available on this device.');
      }
      final expected = (product.single['quantity'] as num).toDouble();
      final delta = countedQuantity - expected;
      await txn.update(
          'products', {'quantity': countedQuantity, 'updated_at': now},
          where: 'id = ?', whereArgs: [productId]);
      await txn.insert('inventory_movements', {
        'id': uuid.v4(),
        'product_id': productId,
        'quantity_delta': delta,
        'reason': 'stock_count',
        'note': note,
        'occurred_at': now
      });
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'inventory.count',
        'payload': jsonEncode({
          'branch_id': branchId,
          'reference': reference,
          'note': note,
          'counted_at': now,
          'items': [
            {'product_id': productId, 'counted_quantity': countedQuantity}
          ],
        }),
        'created_at': now,
      });
    });
  }

  Future<List<Map<String, Object?>>> inventoryMovements({String? productId}) =>
      _database.rawQuery('''
    SELECT inventory_movements.*, products.name AS product_name, products.unit AS product_unit
    FROM inventory_movements
    INNER JOIN products ON products.id = inventory_movements.product_id
    ${productId == null ? '' : 'WHERE inventory_movements.product_id = ?'}
    ORDER BY inventory_movements.occurred_at DESC
  ''', productId == null ? null : [productId]);

  Future<void> markOperationsSynced(Iterable<String> operationIds) async {
    final ids = operationIds.toList();
    if (ids.isEmpty) return;
    await _database.update(
      'sync_queue',
      {
        'status': 'synced',
        'synced_at': DateTime.now().toUtc().toIso8601String(),
        'last_error': null
      },
      where: 'operation_id IN (${List.filled(ids.length, '?').join(', ')})',
      whereArgs: ids,
    );
  }

  Future<void> recordSyncFailure(
      Iterable<String> operationIds, String error) async {
    final ids = operationIds.toList();
    if (ids.isEmpty) return;
    await _database.rawUpdate(
      'UPDATE sync_queue SET attempts = attempts + 1, last_error = ? WHERE operation_id IN (${List.filled(ids.length, '?').join(', ')})',
      [error, ...ids],
    );
  }

  Future<void> recordSyncFailures(Map<String, String> errors) async {
    if (errors.isEmpty) return;
    await _database.transaction((txn) async {
      for (final entry in errors.entries) {
        await txn.rawUpdate(
            'UPDATE sync_queue SET attempts = attempts + 1, last_error = ? WHERE operation_id = ?',
            [entry.value, entry.key]);
      }
    });
  }

  // Business identity settings that sync across devices. Device-local settings
  // (server URL, token, device id, the local logo *path*) are excluded, but the
  // logo *image* itself ('logo_image', base64) does sync.
  static const _syncedSettingKeys = {
    'store_name',
    'registered_name',
    'registered_address',
    'tin',
    'branch_code',
    'tax_mode',
    'pos_permit_status',
    'vat_rate',
    'permit_number',
    'machine_identification_number',
    'logo_image',
  };

  Future<void> saveSetting(String key, String value) async {
    await _database.insert('app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
    if (_syncedSettingKeys.contains(key)) {
      const uuid = Uuid();
      final now = DateTime.now().toUtc().toIso8601String();
      await _database.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'settings.update',
        'payload': jsonEncode({'key': key, 'value': value, 'updated_at': now}),
        'created_at': now,
      });
    }
  }

  Future<String?> setting(String key) async {
    final rows = await _database.query('app_settings',
        columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  static String _hashPassword(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  /// Remembers a user's credentials after a successful online sign-in so they
  /// can be verified locally when the server is later unreachable. Only a
  /// salted hash of the password is stored, never the password itself.
  Future<void> cacheCredential({
    required String username,
    required String password,
    required String userName,
    required String userRole,
    required String branchId,
    required String token,
  }) async {
    final rng = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final salt = base64Url.encode(saltBytes);
    await _database.insert(
      'cached_credentials',
      {
        'username': username.toLowerCase(),
        'password_salt': salt,
        'password_hash': _hashPassword(password, salt),
        'user_name': userName,
        'user_role': userRole,
        'branch_id': branchId,
        'token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Verifies [username]/[password] against the locally cached credential.
  /// Returns the stored session fields (user_name, user_role, branch_id,
  /// token) when the password matches, or null when there is no cached user
  /// or the password is wrong.
  Future<Map<String, String>?> verifyCachedCredential(
      String username, String password) async {
    final rows = await _database.query('cached_credentials',
        where: 'username = ?',
        whereArgs: [username.toLowerCase()],
        limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.single;
    final salt = row['password_salt'] as String;
    final expected = row['password_hash'] as String;
    if (_hashPassword(password, salt) != expected) return null;
    return {
      'user_name': row['user_name'] as String,
      'user_role': row['user_role'] as String,
      'branch_id': row['branch_id'] as String,
      'token': row['token'] as String,
    };
  }

  // --- Offline staff management -------------------------------------------

  /// Replaces the local staff mirror with the list just fetched from the
  /// server, so it can be shown when the device is later offline.
  Future<void> cacheStaffUsers(List<Map<String, dynamic>> users) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      await txn.delete('staff_users');
      for (final user in users) {
        // Insert raw values (no String casts) so a numeric id/field from the
        // server doesn't crash; the TEXT columns coerce them to text.
        await txn.insert('staff_users', {
          'id': user['id']?.toString(),
          'name': user['name']?.toString() ?? '',
          'email': user['email']?.toString(),
          'username': user['username']?.toString(),
          'role': user['role']?.toString() ?? '',
          'deactivated_at': user['deactivated_at']?.toString(),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// The locally cached staff list, ordered by name. Used offline.
  Future<List<Map<String, dynamic>>> cachedStaffUsers() async {
    final rows = await _database.query('staff_users', orderBy: 'name COLLATE NOCASE');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Caches the last-fetched audit log so it can be shown read-only offline.
  Future<void> cacheAuditLogs(List<Map<String, dynamic>> logs) async {
    await saveSetting('audit_logs_cache', jsonEncode(logs));
  }

  Future<List<Map<String, dynamic>>> cachedAuditLogs() async {
    final raw = await setting('audit_logs_cache');
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Number of staff changes waiting to sync to the server.
  Future<int> pendingStaffSyncCount() async {
    final result = await _database.rawQuery(
        "SELECT COUNT(*) AS c FROM sync_queue WHERE type LIKE 'user.%' AND status = 'pending'");
    return (result.single['c'] as num).toInt();
  }

  /// Creates a staff member locally and queues the change for the server.
  /// Returns the new user's row as it should appear in the UI.
  Future<Map<String, dynamic>> createStaffUserOffline({
    required String name,
    required String email,
    required String username,
    required String password,
    required String role,
  }) async {
    const uuid = Uuid();
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final user = {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
      'role': role,
      'deactivated_at': null,
      'updated_at': now,
    };
    await _database.transaction((txn) async {
      await txn.insert('staff_users', user,
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'user.create',
        'payload': jsonEncode({
          'id': id,
          'name': name,
          'email': email,
          'username': username,
          'password': password,
          'role': role,
          'created_at': now,
        }),
        'created_at': now,
      });
    });
    return user;
  }

  /// Updates a staff member locally and queues the change for the server.
  Future<void> updateStaffUserOffline({
    required String id,
    required String name,
    required String email,
    required String username,
    String? password,
    required String role,
  }) async {
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final rows = await txn
          .query('staff_users', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw StateError('Staff member not found.');
      await txn.update(
          'staff_users',
          {
            'name': name,
            'email': email,
            'username': username,
            'role': role,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [id]);
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': 'user.update',
        'payload': jsonEncode({
          'id': id,
          'name': name,
          'email': email,
          'username': username,
          if (password != null && password.isNotEmpty) 'password': password,
          'role': role,
          'updated_at': now,
        }),
        'created_at': now,
      });
    });
  }

  /// Activates or deactivates a staff member locally and queues the change.
  Future<void> setStaffUserActiveOffline(String id, bool active) async {
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final rows = await txn
          .query('staff_users', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw StateError('Staff member not found.');
      await txn.update('staff_users', {'deactivated_at': active ? null : now},
          where: 'id = ?', whereArgs: [id]);
      await txn.insert('sync_queue', {
        'operation_id': uuid.v4(),
        'type': active ? 'user.reactivate' : 'user.deactivate',
        'payload': jsonEncode({'id': id, 'updated_at': now}),
        'created_at': now,
      });
    });
  }

  Future<void> applyServerSnapshot(Map<String, dynamic> snapshot) async {
    final products = (snapshot['products'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final inventory = (snapshot['inventory'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final barcodes = (snapshot['barcodes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final credits = (snapshot['credits'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final creditPayments = (snapshot['credit_payments'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final expenses = (snapshot['expenses'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final registerShifts = (snapshot['register_shifts'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final cashMovements = (snapshot['cash_movements'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final settings = (snapshot['settings'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    // Staff list, when the server includes it in the pull. Absent on older
    // backends, in which case the local mirror is left untouched.
    final users = (snapshot['users'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final inventoryByProduct = <String, num>{
      for (final item in inventory)
        item['product_id'] as String: item['quantity'] as num,
    };
    final barcodeByProduct = <String, String>{};
    for (final item in barcodes) {
      barcodeByProduct.putIfAbsent(
          item['product_id'] as String, () => item['code'] as String);
    }
    await _database.transaction((txn) async {
      for (final product in products) {
        final id = product['id'] as String;
        await txn.insert(
            'products',
            {
              'id': id,
              'sku': product['sku'],
              'barcode': barcodeByProduct[id],
              'name': product['name'],
              'selling_price': product['selling_price'],
              'cost_price': product['cost_price'] ?? 0,
              'unit': product['unit'] ?? 'piece',
              'quantity': inventoryByProduct[id] ?? 0,
              'reorder_level': product['reorder_level'] ?? 0,
              'allow_negative_stock': product['allow_negative_stock'] == true ||
                      product['allow_negative_stock'] == 1
                  ? 1
                  : 0,
              'archived_at': product['deleted_at'],
              'updated_at': product['updated_at'] ??
                  DateTime.now().toUtc().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final item in inventory) {
        await txn.update('products', {'quantity': item['quantity'] ?? 0},
            where: 'id = ?', whereArgs: [item['product_id']]);
      }
      for (final credit in credits) {
        await txn.insert(
            'credits',
            {
              'id': credit['id'],
              'sale_id': credit['sale_id'],
              'receipt_number': credit['receipt_number'],
              'customer_name': credit['customer_name'],
              'customer_contact': credit['customer_contact'],
              'original_amount': credit['original_amount'],
              'balance': credit['balance'],
              'status': credit['status'],
              'due_at': credit['due_at'],
              'note': credit['note'],
              'created_at': credit['created_at'],
              'updated_at': credit['updated_at'],
              'paid_at': credit['paid_at'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final payment in creditPayments) {
        await txn.insert(
            'credit_payments',
            {
              'id': payment['id'],
              'credit_id': payment['credit_id'],
              'amount': payment['amount'],
              'method': payment['method'],
              'note': payment['note'],
              'paid_at': payment['paid_at'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final expense in expenses) {
        await txn.insert(
            'expenses',
            {
              'id': expense['id'],
              'category': expense['category'],
              'description': expense['description'],
              'amount': expense['amount'],
              'payment_method': expense['payment_method'],
              'vendor': expense['vendor'],
              'expense_date': expense['expense_date'],
              'note': expense['note'],
              'created_at': expense['created_at'],
              'updated_at': expense['updated_at'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Closed register shifts synced from other devices (history/audit).
      for (final shift in registerShifts) {
        await txn.insert(
            'register_shifts',
            {
              'id': shift['id'],
              'opening_cash': shift['opening_cash'],
              'status': shift['status'],
              'opened_at': shift['opened_at'],
              'closed_at': shift['closed_at'],
              'expected_cash': shift['expected_cash'],
              'actual_cash': shift['actual_cash'],
              'variance': shift['variance'],
              'note': shift['note'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final movement in cashMovements) {
        await txn.insert(
            'cash_movements',
            {
              'id': movement['id'],
              'shift_id': movement['register_shift_id'],
              'type': movement['type'],
              'amount': movement['amount'],
              'note': movement['note'],
              'occurred_at': movement['occurred_at'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Store/invoice identity settings synced from other devices.
      for (final setting in settings) {
        await txn.insert(
            'app_settings',
            {'key': setting['key'], 'value': setting['value']},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Refresh the offline staff mirror so admins can manage staff without a
      // connection. Only when the server actually sent the list.
      if (users.isNotEmpty) {
        await txn.delete('staff_users');
        final now = DateTime.now().toUtc().toIso8601String();
        for (final user in users) {
          await txn.insert(
              'staff_users',
              {
                'id': user['id']?.toString(),
                'name': user['name']?.toString() ?? '',
                'email': user['email']?.toString(),
                'username': user['username']?.toString(),
                'role': user['role']?.toString() ?? '',
                'deactivated_at': user['deactivated_at']?.toString(),
                'updated_at': user['updated_at']?.toString() ?? now,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
