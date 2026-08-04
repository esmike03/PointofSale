import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import 'core/deployment_mode.dart';
import 'data/local/local_database.dart';
import 'data/remote/api_client.dart';

/// The login gate shown when no session is stored. A standalone account is
/// checked only on this device; a server account is authenticated by Laravel.
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
  final _deviceName = TextEditingController(text: 'Chirpy POS terminal');
  final _form = GlobalKey<FormState>();
  DeploymentMode _mode = DeploymentMode.standalone;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final server = await widget.database.setting('server_url');
    final deviceName = await widget.database.setting('device_name');
    final savedMode = await widget.database.setting('deployment_mode');
    if (!mounted) return;
    setState(() {
      _mode = savedMode == 'standalone'
          ? DeploymentMode.standalone
          : savedMode == null
              ? DeploymentMode.standalone
              : DeploymentMode.hosted;
      if (server != null && server.isNotEmpty) _server.text = server;
      if (deviceName != null && deviceName.isNotEmpty) {
        _deviceName.text = deviceName;
      }
      if (_mode == DeploymentMode.standalone && _username.text.isEmpty) {
        _username.text = 'admin';
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
    if (_mode == DeploymentMode.standalone) {
      await _localSignIn();
      return;
    }
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
      result =
          await ApiClient(baseUrl).login(_username.text.trim(), _password.text);
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
          ? 'Chirpy POS terminal'
          : _deviceName.text.trim();
      await widget.database.saveSetting('server_url', baseUrl.toString());
      await widget.database.saveSetting('deployment_mode', 'hosted');
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
        setState(
            () => _error = 'Signed in, but could not save the session: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _localSignIn() async {
    try {
      final account = await widget.database
          .verifyLocalCredential(_username.text.trim(), _password.text);
      if (account == null) {
        if (mounted) {
          setState(() => _error =
              'Invalid local username or password, or the account is inactive.');
        }
        return;
      }
      await widget.database.saveSetting('deployment_mode', 'standalone');
      await widget.database.saveSetting('token', 'local:${account['id']}');
      await widget.database.saveSetting('branch_id', 'local');
      await widget.database.saveSetting('user_name', account['user_name']!);
      await widget.database.saveSetting('user_role', account['user_role']!);
      widget.onSignedIn();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not sign in locally: $error');
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
    await widget.database.saveSetting('deployment_mode', 'hosted');
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

  void _selectMode(DeploymentMode mode) {
    if (_loading || mode == _mode) return;
    setState(() {
      _mode = mode;
      _error = null;
      if (mode == DeploymentMode.standalone && _username.text.isEmpty) {
        _username.text = 'admin';
      } else if (mode == DeploymentMode.hosted && _username.text == 'admin') {
        _username.clear();
      }
    });
  }

  Widget _modeChoice({
    required DeploymentMode mode,
    required IconData icon,
    required String title,
    required String caption,
  }) {
    final selected = _mode == mode;
    return Material(
      color: selected ? const Color(0xffe7f9f2) : const Color(0xfff7faf9),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _loading ? null : () => _selectMode(mode),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected ? const Color(0xff13a16f) : const Color(0xffdbe7e1),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xff0e8a60) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120e5d43),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : const Color(0xff416056),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xff153c31),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff668078),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xff0e8a60),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, {required bool compact}) {
    final imageSize = compact ? 196.0 : 300.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14005765),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: Color(0xffffaa00), size: 17),
              SizedBox(width: 7),
              Text(
                'CHIRPY POS',
                style: TextStyle(
                  color: Color(0xff146f66),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 4 : 14),
        SizedBox(
          width: imageSize,
          height: imageSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: imageSize * .73,
                height: imageSize * .73,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x65ffffff), Color(0x22ffffff)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x241bc7d2),
                      blurRadius: 45,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
              Image.asset(
                'assets/branding/login_mascot.png',
                width: imageSize,
                height: imageSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                isAntiAlias: false,
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: Offset(0, compact ? -13 : -20),
          child: Column(
            children: [
              Text(
                'Hello, seller!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xff123c38),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                    ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Let\'s make today a great sales day.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff52756d),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FeaturePill(
                    icon: LucideIcons.smartphone,
                    label: 'Works offline',
                  ),
                  _FeaturePill(
                    icon: LucideIcons.server,
                    label: 'Multi-device ready',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loginCard(BuildContext context) {
    final local = _mode == DeploymentMode.standalone;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19175f58),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(
                color: Color(0xff153c31),
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -.45,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose how this register connects, then sign in.',
              style: TextStyle(
                color: Color(0xff698078),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _modeChoice(
                    mode: DeploymentMode.standalone,
                    icon: LucideIcons.smartphone,
                    title: 'Local',
                    caption: 'This device',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _modeChoice(
                    mode: DeploymentMode.hosted,
                    icon: LucideIcons.server,
                    title: 'Server',
                    caption: 'Shared data',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Container(
                key: ValueKey(_mode),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color:
                      local ? const Color(0xfffff8dc) : const Color(0xffeaf7ff),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: local
                        ? const Color(0xffffe496)
                        : const Color(0xffbfe5f7),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      local ? LucideIcons.shieldCheck : LucideIcons.server,
                      size: 19,
                      color: local
                          ? const Color(0xffa46600)
                          : const Color(0xff16739a),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        local
                            ? 'No internet needed. First login: admin / admin1234'
                            : 'Connect multiple Chirpy POS devices to one shared server.',
                        style: TextStyle(
                          color: local
                              ? const Color(0xff71500b)
                              : const Color(0xff285c72),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _username,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your username',
                prefixIcon: Icon(LucideIcons.userRound, size: 20),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your username.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(LucideIcons.lock, size: 20),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 20,
                  ),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your password.'
                  : null,
            ),
            if (!local) ...[
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 2),
                    childrenPadding: const EdgeInsets.only(bottom: 4),
                    leading: const Icon(Icons.settings_ethernet_rounded,
                        color: Color(0xff45766a), size: 21),
                    title: const Text(
                      'Server connection',
                      style: TextStyle(
                        color: Color(0xff315b50),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    children: [
                      TextFormField(
                        controller: _server,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Server address',
                          hintText: 'http://192.168.1.10:8000',
                          prefixIcon: Icon(Icons.link_rounded, size: 20),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter the server address.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _deviceName,
                        decoration: const InputDecoration(
                          labelText: 'Device name',
                          hintText: 'Front counter',
                          prefixIcon:
                              Icon(Icons.point_of_sale_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffffeeee),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffffc9c9)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xffb42318), size: 19),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xff8f1d18),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff0e8a60),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xff9bc8b8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  elevation: 0,
                ),
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 21),
                label: Text(
                  _loading
                      ? 'Signing in...'
                      : local
                          ? 'Start selling locally'
                          : 'Connect and sign in',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: .1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 14, color: Color(0xff7b918a)),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Your credentials stay protected on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xff7b918a),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeafaff),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xffdcf8ff),
              Color(0xfff4fbef),
              Color(0xfffff7dc),
            ],
            stops: [0, .58, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -110,
              right: -80,
              child: _GlowOrb(size: 270, color: Color(0x48ffffff)),
            ),
            const Positioned(
              top: 250,
              left: -90,
              child: _GlowOrb(size: 210, color: Color(0x30ffd648)),
            ),
            const Positioned(
              bottom: -100,
              right: -70,
              child: _GlowOrb(size: 230, color: Color(0x2619c6bd)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 820;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 42 : 18,
                      wide ? 28 : 14,
                      wide ? 42 : 18,
                      26,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: wide ? 980 : 470),
                        child: wide
                            ? Row(
                                children: [
                                  Expanded(
                                      child: _hero(context, compact: false)),
                                  const SizedBox(width: 44),
                                  SizedBox(
                                    width: 430,
                                    child: _loginCard(context),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _hero(context, compact: true),
                                  _loginCard(context),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xff2b7868)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff416a61),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
