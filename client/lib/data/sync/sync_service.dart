import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../logo_sync.dart';
import '../local/local_database.dart';
import '../remote/api_client.dart';

/// Reports how far a queue drain has got. A device returning from a long spell
/// offline can have six figures of queued work, which must not look like a hang.
typedef SyncProgress = void Function(int done, int total);

/// A user-facing checkpoint for the sync modal. Pull totals are sometimes
/// unknown, so [total] is nullable and the UI can use an indeterminate bar.
class SyncActivity {
  const SyncActivity({
    required this.phase,
    required this.message,
    this.done = 0,
    this.total,
    this.currentItem,
  });

  final String phase;
  final String message;
  final int done;
  final int? total;
  final String? currentItem;
}

typedef SyncActivityCallback = void Function(SyncActivity activity);

class SyncService {
  SyncService(this._database, this.serverUrl, this.token, this.deviceId,
      {http.Client? httpClient})
      : _httpClient = httpClient;
  final LocalDatabase _database;
  final Uri serverUrl;
  final String token;
  final String deviceId;

  /// Injected only by tests.
  final http.Client? _httpClient;

  ApiClient _api() =>
      ApiClient(serverUrl, token: token, httpClient: _httpClient);

  /// The server caps how many operations one push may carry, so a device that
  /// has been offline for a while drains its queue in batches. Exceeding the
  /// cap fails validation and nothing ever syncs.
  static const _batchSize = 500;

  Future<void> synchronize(
      {SyncProgress? onProgress,
      SyncActivityCallback? onActivity,
      SyncQueueScope scope = SyncQueueScope.all}) async {
    final client = _api();
    await pushPending(
        onProgress: onProgress, onActivity: onActivity, scope: scope);

    // Product catalogs can contain hundreds of thousands of queued rows. Keep
    // their pull watermark separate so a catalog problem never prevents sales,
    // register, inventory, finance, or settings data from synchronizing.
    final watermarkKey = switch (scope) {
      SyncQueueScope.products => 'sync_watermark_products',
      SyncQueueScope.businessData => 'sync_watermark_business_data',
      SyncQueueScope.all => 'sync_watermark',
    };
    final pullScope = switch (scope) {
      SyncQueueScope.products => 'products',
      SyncQueueScope.businessData => 'business_data',
      SyncQueueScope.all => 'all',
    };
    final since = await _database.setting(watermarkKey);
    String? cursor;
    String? until;
    String? serverTime;
    var received = 0;
    var page = 0;
    do {
      page++;
      final receivingProducts = scope == SyncQueueScope.products;
      onActivity?.call(SyncActivity(
        phase: receivingProducts
            ? 'Receiving products'
            : 'Receiving business data',
        message: received == 0
            ? 'Requesting updates from the server...'
            : '${_compact(received)} item(s) received; requesting page $page...',
        done: received,
      ));
      final snapshot = await client.pull(
        since: since,
        scope: pullScope,
        cursor: cursor,
        until: until,
        limit: scope == SyncQueueScope.products ? 2000 : null,
      );
      final pageItems = _snapshotItemCount(snapshot, scope);
      received += pageItems;
      onActivity?.call(SyncActivity(
        phase: receivingProducts
            ? 'Receiving products'
            : 'Receiving business data',
        message: pageItems == 0
            ? 'The server has no new ${receivingProducts ? 'products' : 'business records'}.'
            : '${_compact(received)} item(s) received from the server',
        done: received,
        currentItem: _snapshotItemLabel(snapshot, scope),
      ));
      await _database.applyServerSnapshot(snapshot);
      serverTime ??= snapshot['server_time']?.toString();
      until ??= serverTime;
      cursor = snapshot['has_more'] == true
          ? snapshot['next_cursor']?.toString()
          : null;
    } while (cursor != null && cursor.isNotEmpty);
    onActivity?.call(const SyncActivity(
      phase: 'Finalizing sync',
      message: 'Saving the server checkpoint on this device...',
    ));
    // Rebuild the local logo file from the synced base64 image, if it changed.
    await materializeSyncedLogo(_database);

    // Advance the watermark using the server's own clock, so a device whose
    // time is off can't skip records or replay them forever.
    if (serverTime != null && serverTime.isNotEmpty) {
      await _database.saveSetting(watermarkKey, serverTime);
    }
    await _database.saveSetting('last_sync_error', '');
  }

