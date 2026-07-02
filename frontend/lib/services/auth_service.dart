import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/auth_user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _tokenKey = 'access_token';
  static const _userKey = 'auth_user';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _token;
  AuthUser? _user;
  bool _ready = false;

  bool get isReady => _ready;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  AuthUser? get user => _user;
  String? get token => _token;

  Future<void> init() async {
    _token = await _storage.read(key: _tokenKey);
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      try {
        _user = AuthUser.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
      } catch (_) {
        _user = null;
      }
    }
    _ready = true;
    notifyListeners();
  }

  Map<String, String> authorizationHeaders() {
    final value = _token;
    if (value == null || value.isEmpty) return {};
    return {'Authorization': 'Bearer $value'};
  }

  Future<AuthUser> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/auth/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
      }),
    );

    if (response.statusCode != 201) {
      throw _authError(response);
    }

    return _persistSession(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw _authError(response);
    }

    return _persistSession(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AuthUser> updateProfile({
    String? fullName,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/auth/profile');
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (email != null) body['email'] = email;
    if (currentPassword != null) body['current_password'] = currentPassword;
    if (newPassword != null) body['new_password'] = newPassword;

    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...authorizationHeaders(),
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw _authError(response);
    }

    return _persistSession(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    notifyListeners();
  }

  Future<AuthUser> _persistSession(Map<String, dynamic> data) async {
    final token = data['access_token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    _token = token;
    _user = user;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(data['user']));
    notifyListeners();
    return user;
  }

  Exception _authError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) {
        return Exception(detail);
      }
    } catch (_) {}
    return Exception('Authentication failed (${response.statusCode}).');
  }
}
