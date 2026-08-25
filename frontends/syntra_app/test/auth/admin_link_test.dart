import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syntra_app/app.dart';
import 'package:syntra_app/auth/auth_user.dart';
import 'package:syntra_app/auth/fake_auth_service.dart';
import 'package:syntra_app/auth/widgets/admin_link.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('Admin link is hidden for guests', (tester) async {
    await tester.pumpWidget(SyntraApp(authService: FakeAuthService()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AdminLink), findsOneWidget);
    expect(find.text('Admin'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Admin link is hidden for other emails', (tester) async {
    await tester.pumpWidget(
      SyntraApp(
        authService: FakeAuthService(
          user: const AuthUser(
            uid: 'teacher-uid',
            email: 'teacher@school.test',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Admin'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('allowlisted email sees Admin and cache CLI note', (tester) async {
    await tester.pumpWidget(
      SyntraApp(
        authService: FakeAuthService(
          user: const AuthUser(
            uid: 'admin-uid',
            email: 'shouryakelkar@gmail.com',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Admin'), findsOneWidget);

    await tester.tap(find.text('Admin'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('isAdmin'), findsOneWidget);
    expect(find.text('python scripts/cache_hits.py'), findsOneWidget);
    expect(
      find.textContaining('Flutter must not read or write'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
