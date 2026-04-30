import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'api_client.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final options = WireFirebaseOptions.currentPlatform;
  if (options == null) {
    return;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<Uri> _launchStream = StreamController<Uri>.broadcast();

  Future<void> Function()? _tokenRefreshSync;
  Uri? _initialUri;
  bool _initialized = false;

  Stream<Uri> get launchStream => _launchStream.stream;
  bool get isConfigured => WireFirebaseOptions.currentPlatform != null;

  Future<void> initialize() async {
    if (_initialized || !isConfigured) {
      return;
    }

    await Firebase.initializeApp(options: WireFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    await _initializeLocalNotifications();
    await _captureInitialNotificationLaunch();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      final callback = _tokenRefreshSync;
      if (callback != null) {
        unawaited(callback());
      }
    });

    _initialized = true;
  }

  void bindTokenRefreshSync(Future<void> Function() callback) {
    _tokenRefreshSync = callback;
  }

  Uri? consumeInitialUri() {
    final uri = _initialUri;
    _initialUri = null;
    return uri;
  }

  Future<void> syncDeviceRegistration(ApiClient client) async {
    if (!isConfigured) {
      return;
    }

    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final granted =
        permission.authorizationStatus == AuthorizationStatus.authorized ||
        permission.authorizationStatus == AuthorizationStatus.provisional;

    if (!granted) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await client.post(
      '/notifications/devices',
      body: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'device_name': Platform.operatingSystem,
        'locale': WidgetsBinding.instance.platformDispatcher.locale
            .toLanguageTag(),
        'notifications_enabled': true,
      },
    );
  }

  Future<void> unregisterDevice(ApiClient client) async {
    if (!isConfigured) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await client.delete('/notifications/devices', body: {'token': token});
  }

  Future<void> _initializeLocalNotifications() async {
    const channel = AndroidNotificationChannel(
      'wire_crm_updates',
      'Wire CRM Updates',
      description: 'Notificações operacionais do Wire CRM.',
      importance: Importance.max,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(channel);

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );
  }

  Future<void> _captureInitialNotificationLaunch() async {
    final localLaunch = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (localLaunch?.didNotificationLaunchApp == true) {
      final payload = localLaunch?.notificationResponse?.payload;
      final uri = _uriFromPayload(payload);
      if (uri != null) {
        _initialUri = uri;
      }
    }

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    final initialUriFromMessage = _uriFromMessage(initialMessage);
    if (initialUriFromMessage != null) {
      _initialUri = initialUriFromMessage;
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    await _localNotifications.show(
      id: message.messageId.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'wire_crm_updates',
          'Wire CRM Updates',
          channelDescription: 'Notificações operacionais do Wire CRM.',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['deep_link']?.toString(),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final uri = _uriFromMessage(message);
    if (uri != null) {
      _launchStream.add(uri);
    }
  }

  void _handlePayload(String? payload) {
    final uri = _uriFromPayload(payload);
    if (uri != null) {
      _launchStream.add(uri);
    }
  }

  Uri? _uriFromMessage(RemoteMessage? message) {
    if (message == null) {
      return null;
    }

    return _uriFromPayload(message.data['deep_link']?.toString());
  }

  Uri? _uriFromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }

    return Uri.tryParse(payload.trim());
  }
}
