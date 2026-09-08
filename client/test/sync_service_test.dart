import 'dart:convert';

import 'package:chirpy_pos/data/local/local_database.dart';
import 'package:chirpy_pos/data/remote/api_client.dart';
import 'package:chirpy_pos/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

/// Covers the ways a push to the server can go wrong. These paths used to sign
/// the cashier out or wedge the queue permanently.
void main() {
  late Database rawDatabase;
  late LocalDatabase database;

  setUp(() async {
    rawDatabase = await openTestDatabase();
    database = LocalDatabase(rawDatabase);
  });

  tearDown(() => rawDatabase.close());

  Future<void> queue(int count) async {
    for (var i = 0; i < count; i++) {
      await rawDatabase.insert('sync_queue', {
        'operation_id': 'op-${i.toString().padLeft(4, '0')}',
        'type': 'sale.create',
        'payload': jsonEncode({'id': 'sale-$i'}),
        'created_at': DateTime.utc(2026, 1, 1)
            .add(Duration(seconds: i))
            .toIso8601String(),
      });
    }
  }

  /// Answers every push with "processed" for whatever it was sent.
  String acceptAll(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final operations =
        (body['operations'] as List<dynamic>).cast<Map<String, dynamic>>();
    return jsonEncode({
      'results': [
        for (final operation in operations)
          {'operation_id': operation['operation_id'], 'status': 'processed'},
      ],
    });
  }

  SyncService serviceWith(MockClient client) => SyncService(
      database,
      Uri.parse('http://server.test'),
      'token-123',
      '11111111-2222-3333-4444-555555555555',
      httpClient: client);

  test('drains more than one server batch instead of being rejected', () async {
    await queue(1150);
    final batchSizes = <int>[];
    final progress = <(int, int)>[];
    final activities = <SyncActivity>[];
    final service = serviceWith(MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      batchSizes.add((body['operations'] as List<dynamic>).length);
      return http.Response(acceptAll(request), 200);
    }));

    await service.pushPending(
      onProgress: (done, total) => progress.add((done, total)),
      onActivity: activities.add,
    );

    // The server rejects any request carrying more than 500 operations.
    expect(batchSizes, [500, 500, 150]);
    expect(await database.pendingOperations(), isEmpty);
    expect((await database.syncSummary())['synced_count'], 1150);
    // The drain has to be observable, or a big queue looks like a hang.
    expect(progress, [(0, 1150), (500, 1150), (1000, 1150), (1150, 1150)]);
    expect(activities.first.phase, 'Sending changes');
    expect(activities.first.total, 1150);
    expect(activities.last.done, 1150);
    expect(activities.last.currentItem, 'Sale Create - sale-1149');
  });

  test('pulls only what changed since the last successful sync', () async {
    final requested = <String?>[];
    final service = serviceWith(MockClient((request) async {
      if (request.url.path == '/api/sync/pull') {
        requested.add(request.url.queryParameters['since']);
        return http.Response(
            jsonEncode({'server_time': '2026-08-07T12:00:00+00:00'}), 200);
      }
      return http.Response(acceptAll(request), 200);
    }));

    // First sync has no watermark, so the server picks its own window.
    await service.synchronize();
    expect(requested, [null]);
    expect(
        await database.setting('sync_watermark'), '2026-08-07T12:00:00+00:00');

    // The next one asks only for changes after the server's own timestamp,
    // rather than re-downloading a 30-day window of the whole catalog.
    await service.synchronize();
    expect(requested, [null, '2026-08-07T12:00:00+00:00']);
  });

  test('keeps the old watermark when applying the snapshot fails', () async {
    await database.saveSetting('sync_watermark', '2026-08-01T00:00:00+00:00');
    final service = serviceWith(MockClient((request) async {
      if (request.url.path == '/api/sync/pull') {
        return http.Response(jsonEncode({'server_time': 'later'}), 500);
      }
      return http.Response(acceptAll(request), 200);
    }));

    await expectLater(service.synchronize(), throwsA(isA<ApiException>()));

    // Advancing past records that were never applied would lose them for good.
    expect(
        await database.setting('sync_watermark'), '2026-08-01T00:00:00+00:00');
  });

  test('registers an unknown device and retries the push', () async {
    await queue(1);
    await database.saveSetting('device_name', 'Counter 1');
    await database.saveSetting('branch_id', 'local');
    final paths = <String>[];
    var pushes = 0;
    final service = serviceWith(MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path == '/api/devices/register') {
        return http.Response(jsonEncode({'id': 'device'}), 200);
      }
      pushes++;
      if (pushes == 1) {
        return http.Response(
            jsonEncode(
                {'message': 'Register this device before synchronizing.'}),
            422);
      }
      return http.Response(acceptAll(request), 200);
    }));

    await service.pushPending();

    expect(paths, [
      '/api/sync/push',
      '/api/devices/register',
      '/api/sync/push',
    ]);
    expect(await database.pendingOperations(), isEmpty);
  });

  test('a dead token surfaces as unauthenticated without touching the queue',
      () async {
    await queue(3);
    final service = serviceWith(MockClient((request) async =>
        http.Response(jsonEncode({'message': 'Unauthenticated.'}), 401)));

    await expectLater(
      service.pushPending(),
      throwsA(isA<ApiException>().having(
          (error) => error.isUnauthenticated, 'isUnauthenticated', isTrue)),
    );

    // The operations are fine — the session is not. Flagging them would tell
    // the cashier their sales are broken when they are merely waiting.
    final summary = await database.syncSummary();
    expect(summary['pending_count'], 3);
    expect(summary['failed_count'], 0);
    expect(await database.setting('last_sync_error'), isNotNull);
  });

  test('an operation the server rejects is counted against that operation only',
      () async {
    await queue(2);
    final service = serviceWith(MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final operations =
          (body['operations'] as List<dynamic>).cast<Map<String, dynamic>>();
      return http.Response(
          jsonEncode({
            'results': [
              {
                'operation_id': operations.first['operation_id'],
                'status': 'processed'
              },
              {
                'operation_id': operations.last['operation_id'],
                'status': 'failed',
                'error': 'Unsupported operation type.'
              },
            ],
          }),
          200);
    }));

    await service.pushPending();

    final summary = await database.syncSummary();
    expect(summary['synced_count'], 1);
    expect(summary['failed_count'], 1);
    final issue = (await database.syncIssues()).single;
    expect(issue['attempts'], 1);
    expect(issue['last_error'], 'Unsupported operation type.');
  });

  test('a batch the server rejects entirely does not loop forever', () async {
    await queue(4);
    var pushes = 0;
    final service = serviceWith(MockClient((request) async {
      pushes++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final operations =
          (body['operations'] as List<dynamic>).cast<Map<String, dynamic>>();
      return http.Response(
          jsonEncode({
            'results': [
              for (final operation in operations)
                {
                  'operation_id': operation['operation_id'],
                  'status': 'failed',
                  'error': 'Unsupported operation type.'
                },
            ],
          }),
          200);
    }));

    await service.pushPending();

    expect(pushes, 1);
    expect((await database.syncSummary())['failed_count'], 4);
  });

  test('business data sync does not send queued product catalog operations',
      () async {
    await rawDatabase.insert('sync_queue', {
      'operation_id': 'product-op',
      'type': 'product.create',
      'payload': jsonEncode({'id': 'product-1'}),
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });
    await rawDatabase.insert('sync_queue', {
      'operation_id': 'sale-op',
      'type': 'sale.create',
      'payload': jsonEncode({'id': 'sale-1'}),
      'created_at': DateTime.utc(2026, 1, 2).toIso8601String(),
    });
    final sentTypes = <String>[];
    final service = serviceWith(MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final operations =
          (body['operations'] as List<dynamic>).cast<Map<String, dynamic>>();
      sentTypes.addAll(operations.map((item) => item['type'] as String));
      return http.Response(acceptAll(request), 200);
    }));

    await service.pushPending(scope: SyncQueueScope.businessData);

    expect(sentTypes, ['sale.create']);
    expect(
        await database.pendingOperationCount(
            scope: SyncQueueScope.businessData),
        0);
    expect(await database.pendingOperationCount(scope: SyncQueueScope.products),
        1);
  });

  test('a rejected product batch does not hide later catalog rows', () async {
    for (var i = 0; i < 501; i++) {
      await rawDatabase.insert('sync_queue', {
        'operation_id': 'product-$i',
        'type': 'product.create',
        'payload': jsonEncode({'id': 'product-$i'}),
        'created_at': DateTime.utc(2026, 1, 1)
            .add(Duration(seconds: i))
            .toIso8601String(),
      });
    }
    final batchSizes = <int>[];
    var requestNumber = 0;
    final service = serviceWith(MockClient((request) async {
      requestNumber++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final operations =
          (body['operations'] as List<dynamic>).cast<Map<String, dynamic>>();
      batchSizes.add(operations.length);
      return http.Response(
          jsonEncode({
            'results': [
              for (final operation in operations)
                {
                  'operation_id': operation['operation_id'],
                  'status': requestNumber == 1 ? 'failed' : 'processed',
                  if (requestNumber == 1) 'error': 'Duplicate barcode.',
                },
            ],
          }),
          200);
    }));

    await service.pushPending(scope: SyncQueueScope.products);

    expect(batchSizes, [500, 1]);
    final summary = await database.syncSummary(scope: SyncQueueScope.products);
    expect(summary['synced_count'], 1);
    expect(summary['failed_count'], 500);
    final issue =
        (await database.syncIssues(scope: SyncQueueScope.products)).single;
    expect(issue['affected_count'], 500);
    expect(issue['last_error'], 'Duplicate barcode.');
  });

  test('product and business pulls keep independent watermarks', () async {
    final scopes = <String?>[];
    final service = serviceWith(MockClient((request) async {
      if (request.url.path == '/api/sync/pull') {
        final scope = request.url.queryParameters['scope'];
        scopes.add(scope);
        return http.Response(
            jsonEncode({
              'server_time': scope == 'products'
                  ? '2026-08-08T02:00:00+00:00'
                  : '2026-08-08T01:00:00+00:00',
              'has_more': false,
            }),
            200);
      }
      return http.Response(acceptAll(request), 200);
    }));

    await service.synchronize(scope: SyncQueueScope.businessData);
    await service.synchronize(scope: SyncQueueScope.products);

    expect(scopes, ['business_data', 'products']);
    expect(await database.setting('sync_watermark_business_data'),
        '2026-08-08T01:00:00+00:00');
    expect(await database.setting('sync_watermark_products'),
        '2026-08-08T02:00:00+00:00');
  });

  test('product pull reports the received count and current product', () async {
    final activities = <SyncActivity>[];
    final service = serviceWith(MockClient((request) async {
      if (request.url.path == '/api/sync/pull') {
        return http.Response(
            jsonEncode({
              'server_time': '2026-08-08T03:00:00+00:00',
              'has_more': false,
              'products': [
                {
                  'id': 'server-product',
                  'name': 'Server Coffee',
                  'selling_price': 100,
                  'cost_price': 50,
                  'unit': 'piece',
                  'updated_at': '2026-08-08T02:59:00+00:00',
                }
              ],
            }),
            200);
      }
      return http.Response(acceptAll(request), 200);
    }));

    await service.synchronize(
      scope: SyncQueueScope.products,
      onActivity: activities.add,
    );

    final receiving =
        activities.lastWhere((activity) => activity.currentItem != null);
    expect(receiving.phase, 'Receiving products');
    expect(receiving.done, 1);
    expect(receiving.currentItem, 'Server Coffee');
    expect(activities.last.phase, 'Finalizing sync');
  });
}
