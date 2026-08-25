import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syntra_app/app.dart';
import 'package:syntra_app/auth/auth_service.dart';
import 'package:syntra_app/auth/fake_auth_service.dart';
import 'package:syntra_app/auth/widgets/sign_in_sheet.dart';
import 'package:syntra_app/theme/syntra_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget wrap(AuthService auth, {Widget? home}) {
    return AuthScope(
      auth: auth,
      child: MaterialApp(
        theme: SyntraTheme.light(),
        home: home ?? const Scaffold(body: SizedBox()),
      ),
    );
  }

  testWidgets('guest can skip sign-in and stay signed out', (tester) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(
      wrap(
        auth,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showSignInSheet(context, auth: auth),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Keep lessons across devices'), findsOneWidget);
    expect(find.text('Skip — continue as guest'), findsOneWidget);

    await tester.tap(find.text('Skip — continue as guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.isSignedIn, isFalse);
    expect(auth.historyNamespace, 'guest');
    expect(find.text('Keep lessons across devices'), findsNothing);
  });

  testWidgets('Google sign-in updates the fake user', (tester) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(
      wrap(auth, home: Scaffold(body: SignInSheet(auth: auth))),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.currentUser!.uid, 'google-test-uid');
    expect(auth.historyNamespace, 'google-test-uid');
  });

  testWidgets('landing stays usable as guest when Auth is off', (tester) async {
    await tester.pumpWidget(SyntraApp(authService: FakeAuthService(configured: false)));
    await tester.pump();

    expect(find.text('Create New Lesson'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Past lessons'), findsWidgets);
    expect(find.text('Sign in to keep lessons across devices'), findsOneWidget);

    await tester.tap(find.text('Create New Lesson'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('New lesson'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Past lessons'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('configured guest sees skippable sign-in on landing', (tester) async {
    await tester.pumpWidget(SyntraApp(authService: FakeAuthService()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Sign in to keep lessons across devices'), findsOneWidget);
    expect(find.text('Optional — skip and continue as a guest.'), findsOneWidget);
    expect(find.text('Create New Lesson'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
