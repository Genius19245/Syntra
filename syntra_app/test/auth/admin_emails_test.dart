import 'package:flutter_test/flutter_test.dart';
import 'package:syntra_app/auth/admin_emails.dart';

void main() {
  test('default allowlist includes the admin identifier email', () {
    expect(AdminEmails.allowlist, contains('shouryakelkar@gmail.com'));
    expect(AdminEmails.contains('shouryakelkar@gmail.com'), isTrue);
    expect(AdminEmails.contains('ShouryaKelkar@Gmail.com'), isTrue);
    expect(AdminEmails.contains('  shouryakelkar@gmail.com  '), isTrue);
  });

  test('other emails and empty values are not admin', () {
    expect(AdminEmails.contains('teacher@school.test'), isFalse);
    expect(AdminEmails.contains(null), isFalse);
    expect(AdminEmails.contains(''), isFalse);
    expect(AdminEmails.contains('   '), isFalse);
  });

  test('parse splits comma-separated emails', () {
    expect(
      AdminEmails.parse('shouryakelkar@gmail.com, Other@School.test'),
      ['shouryakelkar@gmail.com', 'other@school.test'],
    );
    expect(AdminEmails.parse(''), isEmpty);
    expect(AdminEmails.parse('  ,  '), isEmpty);
  });
}
