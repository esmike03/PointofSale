import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// An in-memory database with the app's schema, for widget/layout tests.
Future<Database> openTestDatabase() async {
  sqfliteFfiInit();
  final database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await database.execute('''CREATE TABLE held_sales (
    id TEXT PRIMARY KEY, label TEXT NOT NULL, discount_amount REAL NOT NULL DEFAULT 0,
    discount_reason TEXT, created_at TEXT NOT NULL
  )''');
  await database.execute('''CREATE TABLE held_sale_items (
    id TEXT PRIMARY KEY, held_sale_id TEXT NOT NULL, product_id TEXT NOT NULL,
    product_name TEXT NOT NULL, quantity REAL NOT NULL, unit_price REAL NOT NULL,
    line_total REAL NOT NULL, tax_category TEXT NOT NULL DEFAULT 'vatable'
  )''');
  await database.execute('''CREATE TABLE products (
    id TEXT PRIMARY KEY, sku TEXT, barcode TEXT, name TEXT NOT NULL,
    selling_price REAL NOT NULL DEFAULT 0, cost_price REAL NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'piece', quantity REAL NOT NULL,
    reorder_level REAL NOT NULL DEFAULT 0, allow_negative_stock INTEGER NOT NULL DEFAULT 0,
    tax_category TEXT NOT NULL DEFAULT 'vatable', archived_at TEXT, updated_at TEXT
  )''');
  await database.execute('''CREATE TABLE sales (
    id TEXT PRIMARY KEY, receipt_number TEXT NOT NULL, gross_amount REAL NOT NULL,
    discount_amount REAL NOT NULL DEFAULT 0, discount_reason TEXT, receipt_name TEXT,
    net_amount REAL NOT NULL,
    tax_mode TEXT NOT NULL DEFAULT 'unregistered', vat_rate REAL NOT NULL DEFAULT 0,
    vatable_sales REAL NOT NULL DEFAULT 0, vat_amount REAL NOT NULL DEFAULT 0,
    vat_exempt_sales REAL NOT NULL DEFAULT 0, zero_rated_sales REAL NOT NULL DEFAULT 0,
    receipt_profile TEXT,
    occurred_at TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'completed'
  )''');
  await database.execute('''CREATE TABLE sale_items (
    id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, product_id TEXT NOT NULL,
    product_name TEXT NOT NULL, quantity REAL NOT NULL, unit_price REAL NOT NULL,
    discount_amount REAL NOT NULL DEFAULT 0, line_total REAL NOT NULL,
    tax_category TEXT NOT NULL DEFAULT 'vatable'
  )''');
  await database.execute('''CREATE TABLE payments (
    id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, method TEXT NOT NULL,
    amount REAL NOT NULL, reference TEXT
  )''');
  await database.execute('''CREATE TABLE refunds (
    id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, refund_number TEXT NOT NULL,
    amount REAL NOT NULL, method TEXT NOT NULL, reason TEXT NOT NULL,
    occurred_at TEXT NOT NULL
  )''');
  await database.execute('''CREATE TABLE refund_items (
    id TEXT PRIMARY KEY, refund_id TEXT NOT NULL, sale_item_id TEXT NOT NULL,
    product_id TEXT NOT NULL, product_name TEXT NOT NULL, quantity REAL NOT NULL,
    unit_price REAL NOT NULL, amount REAL NOT NULL
  )''');
  await database.execute('''CREATE TABLE inventory_movements (
    id TEXT PRIMARY KEY, product_id TEXT NOT NULL, quantity_delta REAL NOT NULL,
    reason TEXT NOT NULL, note TEXT, occurred_at TEXT NOT NULL
  )''');
  await database.execute('''CREATE TABLE sync_queue (
    operation_id TEXT PRIMARY KEY, type TEXT NOT NULL, payload TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0,
    last_error TEXT, created_at TEXT NOT NULL, synced_at TEXT
  )''');
  await database.execute('''CREATE TABLE app_settings (
    key TEXT PRIMARY KEY, value TEXT NOT NULL
  )''');
  await database.execute('''CREATE TABLE local_users (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT,
    username TEXT NOT NULL COLLATE NOCASE UNIQUE,
    password_salt TEXT NOT NULL, password_hash TEXT NOT NULL,
    role TEXT NOT NULL, deactivated_at TEXT,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL
  )''');
  await database.execute('''CREATE TABLE register_shifts (
    id TEXT PRIMARY KEY, opening_cash REAL NOT NULL, status TEXT NOT NULL,
    opened_at TEXT NOT NULL, closed_at TEXT, expected_cash REAL,
    actual_cash REAL, variance REAL, note TEXT
  )''');
  await database.execute('''CREATE TABLE cash_movements (
    id TEXT PRIMARY KEY, shift_id TEXT NOT NULL, type TEXT NOT NULL,
    amount REAL NOT NULL, note TEXT, occurred_at TEXT NOT NULL
  )''');
  await database.execute('''CREATE TABLE credits (
    id TEXT PRIMARY KEY, sale_id TEXT, receipt_number TEXT,
    customer_name TEXT NOT NULL, customer_contact TEXT,
    original_amount REAL NOT NULL, balance REAL NOT NULL,
    status TEXT NOT NULL DEFAULT 'unpaid', due_at TEXT, note TEXT,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL, paid_at TEXT
  )''');
  await database.execute('''CREATE TABLE credit_payments (
    id TEXT PRIMARY KEY, credit_id TEXT NOT NULL, amount REAL NOT NULL,
    method TEXT NOT NULL, note TEXT, paid_at TEXT NOT NULL
  )''');
  await database.execute('''CREATE TABLE expenses (
    id TEXT PRIMARY KEY, category TEXT NOT NULL, description TEXT NOT NULL,
    amount REAL NOT NULL, payment_method TEXT NOT NULL, vendor TEXT,
    expense_date TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''');
  return database;
}
