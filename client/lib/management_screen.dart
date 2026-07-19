import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'async_dispose.dart';
import 'data/local/local_database.dart';
import 'data/remote/api_client.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key, required this.database});
  final LocalDatabase database;

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  String _tab = 'staff';
  late Future<_ManagementData> _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _data = _load());
    await _data;
  }

  Future<_ManagementData> _load() async {
    final server = await widget.database.setting('server_url');
    final token = await widget.database.setting('token');
    if (server == null || token == null || token.isEmpty) {
      throw StateError('Sign in to manage staff and audit records.');
    }
    final api = ApiClient(Uri.parse(server), token: token);
    try {
      final users = await api.managementUsers();
      final logs = await api.auditLogs();
      await widget.database.cacheStaffUsers(users);
      await widget.database.cacheAuditLogs(logs);
      return _ManagementData(users: users, logs: logs, offline: false);
    } catch (_) {
      // Server unreachable: fall back to the local mirror so the admin can
      // still view and manage staff. Changes will queue and sync later.
      return _ManagementData(
        users: await widget.database.cachedStaffUsers(),
        logs: await widget.database.cachedAuditLogs(),
        offline: true,
        pendingSync: await widget.database.pendingStaffSyncCount(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Management'),
                  Text('Staff and audit trail',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500))
                ]),
            actions: [
              if (_tab == 'staff')
                IconButton(
                    onPressed: () => _userEditor(),
                    tooltip: 'Add staff',
                    icon: const Icon(LucideIcons.circlePlus)),
              IconButton(
                  onPressed: _reload,
                  tooltip: 'Refresh',
                  icon: const Icon(LucideIcons.refreshCw))
            ]),
        body: FutureBuilder<_ManagementData>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              final data = snapshot.data!;
              return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(children: [
                    if (data.offline) _offlineBanner(data.pendingSync),
                    Row(children: [
                      const Icon(LucideIcons.users, size: 19),
                      const SizedBox(width: 8),
                      Text('Business controls',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      Text('${data.users.length} staff',
                          style: Theme.of(context).textTheme.bodySmall)
                    ]),
                    const SizedBox(height: 14),
                    SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'staff',
                              icon: Icon(LucideIcons.users),
                              label: Text('Staff')),
                          ButtonSegment(
                              value: 'audit',
                              icon: Icon(LucideIcons.history),
                              label: Text('Audit'))
                        ],
                        selected: {
                          _tab
                        },
                        onSelectionChanged: (value) =>
                            setState(() => _tab = value.first)),
                    const SizedBox(height: 16),
                    Expanded(
                        child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: _tab == 'staff'
                                    ? _staffList(data.users)
                                    : _auditList(data.logs)))),
                  ]));
            }),
      );

  Widget _offlineBanner(int pending) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xfffef3c7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xfffcd34d))),
      child: Row(children: [
        const Icon(LucideIcons.cloudOff, size: 18, color: Color(0xff92620a)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(
                pending > 0
                    ? 'Offline - showing last synced staff. $pending change${pending == 1 ? '' : 's'} will sync when reconnected.'
                    : 'Offline - showing last synced staff. Changes you make will sync when reconnected.',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff92620a)))),
      ]));

  Widget _staffList(List<Map<String, dynamic>> users) => ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = users[index];
        final inactive = user['deactivated_at'] != null;
        return ListTile(
            leading: Icon(LucideIcons.users,
                color: inactive
                    ? const Color(0xff9aa5a0)
                    : const Color(0xff16803d)),
            title: Row(children: [
              Flexible(
                  child: Text(user['name'] as String,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: inactive ? const Color(0xff9aa5a0) : null))),
              if (inactive) ...[
                const SizedBox(width: 8),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xfff1f0ee),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('Inactive',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff6b7671)))),
              ],
            ]),
            subtitle: Text(user['username'] != null
                ? '@${user['username']}  |  ${user['email']}'
                : user['email'] as String),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_title(user['role'] as String),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xff146c34))),
              const SizedBox(width: 8),
              const Icon(LucideIcons.pencil,
                  size: 16, color: Color(0xff90a49a)),
            ]),
            onTap: () => _userEditor(existing: user));
      });
  Widget _auditList(List<Map<String, dynamic>> logs) => ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = logs[index];
        return ListTile(
            leading: const Icon(LucideIcons.history, color: Color(0xff16803d)),
            title: Text(_title(log['action'] as String),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                '${log['user_name'] ?? 'System'}  |  ${(log['created_at'] as String).substring(0, 16)}'),
            trailing: Text(_title(log['subject_type'] as String),
                style: Theme.of(context).textTheme.bodySmall));
      });

  Future<void> _userEditor({Map<String, dynamic>? existing}) async {
    final editing = existing != null;
    final name = TextEditingController(text: existing?['name'] as String? ?? '');
    final email =
        TextEditingController(text: existing?['email'] as String? ?? '');
    final username =
        TextEditingController(text: existing?['username'] as String? ?? '');
    final password = TextEditingController();
    final roleOptions = <String>[
      'admin',
      'business_owner',
      'store_manager',
      'cashier',
      'inventory_staff',
      'auditor',
      'accountant'
    ];
    var role = existing?['role'] as String? ?? 'cashier';
    // Keep the current role selectable even if it is outside the editable set
    // (e.g. the business owner's super_admin), so the dropdown never crashes.
    if (!roleOptions.contains(role)) roleOptions.insert(0, role);
    final form = GlobalKey<FormState>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.viewInsetsOf(sheet).bottom + 20),
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(editing ? 'Edit staff member' : 'Add staff member',
                      style: Theme.of(sheet)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800))),
              const SizedBox(height: 16),
              TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a name.'
                      : null),
              const SizedBox(height: 10),
              TextFormField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter an email.'
                      : null),
              const SizedBox(height: 10),
              TextFormField(
                  controller: username,
                  decoration: const InputDecoration(
                      labelText: 'Username',
                      helperText: 'Used by the cashier to sign in'),
                  validator: (value) => value == null || value.trim().length < 3
                      ? 'Enter a username (min 3 characters).'
                      : null),
              const SizedBox(height: 10),
              TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: editing
                          ? 'New password (leave blank to keep)'
                          : 'Temporary password'),
                  validator: (value) {
                    if (editing && (value == null || value.isEmpty)) return null;
                    return value == null || value.length < 8
                        ? 'Use at least 8 characters.'
                        : null;
                  }),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: roleOptions
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text(_roleLabel(value))))
                      .toList(),
                  onChanged: (value) => role = value!),
              const SizedBox(height: 18),
              SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                      onPressed: () async {
                        if (!form.currentState!.validate()) return;
                        final server =
                            await widget.database.setting('server_url');
                        final token = await widget.database.setting('token');
                        if (server == null || token == null) return;
                        try {
                          final api =
                              ApiClient(Uri.parse(server), token: token);
                          if (editing) {
                            await api.updateManagementUser(
                                id: existing['id'] as String,
                                name: name.text.trim(),
                                email: email.text.trim(),
                                username: username.text.trim(),
                                password:
                                    password.text.isEmpty ? null : password.text,
                                role: role);
                          } else {
                            await api.createManagementUser(
                                name: name.text.trim(),
                                email: email.text.trim(),
                                username: username.text.trim(),
                                password: password.text,
                                role: role);
                          }
                          if (sheet.mounted) Navigator.pop(sheet, true);
                        } on ApiException catch (error) {
                          // Server reachable but rejected it (e.g. duplicate
                          // username) - don't queue, show why.
                          if (sheet.mounted) {
                            ScaffoldMessenger.of(sheet).showSnackBar(
                                SnackBar(content: Text(error.message)));
                          }
                        } catch (_) {
                          // Server unreachable: apply locally and queue.
                          try {
                            if (editing) {
                              await widget.database.updateStaffUserOffline(
                                  id: existing['id'] as String,
                                  name: name.text.trim(),
                                  email: email.text.trim(),
                                  username: username.text.trim(),
                                  password: password.text.isEmpty
                                      ? null
                                      : password.text,
                                  role: role);
                            } else {
                              await widget.database.createStaffUserOffline(
                                  name: name.text.trim(),
                                  email: email.text.trim(),
                                  username: username.text.trim(),
                                  password: password.text,
                                  role: role);
                            }
                            if (sheet.mounted) Navigator.pop(sheet, true);
                          } catch (error) {
                            if (sheet.mounted) {
                              ScaffoldMessenger.of(sheet).showSnackBar(SnackBar(
                                  content: Text(error.toString())));
                            }
                          }
                        }
                      },
                      icon: Icon(
                          editing ? LucideIcons.check : LucideIcons.circlePlus),
                      label: Text(
                          editing ? 'Save changes' : 'Create staff account'))),
              if (editing && existing['role'] != 'super_admin') ...[
                const SizedBox(height: 10),
                SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: existing['deactivated_at'] == null
                        ? OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xffb91c1c)),
                            onPressed: () => _setActive(sheet, existing, false),
                            icon: const Icon(LucideIcons.userMinus, size: 18),
                            label: const Text('Deactivate account'))
                        : OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xff16803d)),
                            onPressed: () => _setActive(sheet, existing, true),
                            icon: const Icon(LucideIcons.userCheck, size: 18),
                            label: const Text('Reactivate account'))),
              ],
            ]),
          ),
        ),
      ),
    );
    disposeAfterClose([name, username, email, password]);
    if (saved == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(editing
                ? 'Staff account updated.'
                : 'Staff account created.')));
      }
      await _reload();
    }
  }

  Future<void> _setActive(
      BuildContext sheet, Map<String, dynamic> existing, bool active) async {
    if (!active) {
      final confirm = await showDialog<bool>(
        context: sheet,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Deactivate account?'),
          content: Text(
              '${existing['name']} will no longer be able to sign in. You can reactivate them anytime.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffb91c1c)),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Deactivate')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    final server = await widget.database.setting('server_url');
    final token = await widget.database.setting('token');
    if (server == null || token == null) return;
    try {
      await ApiClient(Uri.parse(server), token: token)
          .setManagementUserActive(existing['id'] as String, active);
      if (sheet.mounted) Navigator.pop(sheet, true);
    } on ApiException catch (error) {
      if (sheet.mounted) {
        ScaffoldMessenger.of(sheet)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      // Server unreachable: apply locally and queue for sync.
      try {
        await widget.database
            .setStaffUserActiveOffline(existing['id'] as String, active);
        if (sheet.mounted) Navigator.pop(sheet, true);
      } catch (error) {
        if (sheet.mounted) {
          ScaffoldMessenger.of(sheet)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
  }

  String _title(String value) => _roleLabel(value.replaceAll('.', ' '));
}

class _ManagementData {
  const _ManagementData(
      {required this.users,
      required this.logs,
      this.offline = false,
      this.pendingSync = 0});
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> logs;
  final bool offline;
  final int pendingSync;
}

String _roleLabel(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map((word) =>
        word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