  Future<void> pushPending(
      {SyncProgress? onProgress,
      SyncActivityCallback? onActivity,
      SyncQueueScope scope = SyncQueueScope.all}) async {
    final client = _api();
    // Freeze the current retry generation. Each rejected operation increments
    // its attempt count, falls out of this run, and lets the next queued batch
    // proceed. This remains constant-space even for a six-figure catalog.
    final maxAttempts = await _database.maxPendingAttempts(scope: scope);
    final total = await _database.pendingOperationCount(scope: scope);
    var done = 0;
    onProgress?.call(0, total);
    final subject = scope == SyncQueueScope.products ? 'products' : 'changes';
    onActivity?.call(SyncActivity(
      phase: total == 0 ? 'Checking local changes' : 'Sending $subject',
      message: total == 0
          ? 'No queued $subject are waiting to be sent.'
          : '0 of ${_compact(total)} item(s) sent',
      total: total,
    ));
    while (true) {
      final pending = await _database.pendingOperations(
          limit: _batchSize, maxAttempts: maxAttempts, scope: scope);
      if (pending.isEmpty) return;
      final operations = pending
          .map<Map<String, dynamic>>((row) => {
                'operation_id': row['operation_id'] as String,
                'device_id': deviceId,
                'type': row['type'] as String,
                'payload': jsonDecode(row['payload']! as String),
              })
          .toList();
      final Map<String, dynamic> response;
      try {
        response = await _push(client, operations);
      } catch (error) {
        // The whole request failed — an unreachable server, a dead token, a
        // rejected device. That says nothing about the individual operations,
        // so leave their attempt counts alone and record it as a sync-level
        // problem instead of flagging every queued change as broken.
        await _database.saveSetting('last_sync_error', error.toString());
        rethrow;
      }

      final results =
          (response['results'] as List<dynamic>).cast<Map<String, dynamic>>();
      final completed = <String>[];
      final failures = <String, String>{};
      for (final result in results) {
        if (result['status'] == 'processed' ||
            result['status'] == 'already_processed') {
          completed.add(result['operation_id'] as String);
        } else {
          failures[result['operation_id'] as String] =
              result['error']?.toString() ?? 'Server rejected the operation.';
        }
      }
      await _database.markOperationsSynced(completed);
      await _database.recordSyncFailures(failures);
      done += operations.length;
      onProgress?.call(done, total);
      onActivity?.call(SyncActivity(
        phase: 'Sending $subject',
        message: '${_compact(done)} of ${_compact(total)} item(s) sent',
        done: done,
        total: total,
        currentItem: _operationItemLabel(operations.last),
      ));
    }
  }

  static int _snapshotItemCount(
      Map<String, dynamic> snapshot, SyncQueueScope scope) {
    if (scope == SyncQueueScope.products) {
      return (snapshot['products'] as List<dynamic>? ?? []).length;
    }
    const keys = [
      'inventory',
      'credits',
      'credit_payments',
      'expenses',
      'register_shifts',
      'cash_movements',
      'settings',
      'users',
    ];
    return keys.fold<int>(0,
        (total, key) => total + (snapshot[key] as List<dynamic>? ?? []).length);
  }

  static String? _snapshotItemLabel(
      Map<String, dynamic> snapshot, SyncQueueScope scope) {
    if (scope == SyncQueueScope.products) {
      final products = snapshot['products'] as List<dynamic>? ?? [];
      if (products.isEmpty) return null;
      final product = products.last as Map<String, dynamic>;
      return product['name']?.toString() ?? product['id']?.toString();
    }
    const candidates = [
      ('users', 'name'),
      ('settings', 'key'),
      ('expenses', 'description'),
      ('credits', 'customer_name'),
      ('register_shifts', 'id'),
      ('cash_movements', 'type'),
      ('inventory', 'product_id'),
      ('credit_payments', 'id'),
    ];
    for (final candidate in candidates) {
      final items = snapshot[candidate.$1] as List<dynamic>? ?? [];
      if (items.isNotEmpty) {
        final item = items.last as Map<String, dynamic>;
        final value = item[candidate.$2]?.toString();
        return value == null || value.isEmpty
            ? _friendlyOperation(candidate.$1)
            : value;
      }
    }
    return null;
  }

  static String _operationItemLabel(Map<String, dynamic> operation) {
    final payload = operation['payload'] as Map<String, dynamic>;
    final detail = const [
      'name',
      'product_name',
      'receipt_number',
      'customer_name',
      'description',
      'key',
      'id',
    ].map((key) => payload[key]?.toString()).firstWhere(
        (value) => value != null && value.isNotEmpty,
        orElse: () => null);
    final operationName = _friendlyOperation(operation['type'] as String);
    return detail == null ? operationName : '$operationName - $detail';
  }

  static String _friendlyOperation(String value) => value
      .replaceAll('.', ' ')
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  static String _compact(int value) => value < 1000
      ? '$value'
      : '${(value / 1000).toStringAsFixed(value < 10000 ? 1 : 0)}k';

  /// Pushes [operations], registering this device first if the server says it
  /// does not know it yet. Device registration can be missed when the first
  /// sign-in happened offline, or when it failed silently during sign-in.
  Future<Map<String, dynamic>> _push(
      ApiClient client, List<Map<String, dynamic>> operations) async {
    try {
      return await client.push(operations);
    } on ApiException catch (error) {
      if (!error.isUnregisteredDevice) rethrow;
      await _registerThisDevice(client);
      return await client.push(operations);
    }
  }

  Future<void> _registerThisDevice(ApiClient client) async {
    final name = (await _database.setting('device_name'))?.trim() ?? '';
    final branchId = await _database.setting('branch_id');
    await client.registerDevice(
      id: deviceId,
      name: name.isEmpty ? 'Chirpy POS terminal' : name,
      mode: 'hosted',
      // Offline sign-in stores a placeholder branch; the server only accepts a
      // UUID here and falls back to the user's own branch when it is absent.
      branchId: _isUuid(branchId) ? branchId : null,
    );
  }

  static bool _isUuid(String? value) =>
      value != null &&
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
              r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(value);
}
