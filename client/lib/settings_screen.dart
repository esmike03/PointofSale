import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'app_menu.dart';
import 'data/local/local_database.dart';
import 'data/remote/api_client.dart';
import 'data/sync/sync_service.dart';
import 'logo_sync.dart';
import 'management_screen.dart';
import 'module_fab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen(
      {super.key,
      required this.database,
      required this.onChanged,
      this.onSignedOut});
  final LocalDatabase database;
  final VoidCallback onChanged;
  final VoidCallback? onSignedOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final server = TextEditingController(text: 'http://127.0.0.1:8000');
  final email = TextEditingController();
  final password = TextEditingController();
  final deviceName = TextEditingController(text: 'POS terminal');
  final storeName = TextEditingController();
  final registeredName = TextEditingController();
  final registeredAddress = TextEditingController();
  final tin = TextEditingController();
  final branchCode = TextEditingController();
  final vatRate = TextEditingController(text: '12');
  final permitNumber = TextEditingController();
  final machineIdentificationNumber = TextEditingController();
  String taxMode = 'unregistered';
  String posPermitStatus = 'not_permitted';
  String? logoPath;
  bool loading = false;
  String? signedInAs;
  String? lastSyncedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await materializeSyncedLogo(widget.database);
    server.text = await widget.database.setting('server_url') ?? server.text;
    deviceName.text =
        await widget.database.setting('device_name') ?? deviceName.text;
    storeName.text = await widget.database.setting('store_name') ?? '';
    registeredName.text =
        await widget.database.setting('registered_name') ?? '';
    registeredAddress.text =
        await widget.database.setting('registered_address') ?? '';
    tin.text = await widget.database.setting('tin') ?? '';
    branchCode.text = await widget.database.setting('branch_code') ?? '';
    taxMode = await widget.database.setting('tax_mode') ?? 'unregistered';
    posPermitStatus =
        await widget.database.setting('pos_permit_status') ?? 'not_permitted';
    if (taxMode == 'unregistered') posPermitStatus = 'not_permitted';
    vatRate.text =
        ((double.tryParse(await widget.database.setting('vat_rate') ?? '') ??
                    .12) *
                100)
            .toStringAsFixed(0);
    permitNumber.text = await widget.database.setting('permit_number') ?? '';
    machineIdentificationNumber.text =
        await widget.database.setting('machine_identification_number') ?? '';
    logoPath = await widget.database.setting('logo_path');
    final savedUser = await widget.database.setting('user_name');
    signedInAs = savedUser == null || savedUser.isEmpty ? null : savedUser;
    lastSyncedAt = await widget.database.setting('last_synced_at');
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    server.dispose();
    email.dispose();
    password.dispose();
    deviceName.dispose();
    storeName.dispose();
    registeredName.dispose();
    registeredAddress.dispose();
    tin.dispose();
    branchCode.dispose();
    vatRate.dispose();
    permitNumber.dispose();
    machineIdentificationNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: AppMenu.leadingOf(context),
          title: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings'),
                Text('Connection and account',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            const _SectionHeader(
                icon: LucideIcons.store, title: 'Store and invoice identity'),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 72,
                height: 72,
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: const Color(0xffeff8f1),
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                    border: Border.all(color: const Color(0xffcce2d0))),
                child: logoPath != null && File(logoPath!).existsSync()
                    ? Image.file(File(logoPath!), fit: BoxFit.cover)
                    : const Icon(LucideIcons.image, color: Color(0xff16803d)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 72,
                  child: OutlinedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(LucideIcons.upload, size: 20),
                      label: const Text('Choose store logo')),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: storeName,
                decoration: const InputDecoration(
                    labelText: 'Store or trade name',
                    prefixIcon: Icon(LucideIcons.store))),
            const SizedBox(height: 10),
            TextField(
                controller: registeredName,
                decoration: const InputDecoration(
                    labelText: 'Registered taxpayer name',
                    prefixIcon: Icon(LucideIcons.building2))),
            const SizedBox(height: 10),
            TextField(
                controller: registeredAddress,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Registered business address',
                    prefixIcon: Icon(LucideIcons.mapPin))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: tin,
                      decoration: const InputDecoration(
                          labelText: 'TIN',
                          prefixIcon: Icon(LucideIcons.hash)))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: branchCode,
                      decoration: const InputDecoration(
                          labelText: 'Branch code',
                          prefixIcon: Icon(LucideIcons.gitBranch)))),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(taxMode),
              initialValue: taxMode,
              decoration: const InputDecoration(
                  labelText: 'Tax registration status',
                  prefixIcon: Icon(LucideIcons.landmark)),
              items: const [
                DropdownMenuItem(
                    value: 'unregistered', child: Text('Not BIR registered')),
                DropdownMenuItem(
                    value: 'non_vat', child: Text('BIR registered - Non-VAT')),
                DropdownMenuItem(
                    value: 'vat', child: Text('BIR registered - VAT')),
              ],
              onChanged: (value) => setState(() {
                taxMode = value ?? 'unregistered';
                if (taxMode == 'unregistered') {
                  posPermitStatus = 'not_permitted';
                }
              }),
            ),
            if (taxMode == 'vat') ...[
              const SizedBox(height: 10),
              TextField(
                  controller: vatRate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'VAT rate (%)',
                      prefixIcon: Icon(LucideIcons.percent))),
            ],
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey('$taxMode-$posPermitStatus'),
              initialValue: posPermitStatus,
              decoration: const InputDecoration(
                  labelText: 'POS permit status',
                  prefixIcon: Icon(LucideIcons.badgeCheck)),
              items: const [
                DropdownMenuItem(
                    value: 'not_permitted', child: Text('Not permitted')),
                DropdownMenuItem(
                    value: 'permitted', child: Text('BIR permitted')),
              ],
              onChanged: taxMode == 'unregistered'
                  ? null
                  : (value) => setState(
                      () => posPermitStatus = value ?? 'not_permitted'),
            ),
            if (posPermitStatus == 'permitted') ...[
              const SizedBox(height: 10),
              TextField(
                  controller: permitNumber,
                  decoration: const InputDecoration(
                      labelText: 'BIR Permit to Use number',
                      prefixIcon: Icon(LucideIcons.fileCheck2))),
              const SizedBox(height: 10),
              TextField(
                  controller: machineIdentificationNumber,
                  decoration: const InputDecoration(
                      labelText: 'Machine Identification Number (MIN)',
                      prefixIcon: Icon(LucideIcons.monitorCog))),
            ],
            const SizedBox(height: 22),
            const _SoftDivider(),
            const SizedBox(height: 22),
            _SectionHeader(
                icon: LucideIcons.settings, title: 'Device connection'),
            const SizedBox(height: 14),
            TextField(
                controller: server,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'Server address',
                    hintText: 'http://192.168.1.10:8000',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: deviceName,
                decoration: const InputDecoration(
                    labelText: 'Device name', border: OutlineInputBorder())),
            const SizedBox(height: 22),
            const _SoftDivider(),
            const SizedBox(height: 22),
            _SectionHeader(
                icon: signedInAs == null
                    ? LucideIcons.logIn
                    : LucideIcons.circleCheck,
                title: signedInAs == null ? 'Sign in' : 'Connected account'),
            const SizedBox(height: 14),
            if (signedInAs == null) ...[
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: loading ? null : _signIn,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.logIn, size: 18),
                  label:
                      Text(loading ? 'Signing in...' : 'Sign in and connect'),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                    color: Color(0xffeff8f1),
                    borderRadius: BorderRadius.all(Radius.circular(6))),
                child: Row(children: [
                  const Icon(LucideIcons.circleCheck,
                      size: 20, color: Color(0xff16803d)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Signed in',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(signedInAs!,
                            style: Theme.of(context).textTheme.bodySmall),
                      ])),
                ]),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: loading ? null : _sync,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.refreshCw, size: 18),
                  label: Text(loading ? 'Synchronizing...' : 'Sync now'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                      onPressed: loading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => ManagementScreen(
                                      database: widget.database))),
                      icon: const Icon(LucideIcons.users, size: 18),
                      label: const Text('Manage staff and audit trail'))),
              const SizedBox(height: 10),
              SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                      onPressed: loading ? null : _signOut,
                      icon: const Icon(LucideIcons.logOut, size: 18),
                      label: const Text('Sign out from this device'))),
            ],
            const SizedBox(height: 22),
            const _SoftDivider(),
            const SizedBox(height: 22),
            const _SectionHeader(
                icon: LucideIcons.refreshCw, title: 'Offline sync'),
            const SizedBox(height: 14),
            FutureBuilder<_SyncOverview>(
              future: _syncOverview(),
              builder: (context, snapshot) => _SyncStatusPanel(
                  overview: snapshot.data,
                  lastSyncedAt: lastSyncedAt,
                  onRetry: signedInAs == null || loading ? null : _sync),
            ),
          ],
        ),
        floatingActionButton: ModuleFab(
          onPressed: _saveReceiptSettings,
          icon: LucideIcons.save,
          label: 'Save receipt setup',
          heroTag: 'settings-save-receipt',
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );

  Future<void> _pickLogo() async {
    final picked = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true, allowMultiple: false);
    if (picked == null) return;
    final file = picked.files.single;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      _show('Could not read the selected logo.');
      return;
    }
    final directory = await getApplicationSupportDirectory();
    final extension = p.extension(file.name).toLowerCase();
    final target = File(p.join(
        directory.path, 'store_logo${extension.isEmpty ? '.png' : extension}'));
    await target.writeAsBytes(bytes, flush: true);
    logoPath = target.path;
    if (mounted) setState(() {});
  }

  Future<void> _saveReceiptSettings() async {
    final rate = double.tryParse(vatRate.text.trim());
    if (taxMode == 'vat' && (rate == null || rate < 0 || rate > 100)) {
      _show('Enter a VAT rate from 0 to 100.');
      return;
    }
    final effectivePermitStatus =
        taxMode == 'unregistered' ? 'not_permitted' : posPermitStatus;
    if (effectivePermitStatus == 'permitted' &&
        (permitNumber.text.trim().isEmpty ||
            machineIdentificationNumber.text.trim().isEmpty)) {
      _show('Enter both the BIR Permit to Use number and MIN.');
      return;
    }
    final values = <String, String>{
      'store_name': storeName.text.trim(),
      'registered_name': registeredName.text.trim(),
      'registered_address': registeredAddress.text.trim(),
      'tin': tin.text.trim(),
      'branch_code': branchCode.text.trim(),
      'tax_mode': taxMode,
      'pos_permit_status': effectivePermitStatus,
      'vat_rate': ((rate ?? 12) / 100).toString(),
      'permit_number': permitNumber.text.trim(),
      'machine_identification_number': machineIdentificationNumber.text.trim(),
      'logo_path': logoPath ?? '',
    };
    for (final entry in values.entries) {
      await widget.database.saveSetting(entry.key, entry.value);
    }
    // Sync the logo image itself (base64), not just the device-local path.
    if (logoPath != null &&
        logoPath!.isNotEmpty &&
        File(logoPath!).existsSync()) {
      final base64Image = base64Encode(await File(logoPath!).readAsBytes());
      await widget.database.saveSetting('logo_image', base64Image);
      await widget.database.saveSetting('logo_synced_marker',
          '${base64Image.length}:${base64Image.hashCode}');
    } else {
      await widget.database.saveSetting('logo_image', '');
    }
    widget.onChanged();
    _show(effectivePermitStatus == 'permitted'
        ? 'BIR-permitted invoice setup saved.'
        : 'Receipt setup saved. POS output will be marked not valid as a BIR invoice.');
    // Push the identity to the server immediately (each field above queued a
    // settings.update op) so other devices receive it on their next sync.
    // Without this the ops would sit locally until a manual sync.
    await _sync();
  }

  Future<_SyncOverview> _syncOverview() async => _SyncOverview(
      summary: await widget.database.syncSummary(),
      issues: await widget.database.syncIssues());

  Future<void> _signIn() async {
    try {
      setState(() => loading = true);
      final baseUrl = Uri.parse(server.text.trim());
      final result =
          await ApiClient(baseUrl).login(email.text.trim(), password.text);
      final user = result['user'] as Map<String, dynamic>;
      final token = result['token'] as String;
      final deviceId =
          await widget.database.setting('device_id') ?? const Uuid().v4();
      await ApiClient(baseUrl, token: token).registerDevice(
          id: deviceId,
          name: deviceName.text.trim().isEmpty
              ? 'POS terminal'
              : deviceName.text.trim(),
          mode: 'hosted',
          branchId: user['branch_id'] as String);
      await widget.database.saveSetting('server_url', baseUrl.toString());
      await widget.database.saveSetting('token', token);
      await widget.database.saveSetting('device_id', deviceId);
      await widget.database
          .saveSetting('branch_id', user['branch_id'] as String);
      await widget.database.saveSetting('user_name', user['name'] as String);
      await widget.database
          .saveSetting('user_role', user['role'] as String? ?? '');
      await widget.database.saveSetting('device_name', deviceName.text.trim());
      signedInAs = user['name'] as String;
      await _sync();
    } on FormatException {
      _show('Enter a full server address, such as http://127.0.0.1:8000.');
    } on ApiException catch (error) {
      _show(error.message);
    } catch (error) {
      _show('Could not connect: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _sync() async {
    final serverUrl = await widget.database.setting('server_url');
    final token = await widget.database.setting('token');
    final deviceId = await widget.database.setting('device_id');
    if (serverUrl == null || token == null || deviceId == null) return;
    try {
      setState(() => loading = true);
      await SyncService(widget.database, Uri.parse(serverUrl), token, deviceId)
          .synchronize();
      lastSyncedAt = DateTime.now().toUtc().toIso8601String();
      await widget.database.saveSetting('last_synced_at', lastSyncedAt!);
      widget.onChanged();
      // Refresh the identity fields from any settings just pulled from the
      // server, so a sync visibly updates this screen instead of showing stale
      // values (and so re-saving can't overwrite them with old text).
      await _load();
      final summary = await widget.database.syncSummary();
      _show(summary['failed_count']! > 0
          ? 'Sync finished with ${summary['failed_count']} item(s) needing attention.'
          : 'Synchronization complete.');
    } on ApiException catch (error) {
      _show(error.message);
    } catch (error) {
      _show('Synchronization failed: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signOut() async {
    await widget.database.saveSetting('token', '');
    await widget.database.saveSetting('user_name', '');
    await widget.database.saveSetting('user_role', '');
    signedInAs = null;
    if (mounted) setState(() {});
    widget.onSignedOut?.call();
  }

  void _show(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _SyncOverview {
  const _SyncOverview({required this.summary, required this.issues});
  final Map<String, num> summary;
  final List<Map<String, Object?>> issues;
}

class _SyncStatusPanel extends StatelessWidget {
  const _SyncStatusPanel(
      {required this.overview,
      required this.lastSyncedAt,
      required this.onRetry});
  final _SyncOverview? overview;
  final String? lastSyncedAt;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final pending = overview?.summary['pending_count'] ?? 0;
    final failed = overview?.summary['failed_count'] ?? 0;
    final hasFailures = failed > 0;
    final waiting = pending > 0;
    final color =
        hasFailures ? const Color(0xffb45309) : const Color(0xff16803d);
    final background =
        hasFailures ? const Color(0xfffff4e5) : const Color(0xffeff8f1);
    final title = hasFailures
        ? 'Sync needs attention'
        : waiting
            ? 'Changes waiting to sync'
            : 'All local changes are synced';
    final detail = hasFailures
        ? '$failed operation${failed == 1 ? '' : 's'} will be retried on the next sync.'
        : waiting
            ? '$pending operation${pending == 1 ? '' : 's'} saved safely on this device.'
            : lastSyncedAt == null
                ? 'No local changes are waiting.'
                : 'Last synced ${_formatTimestamp(lastSyncedAt!)}.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          border: Border.all(
              color: hasFailures
                  ? const Color(0xfffed7aa)
                  : const Color(0xffcce2d0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
              hasFailures ? LucideIcons.triangleAlert : LucideIcons.circleCheck,
              size: 20,
              color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ])),
        ]),
        if (overview != null && overview!.issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SoftDivider(),
          const SizedBox(height: 10),
          for (final issue in overview!.issues) ...[
            Text(
                '${_operationLabel(issue['type']! as String)}  |  attempt ${issue['attempts']}',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(issue['last_error']! as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
          ],
          SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(LucideIcons.refreshCw, size: 17),
                  label: const Text('Retry sync'))),
        ],
      ]),
    );
  }

  static String _operationLabel(String type) => type
      .replaceAll('.', ' ')
      .split(' ')
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  static String _formatTimestamp(String value) {
    final time = DateTime.tryParse(value)?.toLocal();
    return time == null ? value : time.toString().substring(0, 16);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 19),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge)
      ]);
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: Color(0xffdfe9e1)));
}
