import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syntra_app/app.dart';
import 'package:syntra_app/auth/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('intake studio shows SYNTRA landing as a guest', (tester) async {
    await tester.pumpWidget(SyntraApp(authService: FakeAuthService(configured: false)));
    await tester.pump();

    expect(find.text('SYNTRA'), findsWidgets);
    expect(find.textContaining('Plan the lesson'), findsOneWidget);
    expect(find.text('Create New Lesson'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Past lessons'), findsWidgets);
    expect(find.text('Preview studio'), findsNothing);
    expect(find.text('Open mock lesson'), findsNothing);
    expect(find.byKey(const ValueKey('landing-open-mock-lesson')), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
