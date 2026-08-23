/// Stub so the app runs as a guest when Auth is not configured.
///
/// `lib/firebase_options.dart` is gitignored (FlutterFire output). Do not
/// commit that file, `google-services.json`, or `GoogleService-Info.plist`.
///
/// Enable Auth locally (see README):
/// 1. `--dart-define` / `--dart-define-from-file=firebase.defines.json`
///    (`./scripts/dev.sh` passes this when the file exists)
/// 2. Generate gitignored `lib/firebase_options.dart` and assign
///    `FirebaseConfig.localOptions` in `main.dart` (do not commit).
library;

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  /// Always null in the committed stub — Auth stays off.
  static FirebaseOptions? get currentPlatformOrNull => null;
}
