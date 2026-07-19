import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient(this.baseUrl, {this.token});
  final Uri baseUrl;
  final String? token;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => baseUrl.resolve(path);

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(_uri('/api/auth/login'),
        headers: _headers,
        body: jsonEncode({'username': username, 'password': password}));
    return _decode(response);
  }

  Future<void> registerDevice(
      {required String id,
      required String name,
      required String mode,
      required String branchId}) async {
    final response = await http.post(_uri('/api/devices/register'),
        headers: _headers,
        body: jsonEncode(
            {'id': id, 'name': name, 'mode': mode, 'branch_id': branchId}));
    _decode(response);
  }

  Future<Map<String, dynamic>> pull() async {
    final response = await http.get(_uri('/api/sync/pull'), headers: _headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> push(
      List<Map<String, dynamic>> operations) async {
    final response = await http.post(_uri('/api/sync/push'),
        headers: _headers, body: jsonEncode({'operations': operations}));
    return _decode(response);
  }

  Future<Map<String, dynamic>?> saleByReceipt(String receiptNumber) async {
    final response = await http.get(
        _uri('/api/sales/receipt/${Uri.encodeComponent(receiptNumber)}'),
        headers: _headers);
    if (response.statusCode == 404) return null;
    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> managementUsers() async {
    final response =
        await http.get(_uri('/api/management/users'), headers: _headers);
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> auditLogs() async {
    final response =
        await http.get(_uri('/api/management/audit-logs'), headers: _headers);
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createManagementUser(
      {required String name,
      required String email,
      required String username,
      required String password,
      required String role}) async {
    final response = await http.post(_uri('/api/management/users'),
        headers: _headers,
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
    final response = await http.put(_uri('/api/management/users/$id'),
        headers: _headers,
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
    final response = await http.post(
        _uri('/api/management/users/$id/${active ? 'reactivate' : 'deactivate'}'),
        headers: _headers);
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 300) {
      throw ApiException(body['message']?.toString() ??
          'Server returned ${response.statusCode}.');
    }
    return body;
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
