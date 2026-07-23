import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import 'data/local/local_database.dart';
import 'data/remote/api_client.dart';

/// The login gate shown when no session token is stored. Signs the cashier in
/// with a username + password, registers the device, and persists the session.
class LoginScreen extends StatefulWidget {
  const LoginScreen(
      {super.key, required this.database, required this.onSignedIn});
  final LocalDatabase database;
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _server = TextEditingController(text: 'http://127.0.0.1:8000');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _deviceName = TextEditingController(text: 'POS terminal');
  final _form = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final server = await widget.database.setting('server_url');
    final deviceName = await widget.database.setting('device_name');
    if (!mounted) return;
    setState(() {
      if (server != null && server.isNotEmpty) _server.text = server;
      if (deviceName != null && deviceName.isNotEmpty) {
        _deviceName.text = deviceName;
      }
    });
  }

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _deviceName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final Uri baseUrl;
    try {
      baseUrl = Uri.parse(_server.text.trim());
    } on FormatException {
      setState(() {
        _loading = false;
        _error = 'Enter a full server address, such as http://127.0.0.1:8000.';
      });
      return;
    }

    // Step 1: authenticate against the server.
    Map<String, dynamic> result;
    try {
      result = await ApiClient(baseUrl)
          .login(_username.text.trim(), _password.text);
    } on ApiException catch (error) {
      // Server reachable but rejected the login. This also happens for an
      // account created offline that hasn't synced yet, so try the local cache
      // before surfacing the server's reason.
      final ok = await _offlineSignIn();
      if (!ok && mounted) setState(() => _error = error.message);
      if (mounted) setState(() => _loading = false);
      return;
    } catch (_) {
      // Couldn't reach the server: fall back to a cached login if one exists.
      final ok = await _offlineSignIn();
      if (!ok && mounted) {
        setState(() => _error =
            'Can\'t reach the server, and no saved offline login was found '
            'for this user. Connect to the server to sign in the first time.');
      }
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Step 2: the login succeeded, so persist the FRESH token before doing
    // anything else. Device registration must never be able to discard this
    // session and leave a stale cached token behind.
    try {
      final user = result['user'] as Map<String, dynamic>;
      final token = result['token'] as String;
      final branchId = user['branch_id']?.toString() ?? '';
      final userName = user['name']?.toString() ?? _username.text.trim();
      final userRole = user['role']?.toString() ?? '';
      final deviceId =
          await widget.database.setting('device_id') ?? const Uuid().v4();
      final deviceName = _deviceName.text.trim().isEmpty
          ? 'POS terminal'
          : _deviceName.text.trim();
      await widget.database.saveSetting('server_url', baseUrl.toString());
      await widget.database.saveSetting('token', token);
      await widget.database.saveSetting('device_id', deviceId);
      await widget.database.saveSetting('branch_id', branchId);
      await widget.database.saveSetting('user_name', userName);
      await widget.database.saveSetting('user_role', userRole);
      await widget.database.saveSetting('device_name', deviceName);
      // Remember this login so the user can still sign in offline later.
      await widget.database.cacheCredential(
          username: _username.text.trim(),
          password: _password.text,
          userName: userName,
          userRole: userRole,
          branchId: branchId,
          token: token);
      // Register this device, but don't fail the sign-in if it errors — the
      // session token is already valid and saved for syncing.
      try {
        await ApiClient(baseUrl, token: token).registerDevice(
            id: deviceId, name: deviceName, mode: 'hosted', branchId: branchId);
      } catch (_) {}
      widget.onSignedIn();
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = 'Signed in, but could not save the session: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Attempts to sign in using credentials cached from a prior online login.
  /// Returns true when the cached password matches and the session is
  /// restored; false when there is no cached user or the password is wrong.
  Future<bool> _offlineSignIn() async {
    final cached = await widget.database
        .verifyCachedCredential(_username.text.trim(), _password.text);
    if (cached == null) return false;
    await widget.database.saveSetting('server_url', _server.text.trim());
    await widget.database.saveSetting('token', cached['token']!);
    await widget.database.saveSetting('branch_id', cached['branch_id']!);
    await widget.database.saveSetting('user_name', cached['user_name']!);
    await widget.database.saveSetting('user_role', cached['user_role']!);
    if (_deviceName.text.trim().isNotEmpty) {
      await widget.database.saveSetting('device_name', _deviceName.text.trim());
    }
    widget.onSignedIn();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(LucideIcons.store,
                      size: 44, color: Color(0xff16803d)),
                  const SizedBox(height: 12),
                  Text('Sign in',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Enter your cashier credentials to start.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _username,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(LucideIcons.userRound)),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter your username.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(LucideIcons.lock)),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Enter your password.'
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: Text('Server connection',
                          style: Theme.of(context).textTheme.bodyMedium),
                      children: [
                        TextFormField(
                          controller: _server,
                          decoration: const InputDecoration(
                              labelText: 'Server address'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter the server address.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _deviceName,
                          decoration:
                              const InputDecoration(labelText: 'Device name'),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: const TextStyle(color: Color(0xffb91c1c))),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.logIn, size: 18),
                      label: Text(_loading ? 'Signing in...' : 'Sign in'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
