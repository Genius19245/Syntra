import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Firebase Auth only. Does not import `cloud_firestore`.
///
/// Google Sign-In is OAuth (`signInWithPopup` / `signInWithProvider`).
/// This client never stores a Google password. Email/password uses
/// Firebase `signInWithEmailAndPassword` — do not hardcode credentials.
///
/// Do not grant this client read/write on `syntra/**/research_cache`.
class FirebaseAuthService extends AuthService {
  FirebaseAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance {
    _user = _map(_auth.currentUser);
    _sub = _auth.authStateChanges().listen((user) {
      _user = _map(user);
      notifyListeners();
    });
  }

  final FirebaseAuth _auth;
  StreamSubscription<User?>? _sub;
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isConfigured => true;

  @override
  Future<void> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_message(error));
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(provider);
      } else {
        await _auth.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_message(error));
    } catch (error) {
      throw AuthFailure(error.toString());
    }
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_message(error));
    }
  }

  @override
  Future<void> createEmailAccount(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_message(error));
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  AuthUser? _map(User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      isAnonymous: user.isAnonymous,
    );
  }

  String _message(FirebaseAuthException error) {
    return error.message?.trim().isNotEmpty == true
        ? error.message!
        : error.code;
  }
}
