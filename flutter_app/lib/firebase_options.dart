import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class WireFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _android;
      case TargetPlatform.iOS:
        return _ios;
      default:
        return null;
    }
  }

  static FirebaseOptions? get _android {
    const appId = String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: '',
    );
    const apiKey = String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: '',
    );
    const projectId = String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: '',
    );
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    );

    if (appId.isEmpty ||
        apiKey.isEmpty ||
        projectId.isEmpty ||
        messagingSenderId.isEmpty) {
      return null;
    }

    return const FirebaseOptions(
      appId: appId,
      apiKey: apiKey,
      projectId: projectId,
      messagingSenderId: messagingSenderId,
      storageBucket: String.fromEnvironment(
        'FIREBASE_STORAGE_BUCKET',
        defaultValue: '',
      ),
    );
  }

  static FirebaseOptions? get _ios {
    const appId = String.fromEnvironment(
      'FIREBASE_IOS_APP_ID',
      defaultValue: '',
    );
    const apiKey = String.fromEnvironment(
      'FIREBASE_IOS_API_KEY',
      defaultValue: '',
    );
    const projectId = String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: '',
    );
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    );

    if (appId.isEmpty ||
        apiKey.isEmpty ||
        projectId.isEmpty ||
        messagingSenderId.isEmpty) {
      return null;
    }

    return const FirebaseOptions(
      appId: appId,
      apiKey: apiKey,
      projectId: projectId,
      messagingSenderId: messagingSenderId,
      iosBundleId: String.fromEnvironment(
        'FIREBASE_IOS_BUNDLE_ID',
        defaultValue: 'com.wiredevelop.wirecrmapp',
      ),
      iosClientId: String.fromEnvironment(
        'FIREBASE_IOS_CLIENT_ID',
        defaultValue: '',
      ),
      storageBucket: String.fromEnvironment(
        'FIREBASE_STORAGE_BUCKET',
        defaultValue: '',
      ),
    );
  }
}
