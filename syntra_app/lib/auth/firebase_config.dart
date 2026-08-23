import 'package:firebase_core/firebase_core.dart';

import 'firebase_options_stub.dart';

/// Resolves Firebase options without requiring a committed `firebase_options.dart`.
///
/// Order: `--dart-define-from-file=firebase.defines.json`, then
/// [localOptions] (gitignored `lib/firebase_options.dart` hooked in `main.dart`),
/// then the committed stub (always null).
///
/// Flutter never uses these options to open Firestore. `research_cache` stays
/// Admin-only (deny-all for clients).
abstract final class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  static const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');

  /// Set from local `main.dart` after generating gitignored `firebase_options.dart`.
  static FirebaseOptions? localOptions;

  static bool get hasDartDefines =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      projectId.isNotEmpty &&
      messagingSenderId.isNotEmpty;

  static FirebaseOptions? fromDartDefines() {
    if (!hasDartDefines) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }

  static FirebaseOptions? resolve() {
    return fromDartDefines() ??
        localOptions ??
        DefaultFirebaseOptions.currentPlatformOrNull;
  }
}
