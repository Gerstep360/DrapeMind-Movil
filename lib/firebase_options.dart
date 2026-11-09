// File generated for DrapeMind Firebase Configuration
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para esta plataforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAx9E3JCUs-gBY8cB_cnuMb-4cDkg57Zdk',
    appId: '1:81465683436:android:63b6ae7aaf39913c33a4c9',
    messagingSenderId: '81465683436',
    projectId: 'drapemind-5bd6e',
    storageBucket: 'drapemind-5bd6e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAx9E3JCUs-gBY8cB_cnuMb-4cDkg57Zdk',
    appId: '1:81465683436:ios:63b6ae7aaf39913c33a4c9',
    messagingSenderId: '81465683436',
    projectId: 'drapemind-5bd6e',
    storageBucket: 'drapemind-5bd6e.firebasestorage.app',
    iosBundleId: 'com.drapemind.drapemindMobile',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAx9E3JCUs-gBY8cB_cnuMb-4cDkg57Zdk',
    appId: '1:81465683436:web:63b6ae7aaf39913c33a4c9',
    messagingSenderId: '81465683436',
    projectId: 'drapemind-5bd6e',
    storageBucket: 'drapemind-5bd6e.firebasestorage.app',
  );
}

