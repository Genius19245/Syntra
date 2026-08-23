import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syntra_app/app.dart';
import 'package:syntra_app/auth/auth_service.dart';
import 'package:syntra_app/auth/fake_auth_service.dart';
import 'package:syntra_app/auth/noop_auth_service.dart';
import 'package:syntra_app/screens/auth/sign_in_screen.dart';
import 'package:syntra_app/theme/syntra_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget wrap(AuthService auth, {Widget? home}) {
    return AuthScope(
      auth: auth,
      child: MaterialApp(
        theme: SyntraTheme.light(),
        home: home ?? SignInScreen(auth: auth),
      ),
    );
  }

  testWidgets('Sign in is findable on landing with Fake auth off', (tester) async {
    await tester.pumpWidget(SyntraApp(authService: FakeAuthService(configured: false)));
    await tester.pump();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Past lessons'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Sign in is findable on landing with Noop auth', (tester) async {
    await tester.pumpWidget(SyntraApp(authService: NoopAuthService()));
    await tester.pump();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Past lessons'), findsWidgets);
    expect(find.text('Create New Lesson'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('unconfigured Sign in page shows hint and email form', (tester) async {
    final auth = FakeAuthService(configured: false);

    await tester.pumpWidget(wrap(auth));
    await tester.pump();

    expect(find.text('Sign in / Sign up'), findsOneWidget);
    expect(find.text(AuthService.unconfiguredHint), findsWidgets);
    expect(find.byKey(const Key('sign-in-email-field')), findsOneWidget);
    expect(find.byKey(const Key('sign-in-password-field')), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('landing Sign in opens the email form when Auth is off', (tester) async {
    await tester.pumpWidget(SyntraApp(authService: NoopAuthService()));
    await tester.pump();

    await tester.tap(find.text('Sign in').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sign in / Sign up'), findsOneWidget);
    expect(find.text(AuthService.unconfiguredHint), findsWidgets);
    expect(find.byKey(const Key('sign-in-email-field')), findsOneWidget);
    expect(find.byKey(const Key('sign-in-password-field')), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('configured email sign-in updates the fake user', (tester) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(wrap(auth));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('sign-in-email-field')), 'lead@school.test');
    await tester.enterText(find.byKey(const Key('sign-in-password-field')), 'secret1');
    await tester.tap(find.byKey(const Key('sign-in-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.isSignedIn, isTrue);
    expect(auth.currentUser!.email, 'lead@school.test');
    expect(auth.isAdmin, isFalse);
  });

  testWidgets('isAdmin is true only for the allowlisted email', (tester) async {
    final admin = FakeAuthService(
      user: const AuthUser(
        uid: 'admin-uid',
        email: 'shouryakelkar@gmail.com',
      ),
    );
    final other = FakeAuthService(
      user: const AuthUser(
        uid: 'teacher-uid',
        email: 'teacher@school.test',
      ),
    );
    final guest = NoopAuthService();

    expect(admin.isAdmin, isTrue);
    expect(other.isAdmin, isFalse);
    expect(guest.isAdmin, isFalse);

    await tester.pumpWidget(SyntraApp(authService: admin));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Admin'), findsOneWidget);

    await tester.pumpWidget(SyntraApp(authService: other));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Admin'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
