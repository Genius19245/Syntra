/// Signed-in identity. Guests are represented by a null [AuthService.currentUser].
class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool isAnonymous;

  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    if (isAnonymous) return 'Anonymous';
    return 'Signed in';
  }
}
