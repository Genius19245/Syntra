import 'auth_service.dart';

/// In-memory AuthService for widget and unit tests.
class FakeAuthService extends AuthService {
  FakeAuthService({
    AuthUser? user,
    this.configured = true,
    this.anonymous = true,
    this.google = true,
    this.email = true,
    this.failWith,
  }) : _user = user;

  AuthUser? _user;
  bool configured;
  bool anonymous;
  bool google;
  bool email;
  String? failWith;

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isConfigured => configured;

  @override
  bool get supportsAnonymous => configured && anonymous;

  @override
  bool get supportsGoogle => configured && google;

  @override
  bool get supportsEmail => configured && email;

  void _guard() {
    if (!configured) return;
    final message = failWith;
    if (message != null) throw AuthFailure(message);
  }

  void _setUser(AuthUser? user) {
    _user = user;
    notifyListeners();
  }

  @override
  Future<void> signInAnonymously() async {
    if (!supportsAnonymous) return;
    _guard();
    _setUser(
      const AuthUser(uid: 'anon-test-uid', isAnonymous: true),
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    if (!supportsGoogle) return;
    _guard();
    _setUser(
      const AuthUser(
        uid: 'google-test-uid',
        email: 'teacher@school.test',
        displayName: 'Test Teacher',
      ),
    );
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    if (!supportsEmail) return;
    _guard();
    _setUser(
      AuthUser(
        uid: 'email-test-uid',
        email: email.trim(),
      ),
    );
  }

  @override
  Future<void> createEmailAccount(String email, String password) async {
    await signInWithEmail(email, password);
  }

  @override
  Future<void> signOut() async {
    _setUser(null);
  }
}
