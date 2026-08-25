import 'auth_service.dart';

/// Signed-out guest used when Firebase Auth is not configured.
///
/// Sign-in methods are no-ops so the intake and research pipeline still run.
class NoopAuthService extends AuthService {
  @override
  AuthUser? get currentUser => null;

  @override
  bool get isConfigured => false;

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithEmail(String email, String password) async {}

  @override
  Future<void> createEmailAccount(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}
