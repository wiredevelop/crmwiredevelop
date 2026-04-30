import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'services/api_client.dart';
import 'services/widget_sync_service.dart';

class WalletCheckoutReturn {
  const WalletCheckoutReturn({
    required this.status,
    required this.target,
    this.sessionId,
    this.token,
  });

  final String status;
  final String target;
  final String? sessionId;
  final String? token;

  bool get isSuccess => status == 'success';
  bool get isCancel => status == 'cancel';
}

class AppNavigationRequest {
  const AppNavigationRequest({
    required this.route,
    this.module,
    this.clientId,
    this.status,
  });

  final String route;
  final String? module;
  final String? clientId;
  final String? status;
}

class AppController extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _baseUrlKey = 'base_url';
  static const String _apiEmailKey = 'api_email';
  static const String _apiPasswordKey = 'api_password';
  static const String _tokenKey = 'token';
  static const String _userPayloadKey = 'user_payload';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricAccountKey = 'biometric_account_key';

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
  String? _biometricAssociation;
  WalletCheckoutReturn? _pendingWalletCheckoutReturn;
  int _walletCheckoutReturnVersion = 0;
  String? _pendingHomeShortcut;
  int _homeShortcutVersion = 0;
  AppNavigationRequest? _pendingNavigationRequest;
  int _navigationRequestVersion = 0;

  bool get isReady => _isReady;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  String get baseUrl => _baseUrl;
  String get apiEmail => _apiEmail;
  String get apiPassword => _apiPassword;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get biometricEnabled => _biometricEnabled;
  bool get hasCachedCredentials =>
      _apiEmail.trim().isNotEmpty && _apiPassword.isNotEmpty;
  bool get hasBiometricQuickLogin =>
      _biometricEnabled &&
      hasCachedCredentials &&
      (_biometricAssociation?.isNotEmpty ?? false);
  bool get mustChangePassword => _user?['must_change_password'] == true;
  bool get isClientUser => _user?['role'] == 'client';
  WalletCheckoutReturn? get pendingWalletCheckoutReturn =>
      _pendingWalletCheckoutReturn;
  int get walletCheckoutReturnVersion => _walletCheckoutReturnVersion;
  int get homeShortcutVersion => _homeShortcutVersion;
  int get navigationRequestVersion => _navigationRequestVersion;

  ApiClient get client => ApiClient(baseUrl: _baseUrl, token: _token);

  Future<void> initialize() async {
    try {
      final storedBaseUrl = await _storage.read(key: _baseUrlKey);

      _baseUrl = normalizeBaseUrl(
        storedBaseUrl == legacyBaseUrl
            ? defaultBaseUrl
            : (storedBaseUrl ?? _baseUrl),
      );
      _apiEmail = (await _storage.read(key: _apiEmailKey)) ?? _apiEmail;
      _apiPassword =
          (await _storage.read(key: _apiPasswordKey)) ?? _apiPassword;
      _token = await _storage.read(key: _tokenKey);
      _biometricEnabled =
          (await _storage.read(key: _biometricEnabledKey)) == 'true';
      _biometricAssociation = await _storage.read(key: _biometricAccountKey);
      final rawUserPayload = await _storage.read(key: _userPayloadKey);
      if (rawUserPayload != null && rawUserPayload.isNotEmpty) {
        final decoded = jsonDecode(rawUserPayload);
        if (decoded is Map<String, dynamic>) {
          _user = decoded;
        }
      } else {
        final rawName = await _storage.read(key: _userNameKey);
        final rawEmail = await _storage.read(key: _userEmailKey);
        if (rawName != null || rawEmail != null) {
          _user = {'name': rawName, 'email': rawEmail};
        }
      }

      if (!hasCachedCredentials || (_biometricAssociation?.isEmpty ?? true)) {
        _biometricEnabled = false;
      }
    } catch (_) {
      await _resetLocalSession();
    }

    _isReady = true;
    notifyListeners();

    if (isAuthenticated && !mustChangePassword) {
      unawaited(refreshWidgetData());
    }
  }

  Future<void> updateBaseUrl(String value) async {
    _baseUrl = normalizeBaseUrl(value);
    await _storage.write(key: _baseUrlKey, value: _baseUrl);
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

    await _storage.write(key: _baseUrlKey, value: _baseUrl);
    await _storage.write(key: _apiEmailKey, value: _apiEmail);
    await _storage.write(key: _apiPasswordKey, value: _apiPassword);
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
    final normalizedBaseUrl = normalizeBaseUrl(baseUrl);
    final normalizedEmail = email.trim();

    final data = await ApiClient(
      baseUrl: normalizedBaseUrl,
    ).login(email: normalizedEmail, password: password);

    final payload = data['data'] as Map<String, dynamic>;
    _baseUrl = normalizedBaseUrl;
    _apiEmail = normalizedEmail;
    _apiPassword = password;
    _token = payload['token'] as String;
    _user = (payload['user'] as Map).cast<String, dynamic>();

    await _storage.write(key: _baseUrlKey, value: _baseUrl);
    await _storage.write(key: _apiEmailKey, value: _apiEmail);
    await _storage.write(key: _apiPasswordKey, value: _apiPassword);
    await _storage.write(key: _tokenKey, value: _token);
    await _persistUser();
    await _syncBiometricAssociation();
    await refreshWidgetData();

    notifyListeners();
  }

  Future<void> completePasswordChange({required String password}) async {
    final data = await client.changePassword(password: password);
    final payload = data['data'] as Map<String, dynamic>;

    _apiPassword = password;
    _user = (payload['user'] as Map).cast<String, dynamic>();

    await _storage.write(key: _apiPasswordKey, value: _apiPassword);
    await _persistUser();
    await _syncBiometricAssociation();
    await refreshWidgetData();
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    await _storage.write(
      key: _biometricEnabledKey,
      value: value ? 'true' : 'false',
    );
    await _syncBiometricAssociation();
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

  void handleIncomingUri(Uri uri) {
    if (uri.scheme != 'wirecrm') {
      return;
    }

    final isWalletReturn =
        uri.host == 'wallet' && uri.path == '/checkout-return';

    if (isWalletReturn) {
      final status = uri.queryParameters['status']?.trim();
      if (status != 'success' && status != 'cancel') {
        return;
      }

      _pendingWalletCheckoutReturn = WalletCheckoutReturn(
        status: status!,
        target: uri.queryParameters['target']?.trim().isNotEmpty == true
            ? uri.queryParameters['target']!.trim()
            : 'wallet',
        sessionId: uri.queryParameters['session_id']?.trim(),
        token: uri.queryParameters['token']?.trim(),
      );
      _walletCheckoutReturnVersion += 1;
      notifyListeners();
      return;
    }

    final navigationRequest = _navigationRequestFromUri(uri);
    if (navigationRequest != null) {
      _pendingNavigationRequest = navigationRequest;
      _navigationRequestVersion += 1;
      notifyListeners();
    }
  }

  WalletCheckoutReturn? consumePendingWalletCheckoutReturn() {
    final pending = _pendingWalletCheckoutReturn;
    _pendingWalletCheckoutReturn = null;
    return pending;
  }

  void queueOpenSecurityShortcut() {
    _pendingHomeShortcut = 'security';
    _homeShortcutVersion += 1;
    notifyListeners();
  }

  String? consumePendingHomeShortcut() {
    final pending = _pendingHomeShortcut;
    _pendingHomeShortcut = null;
    return pending;
  }

  AppNavigationRequest? consumePendingNavigationRequest() {
    final pending = _pendingNavigationRequest;
    _pendingNavigationRequest = null;
    return pending;
  }

  Future<void> logout() async {
    try {
      await client.post('/auth/logout');
    } catch (_) {}

    await _resetLocalSession(
      preserveQuickLogin: _biometricEnabled && hasCachedCredentials,
    );
    await WidgetSyncService.clear();
    notifyListeners();
  }

  Future<void> refreshWidgetData() async {
    if (!isAuthenticated || mustChangePassword) {
      return;
    }

    await WidgetSyncService.sync(client);
  }

  Future<void> _resetLocalSession({bool preserveQuickLogin = false}) async {
    final preservedBaseUrl = _baseUrl;
    final preservedEmail = _apiEmail;
    final preservedPassword = _apiPassword;
    final preservedBiometricEnabled = _biometricEnabled;
    final preservedBiometricAssociation = _biometricAssociation;

    _token = null;
    _user = null;
    _apiEmail = '';
    _apiPassword = '';
    _biometricEnabled = false;
    _biometricAssociation = null;
    _baseUrl = defaultBaseUrl;

    try {
      await _storage.deleteAll();
    } catch (_) {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userNameKey);
      await _storage.delete(key: _userEmailKey);
      await _storage.delete(key: _userPayloadKey);
      await _storage.delete(key: _apiEmailKey);
      await _storage.delete(key: _apiPasswordKey);
      await _storage.delete(key: _baseUrlKey);
      await _storage.delete(key: _biometricEnabledKey);
      await _storage.delete(key: _biometricAccountKey);
    }

    if (preserveQuickLogin) {
      _baseUrl = preservedBaseUrl;
      _apiEmail = preservedEmail;
      _apiPassword = preservedPassword;
      _biometricEnabled = preservedBiometricEnabled;
      _biometricAssociation = preservedBiometricAssociation;

      await _storage.write(key: _baseUrlKey, value: _baseUrl);
      await _storage.write(key: _apiEmailKey, value: _apiEmail);
      await _storage.write(key: _apiPasswordKey, value: _apiPassword);
      await _storage.write(
        key: _biometricEnabledKey,
        value: _biometricEnabled ? 'true' : 'false',
      );
      if (_biometricAssociation != null && _biometricAssociation!.isNotEmpty) {
        await _storage.write(
          key: _biometricAccountKey,
          value: _biometricAssociation,
        );
      }
    }
  }

  Future<void> _persistUser() async {
    await _storage.write(key: _userNameKey, value: _user?['name']?.toString());
    await _storage.write(
      key: _userEmailKey,
      value: _user?['email']?.toString(),
    );
    await _storage.write(
      key: _userPayloadKey,
      value: jsonEncode(_user ?? <String, dynamic>{}),
    );
  }

  Future<void> _syncBiometricAssociation() async {
    if (!_biometricEnabled || !hasCachedCredentials) {
      _biometricAssociation = null;
      await _storage.delete(key: _biometricAccountKey);
      return;
    }

    _biometricAssociation = _accountAssociationKey(
      baseUrl: _baseUrl,
      email: _apiEmail,
      user: _user,
    );
    await _storage.write(
      key: _biometricAccountKey,
      value: _biometricAssociation,
    );
  }

  String _accountAssociationKey({
    required String baseUrl,
    required String email,
    Map<String, dynamic>? user,
  }) {
    final userId = user?['id']?.toString().trim() ?? '';
    final userEmail =
        user?['email']?.toString().trim().toLowerCase() ??
        email.trim().toLowerCase();
    return '${normalizeBaseUrl(baseUrl)}|$userId|$userEmail';
  }

  AppNavigationRequest? _navigationRequestFromUri(Uri uri) {
    switch (uri.host) {
      case 'wallet':
        return const AppNavigationRequest(route: 'wallet');
      case 'wallets':
        return AppNavigationRequest(
          route: 'wallets',
          clientId: uri.queryParameters['client_id']?.trim(),
        );
      case 'invoices':
        return AppNavigationRequest(
          route: 'invoices',
          status: uri.queryParameters['status']?.trim(),
        );
      case 'clients':
        return const AppNavigationRequest(route: 'clients');
      case 'projects':
        return const AppNavigationRequest(route: 'projects');
      case 'objects':
        return const AppNavigationRequest(route: 'objects');
      case 'more':
        final module = uri.queryParameters['module']?.trim();
        if (module == null || module.isEmpty) {
          return const AppNavigationRequest(route: 'more');
        }
        return AppNavigationRequest(route: 'more', module: module);
      default:
        return null;
    }
  }
}
