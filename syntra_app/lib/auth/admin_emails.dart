/// Admin is an email allowlist, not a password.
///
/// Override at build time without committing extra addresses:
/// `--dart-define=SYNTRA_ADMIN_EMAILS=shouryakelkar@gmail.com,other@school.test`
///
/// Emails are identifiers, not secrets. Google Sign-In does not use an
/// app-side password; email/password goes to Firebase Auth only.
abstract final class AdminEmails {
  static const fromEnvironment = String.fromEnvironment(
    'SYNTRA_ADMIN_EMAILS',
    defaultValue: 'shouryakelkar@gmail.com',
  );

  static final List<String> allowlist = parse(fromEnvironment);

  static bool contains(String? email) {
    final normalized = email?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return false;
    return allowlist.contains(normalized);
  }

  static List<String> parse(String raw) {
    return [
      for (final part in raw.split(','))
        if (part.trim().isNotEmpty) part.trim().toLowerCase(),
    ];
  }
}
