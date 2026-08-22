import 'dart:ui';

import 'package:flutter/material.dart';

import 'screens/intake/intake_studio_screen.dart';
import 'theme/syntra_theme.dart';

void main() {
  runApp(const SyntraApp());
}

class SyntraApp extends StatelessWidget {
  const SyntraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
