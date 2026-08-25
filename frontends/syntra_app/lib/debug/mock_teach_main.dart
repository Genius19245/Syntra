import 'package:flutter/material.dart';

import 'mock_lesson.dart';

/// Standalone entry for the teaching studio with mock data.
///
/// ```
/// cd frontends/syntra_app && flutter run -d chrome -t lib/debug/mock_teach_main.dart
/// ```
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(mockTeachApp());
}
