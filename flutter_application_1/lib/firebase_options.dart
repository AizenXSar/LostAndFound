import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration options for the current platform.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // These values are derived from android/app/google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDh8jdzUAz16X7YJz4Zut6zFU9I-0isQBU',
    appId: '1:782422210889:android:e051f951fecfd8746fc298',
    messagingSenderId: '782422210889',
    projectId: 'lostandfound-4e45a',
    storageBucket: 'lostandfound-4e45a.firebasestorage.app',
  );

  // Placeholders for other platforms in case you add them later
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'IOS_API_KEY',
    appId: 'IOS_APP_ID',
    messagingSenderId: '782422210889',
    projectId: 'lostandfound-4e45a',
    storageBucket: 'lostandfound-4e45a.firebasestorage.app',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'MACOS_API_KEY',
    appId: 'MACOS_APP_ID',
    messagingSenderId: '782422210889',
    projectId: 'lostandfound-4e45a',
    storageBucket: 'lostandfound-4e45a.firebasestorage.app',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'WEB_OR_WIN_API_KEY',
    appId: 'WEB_OR_WIN_APP_ID',
    messagingSenderId: '782422210889',
    projectId: 'lostandfound-4e45a',
    storageBucket: 'lostandfound-4e45a.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'WEB_API_KEY',
    appId: 'WEB_APP_ID',
    messagingSenderId: '782422210889',
    projectId: 'lostandfound-4e45a',
    authDomain: 'lostandfound-4e45a.firebaseapp.com',
    storageBucket: 'lostandfound-4e45a.firebasestorage.app',
  );
}
