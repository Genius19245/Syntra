import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syntra_app/app.dart';
import 'package:syntra_app/auth/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});

  testWidgets('intake studio shows SYNTRA landing as a guest', (tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SyntraApp(authService: FakeAuthService(configured: false)));
    await tester.pump();

    expect(find.text('SYNTRA'), findsWidgets);
    expect(find.textContaining('Plan the lesson'), findsOneWidget);
    expect(find.text('Create New Lesson'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Past lessons'), findsWidgets);
    expect(find.text('Coastal landscapes'), findsOneWidget);
    expect(find.text('Preview studio'), findsNothing);
    expect(find.text('Open mock lesson'), findsNothing);
    expect(find.byKey(const ValueKey('landing-open-mock-lesson')), findsNothing);
    expect(find.byKey(const ValueKey('landing-sample-lesson')), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('landing sample card opens coastal slides', (tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      SyntraApp(authService: FakeAuthService(configured: false)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('landing-sample-lesson')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Coasts are energy, rock, and sediment'), findsOneWidget);
    expect(find.textContaining('Slide 1 /'), findsOneWidget);
    expect(find.textContaining('Hold the three photos'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
