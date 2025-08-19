// This file is required for Firebase initialization. Replace the values with your actual Firebase project config.
// To generate this file automatically, run `flutterfire configure` in your project root.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

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
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAPtMqNTcLIexTIVW_KLzd2ZP78Bav4KA0',
    appId: '1:445616630533:web:c904cc3d53b64de62a256c',
    messagingSenderId: '445616630533',
    projectId: 'locoshed-bhusawal-9c5ce',
    authDomain: 'locoshed-bhusawal-9c5ce.firebaseapp.com',
    storageBucket: 'locoshed-bhusawal-9c5ce.firebasestorage.app',
    measurementId: 'G-60ZH9XFE27',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDEFBpozJGQMkYO5-GhrJc1NdIUvRuoCKM',
    appId: '1:445616630533:android:94356b380558ec3e2a256c',
    messagingSenderId: '445616630533',
    projectId: 'locoshed-bhusawal-9c5ce',
    storageBucket: 'locoshed-bhusawal-9c5ce.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
    iosBundleId: 'YOUR_IOS_BUNDLE_ID',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
    iosBundleId: 'YOUR_MACOS_BUNDLE_ID',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAPtMqNTcLIexTIVW_KLzd2ZP78Bav4KA0',
    appId: '1:445616630533:web:c904cc3d53b64de62a256c',
    messagingSenderId: '445616630533',
    projectId: 'locoshed-bhusawal-9c5ce',
    authDomain: 'locoshed-bhusawal-9c5ce.firebaseapp.com',
    storageBucket: 'locoshed-bhusawal-9c5ce.firebasestorage.app',
    measurementId: 'G-60ZH9XFE27',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyAPtMqNTcLIexTIVW_KLzd2ZP78Bav4KA0',
    appId: '1:445616630533:web:c904cc3d53b64de62a256c',
    messagingSenderId: '445616630533',
    projectId: 'locoshed-bhusawal-9c5ce',
    authDomain: 'locoshed-bhusawal-9c5ce.firebaseapp.com',
    storageBucket: 'locoshed-bhusawal-9c5ce.firebasestorage.app',
    measurementId: 'G-60ZH9XFE27',
  );
}
