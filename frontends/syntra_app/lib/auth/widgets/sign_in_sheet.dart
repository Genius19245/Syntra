import 'package:flutter/material.dart';

import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../../widgets/syntra_button.dart';
import '../auth_service.dart';

Future<void> showSignInSheet(
  BuildContext context, {
  AuthService? auth,
}) {
  final service = auth ?? AuthScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SignInSheet(auth: service),
      );
    },
  );
}

class SignInSheet extends StatefulWidget {
  const SignInSheet({super.key, required this.auth});

  final AuthService auth;

  @override
  State<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<SignInSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _error;

  AuthService get _auth => widget.auth;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _auth.isSignedIn;
    final user = _auth.currentUser;

    return Material(
      color: SyntraPalette.paper,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SyntraPalette.strokeStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              signedIn ? 'Account' : 'Keep lessons across devices',
              style: SyntraTheme.sans(
                color: SyntraPalette.navy,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              signedIn
                  ? (user?.isAnonymous == true
                      ? 'Anonymous session on this device. Sign in with Google or email to sync.'
                      : _auth.isAdmin
                          ? 'Signed in as ${user?.label}. Admin by email allowlist — cache stays on the server CLI.'
                          : 'Signed in as ${user?.label}. Lesson history is stored under your account.')
                  : 'Optional. Skip and continue as a guest — research still runs.',
              style: SyntraTheme.sans(
                color: SyntraPalette.inkMuted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: SyntraTheme.sans(
                  color: SyntraPalette.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (signedIn)
              SyntraButton(
                label: 'Sign out',
                filled: false,
                expand: true,
                enabled: !_busy,
                onPressed: () => _run(_auth.signOut),
              )
            else ...[
              if (_auth.supportsGoogle) ...[
                SyntraButton(
                  label: 'Continue with Google',
                  icon: Icons.login_rounded,
                  expand: true,
                  enabled: !_busy,
                  onPressed: () => _run(_auth.signInWithGoogle),
                ),
                const SizedBox(height: 12),
              ],
              if (_auth.supportsEmail) ...[
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SyntraButton(
                  label: _creating ? 'Create account' : 'Sign in with email',
                  filled: false,
                  expand: true,
                  enabled: !_busy,
                  onPressed: () {
                    final email = _email.text.trim();
                    final password = _password.text;
                    if (email.isEmpty || !email.contains('@')) {
                      setState(() => _error = 'Enter a valid email.');
                      return;
                    }
                    if (password.length < 6) {
                      setState(() => _error = 'Password must be at least 6 characters.');
                      return;
                    }
                    _run(
                      () => _creating
                          ? _auth.createEmailAccount(email, password)
                          : _auth.signInWithEmail(email, password),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _creating = !_creating),
                    child: Text(
                      _creating
                          ? 'Have an account? Sign in'
                          : 'Need an account? Create one',
                    ),
                  ),
                ),
              ],
              if (_auth.supportsAnonymous) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(_auth.signInAnonymously),
                  child: const Text('Continue anonymously'),
                ),
              ],
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(signedIn ? 'Close' : 'Skip — continue as guest'),
            ),
          ],
        ),
      ),
    );
  }
}
