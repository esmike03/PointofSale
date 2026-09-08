import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient(this.baseUrl, {this.token, http.Client? httpClient})
      : _client = httpClient;
  final Uri baseUrl;
  final String? token;

  /// Injected only by tests. When absent the top-level `http` helpers are used,
  /// which open and close a connection per call so nothing has to be disposed.
  final http.Client? _client;

  Future<http.Response> _get(Uri url) =>
      _client?.get(url, headers: _headers) ?? http.get(url, headers: _headers);

  Future<http.Response> _post(Uri url, {Object? body}) =>
      _client?.post(url, headers: _headers, body: body) ??
      http.post(url, headers: _headers, body: body);

  Future<http.Response> _put(Uri url, {Object? body}) =>
      _client?.put(url, headers: _headers, body: body) ??
      http.put(url, headers: _headers, body: body);

  Future<http.Response> _delete(Uri url, {Object? body}) =>
      _client?.delete(url, headers: _headers, body: body) ??
      http.delete(url, headers: _headers, body: body);

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => baseUrl.resolve(path);

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _post(_uri('/api/auth/login'),
        body: jsonEncode({'username': username, 'password': password}));
    return _decode(response);
  }

  Future<void> registerDevice(
      {required String id,
      required String name,
      required String mode,
      String? branchId}) async {
    final response = await _post(_uri('/api/devices/register'),
        body: jsonEncode(
            {'id': id, 'name': name, 'mode': mode, 'branch_id': branchId}));
    _decode(response);
  }

  /// Pulls one independently-watermarked data group. Product definitions are
  /// intentionally separate from operational business data so a bulk catalog
  /// import cannot block sales, register, inventory, finance, or settings.
  Future<Map<String, dynamic>> pull(
      {String? since,
      String scope = 'all',
      String? cursor,
      String? until,
      int? limit}) async {
    final query = <String, String>{
      if (since != null && since.isNotEmpty) 'since': since,
      if (scope != 'all') 'scope': scope,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (until != null && until.isNotEmpty) 'until': until,
      if (limit != null) 'limit': '$limit',
    };
    final uri = _uri('/api/sync/pull')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await _get(uri);
    return _decode(response);
  }

  Future<Map<String, dynamic>> push(
      List<Map<String, dynamic>> operations) async {
    final response = await _post(_uri('/api/sync/push'),
        body: jsonEncode({'operations': operations}));
    return _decode(response);
  }

  Future<Map<String, dynamic>> resetProducts() async {
    final response = await _delete(
      _uri('/api/products/reset'),
      body: jsonEncode({'confirmation': 'RESET PRODUCTS'}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>?> saleByReceipt(String receiptNumber) async {
    final response = await _get(
        _uri('/api/sales/receipt/${Uri.encodeComponent(receiptNumber)}'));
    if (response.statusCode == 404) return null;
    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> managementUsers() async {
    final response = await _get(_uri('/api/management/users'));
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> auditLogs() async {
    final response = await _get(_uri('/api/management/audit-logs'));
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createManagementUser(
      {required String name,
      required String email,
      required String username,
      required String password,
      required String role}) async {
    final response = await _post(_uri('/api/management/users'),
        body: jsonEncode({
          'name': name,
          'email': email,
          'username': username,
          'password': password,
          'role': role
        }));
    return _decode(response);
  }

  Future<Map<String, dynamic>> updateManagementUser(
      {required String id,
      required String name,
      required String email,
      required String username,
      String? password,
      required String role}) async {
    final response = await _put(_uri('/api/management/users/$id'),
        body: jsonEncode({
          'name': name,
          'email': email,
          'username': username,
          if (password != null && password.isNotEmpty) 'password': password,
          'role': role
        }));
    return _decode(response);
  }

  Future<void> setManagementUserActive(String id, bool active) async {
    final response = await _post(_uri(
        '/api/management/users/$id/${active ? 'reactivate' : 'deactivate'}'));
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 300) {
      throw ApiException(
          body['message']?.toString() ??
              'Server returned ${response.statusCode}.',
          statusCode: response.statusCode);
    }
    return body;
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  /// Whether the server rejected the request because the session token is
  /// missing, expired, or revoked (HTTP 401).
  bool get isUnauthenticated => statusCode == 401;

  /// Whether a sync push was refused because this device has never been
  /// registered to the business. Recoverable: register, then push again.
  bool get isUnregisteredDevice =>
      statusCode == 422 &&
      message.toLowerCase().contains('register this device');

  @override
  String toString() => message;
}
