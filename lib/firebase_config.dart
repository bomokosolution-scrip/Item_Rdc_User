import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;

/// Configuration Firebase pour le Web (Chrome). Sur Android / iOS, la
/// configuration vient de `android/app/google-services.json`
/// (et `GoogleService-Info.plist` sur iOS).
const FirebaseOptions webFirebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyAHFxyylSmPt0WaJmo4vMi9vMl2kicTdQ4",
  authDomain: "item-rdc-a5678.firebaseapp.com",
  projectId: "item-rdc-a5678",
  storageBucket: "item-rdc-a5678.firebasestorage.app",
  messagingSenderId: "601575313244",
  appId: "1:601575313244:web:a325444bbaf5eb7ae83b99",
);

/// Initialise Firebase une seule fois, sans jamais bloquer le démarrage.
Future<void> initFirebase() async {
  try {
    if (Firebase.apps.isNotEmpty) return;
    // Web, Windows et Linux : pas de google-services.json => on utilise les options.
    final useOptions = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    if (useOptions) {
      await Firebase.initializeApp(options: webFirebaseOptions);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }
}
