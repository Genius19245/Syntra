import 'package:flutter_test/flutter_test.dart';
import 'package:syntra_app/auth/auth_service.dart';
import 'package:syntra_app/auth/auth_user.dart';
import 'package:syntra_app/auth/fake_auth_service.dart';
import 'package:syntra_app/auth/noop_auth_service.dart';
import 'package:syntra_app/history/history_keys.dart';

void main() {
  test('NoopAuthService stays a signed-out guest', () async {
    final auth = NoopAuthService();

    expect(auth.isConfigured, isFalse);
    expect(auth.isAdmin, isFalse);
    expect(AuthService.unconfiguredHint, 'Add firebase.defines.json');
    expect(auth.isSignedIn, isFalse);
    expect(auth.currentUser, isNull);
    expect(auth.historyNamespace, AuthService.guestNamespace);

    await auth.signInWithGoogle();
    await auth.signInAnonymously();
    await auth.signInWithEmail('a@b.co', 'secret1');

    expect(auth.isSignedIn, isFalse);
    expect(auth.historyNamespace, 'guest');
    expect(
      HistoryKeys.forService(auth),
      'guest/syntra.lesson_history.v1',
    );
  });

  test('FakeAuthService signs in and namespaces history by uid', () async {
    final auth = FakeAuthService();

    expect(auth.isConfigured, isTrue);
    expect(auth.historyNamespace, 'guest');

    await auth.signInAnonymously();
    expect(auth.isSignedIn, isTrue);
    expect(auth.currentUser!.isAnonymous, isTrue);
    expect(auth.historyNamespace, 'anon-test-uid');
    expect(
      HistoryKeys.forService(auth),
      'anon-test-uid/syntra.lesson_history.v1',
    );

    await auth.signOut();
    expect(auth.isSignedIn, isFalse);
    expect(auth.historyNamespace, 'guest');

    await auth.signInWithGoogle();
    expect(auth.currentUser!.uid, 'google-test-uid');
    expect(auth.currentUser!.email, 'teacher@school.test');
    expect(
      HistoryKeys.forService(auth),
      'google-test-uid/syntra.lesson_history.v1',
    );

    await auth.signInWithEmail('lead@school.test', 'secret1');
    expect(auth.historyNamespace, 'email-test-uid');
    expect(auth.currentUser!.email, 'lead@school.test');
  });

  test('FakeAuthService no-ops when not configured', () async {
    final auth = FakeAuthService(configured: false);

    await auth.signInWithGoogle();
    expect(auth.isSignedIn, isFalse);
    expect(auth.historyNamespace, AuthService.guestNamespace);
  });

  test('FakeAuthService surfaces AuthFailure', () async {
    final auth = FakeAuthService(failWith: 'denied');

    expect(
      auth.signInWithGoogle(),
      throwsA(isA<AuthFailure>().having((e) => e.message, 'message', 'denied')),
    );
  });

  test('signed-in user can be injected', () {
    final auth = FakeAuthService(
      user: const AuthUser(uid: 'uid-99', displayName: 'Ada'),
    );
    expect(auth.historyNamespace, 'uid-99');
    expect(auth.currentUser!.label, 'Ada');
  });

  test('FakeAuthService isAdmin when email is allowlisted', () {
    final auth = FakeAuthService(
      user: const AuthUser(
        uid: 'admin-uid',
        email: 'shouryakelkar@gmail.com',
      ),
    );
    expect(auth.isSignedIn, isTrue);
    expect(auth.isAdmin, isTrue);
  });

  test('FakeAuthService isAdmin matches allowlist case-insensitively', () {
    final auth = FakeAuthService(
      user: const AuthUser(
        uid: 'admin-uid',
        email: 'ShouryaKelkar@Gmail.com',
      ),
    );
    expect(auth.isAdmin, isTrue);
  });

  test('FakeAuthService isAdmin is false for other emails', () {
    final auth = FakeAuthService(
      user: const AuthUser(
        uid: 'teacher-uid',
        email: 'teacher@school.test',
      ),
    );
    expect(auth.isSignedIn, isTrue);
    expect(auth.isAdmin, isFalse);
  });

  test('FakeAuthService guest is not admin', () {
    final auth = FakeAuthService();
    expect(auth.isSignedIn, isFalse);
    expect(auth.currentUser, isNull);
    expect(auth.isAdmin, isFalse);
  });

  test('anonymous FakeAuthService is not admin', () async {
    final auth = FakeAuthService();
    await auth.signInAnonymously();
    expect(auth.isSignedIn, isTrue);
    expect(auth.isAdmin, isFalse);
  });
}
