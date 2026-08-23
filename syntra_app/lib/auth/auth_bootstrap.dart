import 'package:firebase_core/firebase_core.dart';

import 'auth_service.dart';
import 'firebase_auth_service.dart';
import 'firebase_config.dart';
import 'noop_auth_service.dart';

/// Starts Auth off the research hot path.
///
/// If options are missing or init fails, returns a signed-out guest so
/// intake and the pipeline still run. The Sign in UI stays visible either way.
Future<AuthService> bootstrapAuth() async {
  final options = FirebaseConfig.resolve();
  if (options == null) {
    return NoopAuthService();
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }
    return FirebaseAuthService();
  } catch (_) {
    return NoopAuthService();
  }
}
