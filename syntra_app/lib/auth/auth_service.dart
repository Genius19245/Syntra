import 'package:flutter/material.dart';

import 'admin_emails.dart';
import 'auth_user.dart';
export 'auth_user.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sign-in for local profile / lesson history. Never talks to Firestore.
///
/// Research (`research_cache`, RAG, Fact Checker) does not use this service.
abstract class AuthService extends ChangeNotifier {
  static const guestNamespace = 'guest';

  AuthUser? get currentUser;

  bool get isSignedIn => currentUser != null;

  /// True when the signed-in Firebase Auth email is on [AdminEmails.allowlist]
  /// (case-insensitive). Guests and anonymous users are never admin.
  bool get isAdmin => AdminEmails.contains(currentUser?.email);

  /// Shown when Sign in is tapped but Firebase options are missing.
  static const unconfiguredHint = 'Add firebase.defines.json';

  /// True when Firebase options were resolved (dart-define or local file).
  bool get isConfigured;

  bool get supportsAnonymous => isConfigured;
  bool get supportsGoogle => isConfigured;
  bool get supportsEmail => isConfigured;

  /// `guest` when signed out; Firebase uid when signed in.
  String get historyNamespace => namespaceForUid(currentUser?.uid);

  static String namespaceForUid(String? uid) {
    final value = uid?.trim() ?? '';
    return value.isEmpty ? guestNamespace : value;
  }

  Future<void> signInAnonymously();

  Future<void> signInWithGoogle();

  Future<void> signInWithEmail(String email, String password);

  Future<void> createEmailAccount(String email, String password);

  Future<void> signOut();
}

class AuthScope extends InheritedNotifier<AuthService> {
  const AuthScope({
    super.key,
    required AuthService auth,
    required super.child,
  }) : super(notifier: auth);

  static AuthService of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw StateError('AuthScope not found. Wrap the tree with SyntraApp.');
    }
    return scope;
  }

  static AuthService? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
  }

  /// True when the current Auth email is on the admin allowlist.
  static bool isAdmin(BuildContext context) {
    return maybeOf(context)?.isAdmin ?? false;
  }
}
