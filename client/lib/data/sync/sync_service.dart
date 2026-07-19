import 'dart:convert';

import '../../logo_sync.dart';
import '../local/local_database.dart';
import '../remote/api_client.dart';

class SyncService {
  SyncService(this._database, this.serverUrl, this.token, this.deviceId);
  final LocalDatabase _database;
  final Uri serverUrl;
  final String token;
  final String deviceId;

  Future<void> synchronize() async {
    final client = ApiClient(serverUrl, token: token);
    await pushPending();
    final snapshot = await client.pull();
    await _database.applyServerSnapshot(snapshot);
    // Rebuild the local logo file from the synced base64 image, if it changed.
    await materializeSyncedLogo(_database);
  }

  Future<void> pushPending() async {
    final pending = await _database.pendingOperations();
    if (pending.isEmpty) return;
    final operations = pending
        .map<Map<String, dynamic>>((row) => {
              'operation_id': row['operation_id'] as String,
              'device_id': deviceId,
              'type': row['type'] as String,
              'payload': jsonDecode(row['payload']! as String),
            })
        .toList();
    try {
      final response =
          await ApiClient(serverUrl, token: token).push(operations);
      final results = response['results'] as List<dynamic>;
      final completed = <String>[];
      final failures = <String, String>{};
      for (final result in results.cast<Map<String, dynamic>>()) {
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
    } catch (error) {
      await _database.recordSyncFailure(
          pending.map((row) => row['operation_id']! as String),
          error.toString());
      rethrow;
    }
  }
}
