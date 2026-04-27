import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'services/api_client.dart';

class AppController extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String defaultBaseUrl = String.fromEnvironment(
    'WIRE_CRM_API_URL',
    defaultValue: 'https://crm.wiredevelop.pt/api/v1',
  );
  static const String legacyBaseUrl = 'https://srv1.wiredevelop.pt/api/v1';
  bool _isReady = false;
  String _baseUrl = defaultBaseUrl;
  String _apiEmail = '';
  String _apiPassword = '';
  String? _token;
  Map<String, dynamic>? _user;
  bool _biometricEnabled = false;

  bool get isReady => _isReady;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  String get baseUrl => _baseUrl;
  String get apiEmail => _apiEmail;
  String get apiPassword => _apiPassword;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get biometricEnabled => _biometricEnabled;
  bool get mustChangePassword => _user?['must_change_password'] == true;
  bool get isClientUser => _user?['role'] == 'client';

  ApiClient get client => ApiClient(baseUrl: _baseUrl, token: _token);

  Future<void> initialize() async {
    final storedBaseUrl = await _storage.read(key: 'base_url');

    _baseUrl = normalizeBaseUrl(
      storedBaseUrl == legacyBaseUrl
          ? defaultBaseUrl
          : (storedBaseUrl ?? _baseUrl),
    );
    _apiEmail = (await _storage.read(key: 'api_email')) ?? _apiEmail;
    _apiPassword = (await _storage.read(key: 'api_password')) ?? _apiPassword;
    _token = await _storage.read(key: 'token');
    _biometricEnabled =
        (await _storage.read(key: 'biometric_enabled')) == 'true';
    final rawUserPayload = await _storage.read(key: 'user_payload');
    if (rawUserPayload != null && rawUserPayload.isNotEmpty) {
      final decoded = jsonDecode(rawUserPayload);
      if (decoded is Map<String, dynamic>) {
        _user = decoded;
      }
    } else {
      final rawName = await _storage.read(key: 'user_name');
      final rawEmail = await _storage.read(key: 'user_email');
      if (rawName != null || rawEmail != null) {
        _user = {'name': rawName, 'email': rawEmail};
      }
    }

    _isReady = true;
    notifyListeners();
  }

  Future<void> updateBaseUrl(String value) async {
    _baseUrl = normalizeBaseUrl(value);
    await _storage.write(key: 'base_url', value: _baseUrl);
    notifyListeners();
  }

  Future<void> updateApiConfig({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    _baseUrl = normalizeBaseUrl(baseUrl);
    _apiEmail = email.trim();
    _apiPassword = password;

    await _storage.write(key: 'base_url', value: _baseUrl);
    await _storage.write(key: 'api_email', value: _apiEmail);
    await _storage.write(key: 'api_password', value: _apiPassword);
    notifyListeners();
  }

  String normalizeBaseUrl(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) return defaultBaseUrl;

    final withScheme = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) return defaultBaseUrl;

    var path = uri.path.trim();
    if (path.isEmpty || path == '/') {
      path = '/api/v1';
    }
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    return uri.replace(path: path, query: null, fragment: null).toString();
  }

  Future<void> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    await updateApiConfig(baseUrl: baseUrl, email: email, password: password);

    final data = await ApiClient(
      baseUrl: _baseUrl,
    ).login(email: email, password: password);

    final payload = data['data'] as Map<String, dynamic>;
    _token = payload['token'] as String;
    _user = (payload['user'] as Map).cast<String, dynamic>();

    await _storage.write(key: 'token', value: _token);
    await _persistUser();

    notifyListeners();
  }

  Future<void> completePasswordChange({required String password}) async {
    final data = await client.changePassword(password: password);
    final payload = data['data'] as Map<String, dynamic>;

    _apiPassword = password;
    _user = (payload['user'] as Map).cast<String, dynamic>();

    await _storage.write(key: 'api_password', value: _apiPassword);
    await _persistUser();
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    await _storage.write(
      key: 'biometric_enabled',
      value: value ? 'true' : 'false',
    );
    notifyListeners();
  }

  Future<bool> canUseBiometrics() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();
    return canCheck && isSupported;
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Autentique-se para entrar rapidamente no WireDevelop',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> loginWithCachedCredentials() async {
    await login(baseUrl: _baseUrl, email: _apiEmail, password: _apiPassword);
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
    await _storage.delete(key: 'user_payload');
    notifyListeners();
  }

  Future<void> _persistUser() async {
    await _storage.write(key: 'user_name', value: _user?['name']?.toString());
    await _storage.write(key: 'user_email', value: _user?['email']?.toString());
    await _storage.write(
      key: 'user_payload',
      value: jsonEncode(_user ?? <String, dynamic>{}),
    );
  }
}
