import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'data/local/local_database.dart';
import 'data/remote/api_client.dart';
import 'data/sync/sync_service.dart';
import 'logo_sync.dart';
import 'management_screen.dart';
import 'module_fab.dart';
import 'ui_kit.dart';

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
  final deviceName = TextEditingController(text: 'Chirpy POS terminal');
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

  /// (operations pushed, operations queued) while a large drain is running.
  (int, int)? syncProgress;
  SyncQueueScope? activeSyncScope;
  String? signedInAs;
  String? userRole;
  String? lastSyncedAt;
  String? lastProductSyncedAt;
  String deploymentMode = 'hosted';

  bool get isStandalone => deploymentMode == 'standalone';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await materializeSyncedLogo(widget.database);
    deploymentMode =
        await widget.database.setting('deployment_mode') ?? 'hosted';
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
    userRole = await widget.database.setting('user_role');
    lastSyncedAt = await widget.database.setting('last_synced_at');
    lastProductSyncedAt =
        await widget.database.setting('last_product_synced_at');
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
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: kPageTop,
      appBar: const ModuleAppBar(
        title: 'Settings',
        subtitle: 'Connection and account',
      ),
      body: ModuleBody(
        padded: false,
        child: ListView(
          padding: compact
              ? const EdgeInsets.fromLTRB(12, 10, 12, 90)
              : const EdgeInsets.fromLTRB(22, 14, 22, 96),
          children: [
            _identityPanel(),
            if (!isStandalone) ...[
              const SizedBox(height: 14),
              _connectionPanel(),
            ],
            const SizedBox(height: 14),
            _accountPanel(),
            if (!isStandalone) ...[
              const SizedBox(height: 14),
              ModulePanel(
                icon: LucideIcons.refreshCw,
                title: 'Offline sync',
                subtitle: 'What is waiting to reach the server',
                child: FutureBuilder<_SyncOverviews>(
                  future: _syncOverviews(),
                  builder: (context, snapshot) => Column(
                    children: [
                      _SyncStatusPanel(
                        heading: 'Business data',
                        description:
                            'Sales, register, inventory, finance, staff, and receipt settings',
                        actionLabel: 'Sync business data',
                        overview: snapshot.data?.businessData,
                        lastSyncedAt: lastSyncedAt,
                        onRetry: signedInAs == null || loading ? null : _sync,
                      ),
                      const SizedBox(height: 12),
                      _SyncStatusPanel(
                        heading: 'Products and items',
                        description:
                            'The catalog is sent separately so a bulk import cannot block business data',
                        actionLabel: 'Sync products',
                        overview: snapshot.data?.products,
                        lastSyncedAt: lastProductSyncedAt,
                        onRetry: signedInAs == null || loading
                            ? null
                            : _syncProducts,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (!isStandalone) ...[
              _serverProductResetPanel(),
              const SizedBox(height: 14),
            ],
            _dataResetPanel(),
          ],
        ),
      ),
      floatingActionButton: ModuleFab(
        onPressed: _saveReceiptSettings,
        icon: LucideIcons.save,
        label: 'Save receipt setup',
        heroTag: 'settings-save-receipt',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _identityPanel() => ModulePanel(
        icon: LucideIcons.store,
        title: 'Store and invoice identity',
        subtitle: 'What prints on every receipt',
        child: Column(children: [
          Row(children: [
            Container(
              width: 68,
              height: 68,
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kAccentSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: logoPath != null && File(logoPath!).existsSync()
                  ? Image.file(File(logoPath!), fit: BoxFit.cover)
                  : const Icon(LucideIcons.image, color: kAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Store logo',
                      style: TextStyle(
                          color: kInkStrong, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const Text('Shown at the top of printed receipts',
                      style: TextStyle(color: kInkSoft, fontSize: 11.5)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: softButton(),
                    onPressed: _pickLogo,
                    icon: const Icon(LucideIcons.upload, size: 17),
                    label: Text(logoPath == null || logoPath!.isEmpty
                        ? 'Choose logo'
                        : 'Replace logo'),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextField(
              controller: storeName,
              decoration: moduleField(
                  hint: 'Trade name customers know',
                  label: 'Store or trade name',
                  icon: LucideIcons.store)),
          const SizedBox(height: 10),
          TextField(
              controller: registeredName,
              decoration: moduleField(
                  hint: 'Name on your BIR registration',
                  label: 'Registered taxpayer name',
                  icon: LucideIcons.building2)),
          const SizedBox(height: 10),
          TextField(
              controller: registeredAddress,
              maxLines: 2,
              decoration: moduleField(
                  hint: 'Street, city, province',
                  label: 'Registered business address',
                  icon: LucideIcons.mapPin)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: tin,
                    decoration: moduleField(
                        hint: '000-000-000',
                        label: 'TIN',
                        icon: LucideIcons.hash))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: branchCode,
                    decoration: moduleField(
                        hint: '0000',
                        label: 'Branch code',
                        icon: LucideIcons.gitBranch))),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey(taxMode),
            initialValue: taxMode,
            isExpanded: true,
            decoration: moduleField(
                hint: 'Tax registration status',
                label: 'Tax registration status',
                icon: LucideIcons.landmark),
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
                decoration: moduleField(
                    hint: '12',
                    label: 'VAT rate (%)',
                    icon: LucideIcons.percent)),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('$taxMode-$posPermitStatus'),
            initialValue: posPermitStatus,
            isExpanded: true,
            decoration: moduleField(
                hint: 'POS permit status',
                label: 'POS permit status',
                icon: LucideIcons.badgeCheck),
            items: const [
              DropdownMenuItem(
                  value: 'not_permitted', child: Text('Not permitted')),
              DropdownMenuItem(
                  value: 'permitted', child: Text('BIR permitted')),
            ],
            onChanged: taxMode == 'unregistered'
                ? null
                : (value) =>
                    setState(() => posPermitStatus = value ?? 'not_permitted'),
          ),
          if (posPermitStatus == 'permitted') ...[
            const SizedBox(height: 10),
            TextField(
                controller: permitNumber,
                decoration: moduleField(
                    hint: 'Permit to Use number',
                    label: 'BIR Permit to Use number',
                    icon: LucideIcons.fileCheck2)),
            const SizedBox(height: 10),
            TextField(
                controller: machineIdentificationNumber,
                decoration: moduleField(
                    hint: 'MIN',
                    label: 'Machine Identification Number (MIN)',
                    icon: LucideIcons.monitorCog)),
          ],
        ]),
      );

  Widget _connectionPanel() => ModulePanel(
        icon: LucideIcons.satelliteDish,
        title: 'Device connection',
        subtitle: 'Where this terminal syncs to',
        child: Column(children: [
          TextField(
              controller: server,
              keyboardType: TextInputType.url,
              decoration: moduleField(
                  hint: 'http://192.168.1.10:8000',
                  label: 'Server address',
                  icon: LucideIcons.globe)),
          const SizedBox(height: 10),
          TextField(
              controller: deviceName,
              decoration: moduleField(
                  hint: 'Counter 1',
                  label: 'Device name',
                  icon: LucideIcons.monitor)),
        ]),
      );

  Widget _accountPanel() => ModulePanel(
        icon: signedInAs == null ? LucideIcons.logIn : LucideIcons.circleCheck,
        title: signedInAs == null
            ? 'Sign in'
            : isStandalone
                ? 'Local account'
                : 'Connected account',
        subtitle: signedInAs == null
            ? 'Connect this device to your server'
            : 'Staff access and device session',
        child: signedInAs == null
            ? Column(children: [
                TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: moduleField(
                        hint: 'you@example.com',
                        label: 'Email',
                        icon: LucideIcons.mail)),
                const SizedBox(height: 10),
                TextField(
                    controller: password,
                    obscureText: true,
                    decoration: moduleField(
                        hint: 'Your password',
                        label: 'Password',
                        icon: LucideIcons.lockKeyhole)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: accentButton(),
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
              ])
            : Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kRowSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kRowBorder),
                  ),
                  child: Row(children: [
                    const RowIcon(
                        icon: LucideIcons.circleCheck, color: kAccent),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(isStandalone ? 'Signed in locally' : 'Signed in',
                              style: const TextStyle(
                                  color: kInkStrong,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(signedInAs!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: kInkSoft, fontSize: 11.5)),
                        ])),
                  ]),
                ),
                if (!isStandalone) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: accentButton(),
                      onPressed: loading ? null : _sync,
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.refreshCw, size: 18),
                      label: Text(_syncButtonLabel()),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                        style: softButton(),
                        onPressed: loading
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => ManagementScreen(
                                        database: widget.database))),
                        icon: const Icon(LucideIcons.users, size: 18),
                        label: Text(isStandalone
                            ? 'Manage local accounts'
                            : 'Manage staff and audit trail'))),
                const SizedBox(height: 10),
                SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                        style: softButton(),
                        onPressed: loading ? null : _signOut,
                        icon: const Icon(LucideIcons.logOut, size: 18),
                        label: const Text('Sign out from this device'))),
              ]),
      );

  Widget _dataResetPanel() => ModulePanel(
        icon: LucideIcons.trash2,
        title: 'Reset app data',
        subtitle: 'Return this installation to a fresh-app state',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Deletes products, sales, register history, finance records, '
            'settings, cached accounts, and every pending sync operation on '
            'this device. You will be signed out.',
            style: TextStyle(color: kInkSoft, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kDanger,
                foregroundColor: Colors.white,
              ),
              onPressed: loading ? null : _confirmResetAppData,
              icon: const Icon(LucideIcons.rotateCcw, size: 18),
              label: const Text('Reset all local data'),
            ),
          ),
        ]),
      );

  Widget _serverProductResetPanel() {
    final allowed =
        const {'super_admin', 'admin', 'business_owner'}.contains(userRole);
    return ModulePanel(
      icon: LucideIcons.server,
      title: 'Reset server products',
      subtitle: 'Clear only the shared server catalog',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Deletes all products, barcodes, and current inventory quantities '
          'for this business on the server. Sales, receipts, accounts, and '
          'finance records are preserved. Synced devices clear their old '
          'catalog on the next product sync. Sync every device first so no '
          'unsynced sale still depends on an old product.',
          style: TextStyle(color: kInkSoft, fontSize: 12, height: 1.45),
        ),
        if (!allowed) ...[
          const SizedBox(height: 10),
          const Text(
            'Only a business owner or administrator can perform this reset.',
            style: TextStyle(color: kDanger, fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: kDanger,
              side: const BorderSide(color: kDanger),
            ),
            onPressed: loading || signedInAs == null || !allowed
                ? null
                : _confirmResetServerProducts,
            icon: const Icon(LucideIcons.packageX, size: 18),
            label: const Text('Reset products on server'),
          ),
        ),
      ]),
    );
  }

  Future<void> _confirmResetServerProducts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset server products?'),
        content: const Text(
          'This permanently deletes the shared product catalog, barcodes, '
          'and current inventory quantities. Historical sales and accounts '
          'will remain. Sync every device before continuing; unsynced sales '
          'that use old products may fail. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset server products'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final serverUrl = await widget.database.setting('server_url');
    final token = await widget.database.setting('token');
    final offlineSession = await widget.database.setting('offline_session');
    if (!mounted) return;
    if (serverUrl == null ||
        serverUrl.trim().isEmpty ||
        token == null ||
        token.isEmpty) {
      _show('Sign in to the server before resetting its product catalog.');
      return;
    }
    if (offlineSession == '1') {
      _show('Sign in online again before resetting server products.');
      return;
    }

    setState(() => loading = true);
    try {
      final result =
          await ApiClient(Uri.parse(serverUrl), token: token).resetProducts();
      final resetAt = result['reset_at']?.toString() ?? '';
      await widget.database.resetProductData(resetAt: resetAt);
      lastProductSyncedAt = null;
      widget.onChanged();
      if (mounted) setState(() {});
      _show(
          '${result['deleted_products'] ?? 0} server product(s) deleted. Sales history was preserved.');
    } on ApiException catch (error) {
      if (error.isUnauthenticated) {
        await widget.database.saveSetting('offline_session', '1');
      }
      _show(error.message);
    } on FormatException {
      _show('The saved server address is invalid.');
    } catch (error) {
      _show('Could not reset server products: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _confirmResetAppData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset this app?'),
        content: const Text(
          'This permanently deletes all local records and unsynced changes. '
          'Server data is not deleted. The app will return to the login '
          'screen when the reset finishes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset app'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => loading = true);
    try {
      await widget.database.resetAllData();
      widget.onChanged();
      widget.onSignedOut?.call();
    } catch (error) {
      _show('Could not reset the app data: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

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

  Future<_SyncOverviews> _syncOverviews() async => _SyncOverviews(
        businessData: _SyncOverview(
          summary: await widget.database
              .syncSummary(scope: SyncQueueScope.businessData),
          issues: await widget.database
              .syncIssues(scope: SyncQueueScope.businessData),
        ),
        products: _SyncOverview(
          summary:
              await widget.database.syncSummary(scope: SyncQueueScope.products),
          issues:
              await widget.database.syncIssues(scope: SyncQueueScope.products),
        ),
      );

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
              ? 'Chirpy POS terminal'
              : deviceName.text.trim(),
          mode: 'hosted',
          branchId: user['branch_id'] as String);
      await widget.database.saveSetting('server_url', baseUrl.toString());
      await widget.database.saveSetting('deployment_mode', 'hosted');
      await widget.database.saveSetting('token', token);
      await widget.database.saveSetting('offline_session', '0');
      await widget.database.saveSetting('device_id', deviceId);
      await widget.database
          .saveSetting('branch_id', user['branch_id'] as String);
      await widget.database.saveSetting('user_name', user['name'] as String);
      await widget.database
          .saveSetting('user_role', user['role'] as String? ?? '');
      await widget.database.saveSetting('device_name', deviceName.text.trim());
      signedInAs = user['name'] as String;
      userRole = user['role'] as String? ?? '';
      deploymentMode = 'hosted';
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

  Future<void> _sync() => _runSync(SyncQueueScope.businessData);

  Future<void> _syncProducts() => _runSync(SyncQueueScope.products);

  Future<void> _runSync(SyncQueueScope scope) async {
    // Every branch here has to say something. A silent return leaves the
    // cashier tapping "Sync now" with no spinner, no message and no error,
    // which reads exactly like a broken server.
    if (await widget.database.setting('deployment_mode') == 'standalone') {
      _show('This device runs standalone. Connect it to a server below to '
          'start syncing.');
      return;
    }
    final serverUrl = await widget.database.setting('server_url');
    if (serverUrl == null || serverUrl.trim().isEmpty) {
      _show('Set the server address and sign in before syncing.');
      return;
    }
    if (await widget.database.setting('offline_session') == '1') {
      _showAction(
        'This device was signed in with saved offline credentials. Sign in '
        'online to create a fresh server session before syncing.',
        label: 'Sign in',
        onPressed: _signOut,
      );
      return;
    }
    final token = await widget.database.setting('token');
    if (token == null || token.isEmpty) {
      _show('Sign in to sync with the server.');
      return;
    }
    // A device that first signed in offline never got an id, and without one
    // sync used to give up silently. Mint one here; the push registers it with
    // the server on the first attempt.
    var deviceId = await widget.database.setting('device_id');
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await widget.database.saveSetting('device_id', deviceId);
    }
    if (!mounted) return;

    final modalProgress = ValueNotifier<SyncActivity>(SyncActivity(
      phase: 'Preparing sync',
      message: scope == SyncQueueScope.products
          ? 'Checking product changes on this device...'
          : 'Checking business-data changes on this device...',
    ));
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    var progressDismissed = false;
    setState(() {
      loading = true;
      activeSyncScope = scope;
    });
    final progressDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => _SyncProgressDialog(
        progress: modalProgress,
        products: scope == SyncQueueScope.products,
      ),
    );

    Future<void> dismissProgress() async {
      if (progressDismissed) return;
      progressDismissed = true;
      if (rootNavigator.mounted && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      await progressDialog;
    }

    try {
      await SyncService(widget.database, Uri.parse(serverUrl), token, deviceId)
          .synchronize(
        scope: scope,
        onActivity: (activity) {
          if (!progressDismissed) modalProgress.value = activity;
        },
        onProgress: (done, total) {
          // Only worth showing inline once the queue is big enough that the
          // drain takes real time. The modal reports every sync regardless.
          if (total < 500 || !mounted) return;
          setState(() => syncProgress = (done, total));
        },
      );
      final completedAt = DateTime.now().toUtc().toIso8601String();
      final isProducts = scope == SyncQueueScope.products;
      if (isProducts) {
        lastProductSyncedAt = completedAt;
        await widget.database
            .saveSetting('last_product_synced_at', completedAt);
      } else {
        lastSyncedAt = completedAt;
        await widget.database.saveSetting('last_synced_at', completedAt);
      }
      widget.onChanged();
      // Refresh the identity fields from any settings just pulled from the
      // server, so a sync visibly updates this screen instead of showing stale
      // values (and so re-saving can't overwrite them with old text).
      await _load();
      final summary = await widget.database.syncSummary(scope: scope);
      final label = isProducts ? 'Product sync' : 'Business data sync';
      await dismissProgress();
      _show(summary['failed_count']! > 0
          ? '$label finished with ${summary['failed_count']} item(s) needing attention.'
          : '$label complete.');
    } on ApiException catch (error) {
      await dismissProgress();
      if (error.isUnauthenticated) {
        await widget.database.saveSetting('offline_session', '1');
        // The stored token is dead (expired, revoked, or the server was
        // reset). Never sign the user out over this: everything still works
        // offline, and dropping a cashier to the login screen mid-shift can
        // interrupt a sale. Tell them, and let them choose when to re-auth.
        _showAction(
          'Your server session has expired. Sales are still saved on this '
          'device and will sync once you sign in again.',
          label: 'Sign in',
          onPressed: _signOut,
        );
      } else {
        _show(error.message);
      }
    } catch (error) {
      await dismissProgress();
      _show('Could not reach the server. Your changes are safe on this device '
          'and will sync on the next try.');
      debugPrint('Sync failed: $error');
    } finally {
      await dismissProgress();
      modalProgress.dispose();
      if (mounted) {
        setState(() {
          loading = false;
          syncProgress = null;
          activeSyncScope = null;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await widget.database.saveSetting('token', '');
    await widget.database.saveSetting('user_name', '');
    await widget.database.saveSetting('user_role', '');
    await widget.database.saveSetting('offline_session', '0');
    signedInAs = null;
    userRole = null;
    if (mounted) setState(() {});
    widget.onSignedOut?.call();
  }

  String _syncButtonLabel() {
    if (!loading) return 'Sync now';
    final progress = syncProgress;
    final subject = activeSyncScope == SyncQueueScope.products
        ? 'products'
        : 'business data';
    if (progress == null) return 'Syncing $subject...';
    final percent = (progress.$1 / progress.$2 * 100).clamp(0, 100).round();
    return 'Sending ${_compact(progress.$1)} of ${_compact(progress.$2)}  •  $percent%';
  }

  static String _compact(int value) => value < 1000
      ? '$value'
      : '${(value / 1000).toStringAsFixed(value < 10000 ? 1 : 0)}k';

  void _show(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// A message the cashier can act on, rather than an action taken for them.
  void _showAction(String message,
      {required String label, required VoidCallback onPressed}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: label, onPressed: onPressed),
      ));
    }
  }
}

class _SyncProgressDialog extends StatelessWidget {
  const _SyncProgressDialog({required this.progress, required this.products});

  final ValueListenable<SyncActivity> progress;
  final bool products;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const Key('sync-progress-dialog'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kAccentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(LucideIcons.refreshCw, color: kAccent, size: 24),
          ),
          title: Text(
            products ? 'Syncing products' : 'Syncing business data',
            style: const TextStyle(fontWeight: FontWeight.w800, color: kInk),
          ),
          content: SizedBox(
            width: 360,
            child: ValueListenableBuilder<SyncActivity>(
              valueListenable: progress,
              builder: (context, value, _) {
                final total = value.total;
                final determinate = total != null && total > 0;
                final fraction =
                    determinate ? (value.done / total).clamp(0.0, 1.0) : null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value.phase,
                        style: const TextStyle(
                            color: kInk, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(value.message,
                        style: const TextStyle(
                            color: kInkSoft, fontSize: 12.5, height: 1.35)),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      key: const Key('sync-progress-bar'),
                      value: fraction,
                      minHeight: 9,
                      borderRadius: BorderRadius.circular(99),
                      backgroundColor: kSoftControl,
                      color: kAccent,
                    ),
                    if (value.currentItem != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kSoftControl,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT ITEM',
                              style: TextStyle(
                                color: kInkSoft,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              value.currentItem!,
                              key: const Key('sync-current-item'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: kInk, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 13),
                    const Text(
                      'Keep the app open until synchronization is complete.',
                      style: TextStyle(color: kInkSoft, fontSize: 11.5),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
}

class _SyncOverview {
  const _SyncOverview({required this.summary, required this.issues});
  final Map<String, num> summary;
  final List<Map<String, Object?>> issues;
}

class _SyncOverviews {
  const _SyncOverviews({required this.businessData, required this.products});
  final _SyncOverview businessData;
  final _SyncOverview products;
}

class _SyncStatusPanel extends StatelessWidget {
  const _SyncStatusPanel(
      {required this.heading,
      required this.description,
      required this.actionLabel,
      required this.overview,
      required this.lastSyncedAt,
      required this.onRetry});
  final String heading;
  final String description;
  final String actionLabel;
  final _SyncOverview? overview;
  final String? lastSyncedAt;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final pending = overview?.summary['pending_count'] ?? 0;
    final failed = overview?.summary['failed_count'] ?? 0;
    final hasFailures = failed > 0;
    final waiting = pending > 0;
    final color = hasFailures ? kWarning : kAccent;
    final background = hasFailures ? kWarningSoft : kAccentSoft;
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(heading,
            style: const TextStyle(
                color: kInkStrong, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(description,
            style: const TextStyle(color: kInkSoft, fontSize: 11.5)),
        const SizedBox(height: 12),
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
                    style: const TextStyle(
                        color: kInkStrong, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(detail,
                    style: const TextStyle(color: kInkSoft, fontSize: 11.5)),
              ])),
        ]),
        if (overview != null && overview!.issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SizedBox(
              height: 1, child: ColoredBox(color: Color(0x22000000))),
          const SizedBox(height: 10),
          for (final issue in overview!.issues) ...[
            Text(_issueHeading(issue),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: kInkStrong,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(issue['last_error']! as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kInkSoft, fontSize: 11.5)),
            const SizedBox(height: 8),
          ],
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                  style: softButton(),
                  onPressed: onRetry,
                  icon: const Icon(LucideIcons.refreshCw, size: 17),
                  label: Text(actionLabel))),
        ],
        if (overview == null || overview!.issues.isEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                  style: softButton(),
                  onPressed: onRetry,
                  icon: const Icon(LucideIcons.refreshCw, size: 17),
                  label: Text(actionLabel))),
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

  static String _issueHeading(Map<String, Object?> issue) {
    final affected = (issue['affected_count'] as num?)?.toInt() ?? 1;
    final affectedLabel = affected == 1 ? '1 item' : '$affected items';
    return '${_operationLabel(issue['type']! as String)}  •  $affectedLabel  •  attempt ${issue['attempts']}';
  }

  static String _formatTimestamp(String value) {
    final time = DateTime.tryParse(value)?.toLocal();
    return time == null ? value : time.toString().substring(0, 16);
  }
}
