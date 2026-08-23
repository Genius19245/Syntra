import 'dart:ui';

import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'auth/noop_auth_service.dart';
import 'screens/intake/intake_studio_screen.dart';
import 'theme/syntra_theme.dart';

class SyntraApp extends StatelessWidget {
  SyntraApp({super.key, AuthService? authService})
      : authService = authService ?? NoopAuthService();

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: authService,
      child: MaterialApp(
        title: 'SYNTRA',
        debugShowCheckedModeBanner: false,
        theme: SyntraTheme.light(),
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        home: const IntakeStudioScreen(),
      ),
    );
  }
}
