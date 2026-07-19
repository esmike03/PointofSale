import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/local/local_database.dart';

/// Writes the base64 store logo received via sync (`logo_image`) to a local
/// file and points `logo_path` at it, so a device that received the logo from
/// another device can display it on screen and on receipts.
///
/// Idempotent: it only rewrites when the synced image actually changed, so it
/// is safe to call after every sync and whenever settings load.
Future<void> materializeSyncedLogo(LocalDatabase database) async {
  final encoded = await database.setting('logo_image');
  if (encoded == null || encoded.isEmpty) return;
  final marker = '${encoded.length}:${encoded.hashCode}';
  final storedMarker = await database.setting('logo_synced_marker');
  final currentPath = await database.setting('logo_path');
  final hasFile = currentPath != null &&
      currentPath.isNotEmpty &&
      File(currentPath).existsSync();
  if (storedMarker == marker && hasFile) return;
  Uint8List bytes;
  try {
    bytes = base64Decode(encoded);
  } catch (_) {
    return;
  }
  final directory = await getApplicationSupportDirectory();
  final target = File(p.join(directory.path, 'store_logo_synced.png'));
  await target.writeAsBytes(bytes, flush: true);
  await database.saveSetting('logo_path', target.path);
  await database.saveSetting('logo_synced_marker', marker);
}
