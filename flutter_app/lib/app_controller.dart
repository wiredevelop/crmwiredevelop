import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'services/api_client.dart';

class AppController extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isReady = false;
  String _baseUrl = 'http://127.0.0.1:8010/api/v1';
  String? _token;
  Map<String, dynamic>? _user;

  bool get isReady => _isReady;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  String get baseUrl => _baseUrl;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  ApiClient get client => ApiClient(baseUrl: _baseUrl, token: _token);

  Future<void> initialize() async {
    _baseUrl = (await _storage.read(key: 'base_url')) ?? _baseUrl;
    _token = await _storage.read(key: 'token');
    final rawName = await _storage.read(key: 'user_name');
    final rawEmail = await _storage.read(key: 'user_email');

    if (rawName != null || rawEmail != null) {
      _user = {'name': rawName, 'email': rawEmail};
    }

    _isReady = true;
    notifyListeners();
  }

  Future<void> updateBaseUrl(String value) async {
    _baseUrl = value.trim();
    await _storage.write(key: 'base_url', value: _baseUrl);
    notifyListeners();
  }

  Future<void> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    await updateBaseUrl(baseUrl);

    final data = await ApiClient(
      baseUrl: _baseUrl,
    ).login(email: email, password: password);

    final payload = data['data'] as Map<String, dynamic>;
    _token = payload['token'] as String;
    _user = (payload['user'] as Map).cast<String, dynamic>();

    await _storage.write(key: 'token', value: _token);
    await _storage.write(key: 'user_name', value: _user?['name']?.toString());
    await _storage.write(key: 'user_email', value: _user?['email']?.toString());

    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await client.post('/auth/logout');
    } catch (_) {}

    _token = null;
    _user = null;
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user_name');
    await _storage.delete(key: 'user_email');
    notifyListeners();
  }
}
