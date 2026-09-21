import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD-xEjxWySz4ZV4Natb_8fjHSm8l3Sh5_w',
    appId: '1:709594394959:web:09b1459f0fa9508b7c153a',
    messagingSenderId: '709594394959',
    projectId: 'tindahan-ni-eca-app',
    authDomain: 'tindahan-ni-eca-app.firebaseapp.com',
    storageBucket: 'tindahan-ni-eca-app.firebasestorage.app',
    measurementId: 'G-4LV2PDV3NC',
    databaseURL: 'https://tindahan-ni-eca-app-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAkPm_c-56XbbBrDyGRDhTMXFL3HBbCWzI',
    appId: '1:709594394959:android:2bd5f4e63b9bf2327c153a',
    messagingSenderId: '709594394959',
    projectId: 'tindahan-ni-eca-app',
    storageBucket: 'tindahan-ni-eca-app.firebasestorage.app',
    databaseURL: 'https://tindahan-ni-eca-app-default-rtdb.firebaseio.com',
  );
}
