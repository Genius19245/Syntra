import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/auth_bootstrap.dart';
import 'auth/firebase_config.dart';
import 'auth/firebase_options_stub.dart' as stub;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Auth is optional. Options come from:
  // 1. --dart-define-from-file=firebase.defines.json (preferred; see README)
  // 2. gitignored lib/firebase_options.dart assigned to FirebaseConfig.localOptions
  //    (FlutterFire output — do not commit; hook locally as in README Option B)
  // The committed stub is always null. Missing options still boot the app.
  FirebaseConfig.localOptions ??= stub.DefaultFirebaseOptions.currentPlatformOrNull;

  final auth = await bootstrapAuth();
  runApp(SyntraApp(authService: auth));
}
