import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mesh_background.dart';
import '../../widgets/syntra_button.dart';
import '../../widgets/syntra_shell.dart';

/// Pushes the full-page Sign in / Sign up screen.
Future<void> openSignInPage(BuildContext context, {AuthService? auth}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          SignInScreen(auth: auth),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

/// Full-page email/password sign-in. Visible even when Firebase is unconfigured.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.auth});

  final AuthService? auth;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.auth?.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.auth?.removeListener(_refresh);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  AuthService? _service(BuildContext context) {
    return widget.auth ?? AuthScope.maybeOf(context);
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function(AuthService auth) action,
  ) async {
    final auth = _service(context);
    if (auth == null || !auth.isConfigured) {
      setState(() => _error = AuthService.unconfiguredHint);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(auth);
      if (!mounted) return;
      if (Navigator.of(this.context).canPop()) {
        Navigator.of(this.context).pop();
      } else {
        setState(() => _busy = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  void _submitEmail(
    BuildContext context, {
    required bool create,
  }) {
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
      context,
      (auth) => create
          ? auth.createEmailAccount(email, password)
          : auth.signInWithEmail(email, password),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = _service(context);
    final signedIn = auth?.isSignedIn ?? false;
    final user = auth?.currentUser;
    final configured = auth?.isConfigured ?? false;

    return Scaffold(
      body: MeshBackground(
        accent: SyntraPalette.rust,
        secondary: SyntraPalette.peach,
        child: SafeArea(
          child: SyntraPageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SyntraTopBar(
                  leading: SyntraBackButton(
                    label: 'Home',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: GlassCard(
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                          child: signedIn
                              ? _AccountBody(
                                  userLabel: user?.label ?? 'Signed in',
                                  isAdmin: auth!.isAdmin,
                                  isAnonymous: user?.isAnonymous ?? false,
                                  busy: _busy,
                                  error: _error,
                                  onSignOut: () => _run(context, (a) => a.signOut()),
                                )
                              : _FormBody(
                                  configured: configured,
                                  busy: _busy,
                                  error: _error,
                                  email: _email,
                                  password: _password,
                                  onSignIn: () =>
                                      _submitEmail(context, create: false),
                                  onSignUp: () =>
                                      _submitEmail(context, create: true),
                                  onGoogle: () => _run(
                                    context,
                                    (a) => a.signInWithGoogle(),
                                  ),
                                  onSkip: _busy
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.configured,
    required this.busy,
    required this.error,
    required this.email,
    required this.password,
    required this.onSignIn,
    required this.onSignUp,
    required this.onGoogle,
    required this.onSkip,
  });

  final bool configured;
  final bool busy;
  final String? error;
  final TextEditingController email;
  final TextEditingController password;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;
  final VoidCallback onGoogle;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sign in / Sign up',
          style: SyntraTheme.sans(
            color: SyntraPalette.navy,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          configured
              ? 'Keep lessons across devices. Skip and continue as a guest — research still runs.'
              : 'Sign in needs Firebase Auth options. ${AuthService.unconfiguredHint} and restart, or skip and continue as a guest.',
          style: SyntraTheme.sans(
            color: SyntraPalette.inkMuted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        if (!configured) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: SyntraPalette.peach.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              AuthService.unconfiguredHint,
              style: SyntraTheme.sans(
                color: SyntraPalette.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 14),
          Text(
            error!,
            style: SyntraTheme.sans(
              color: SyntraPalette.danger,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 22),
        TextField(
          key: const Key('sign-in-email-field'),
          controller: email,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            hintText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('sign-in-password-field'),
          controller: password,
          enabled: !busy,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(
            hintText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        SyntraButton(
          key: const Key('sign-in-submit'),
          label: 'Sign in',
          expand: true,
          enabled: !busy,
          onPressed: onSignIn,
        ),
        const SizedBox(height: 10),
        SyntraButton(
          key: const Key('sign-up-submit'),
          label: 'Sign up',
          filled: false,
          expand: true,
          enabled: !busy,
          onPressed: onSignUp,
        ),
        const SizedBox(height: 10),
        SyntraButton(
          label: 'Continue with Google',
          icon: Icons.login_rounded,
          filled: false,
          expand: true,
          enabled: !busy,
          onPressed: onGoogle,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onSkip,
            child: const Text('Skip for now'),
          ),
        ),
      ],
    );
  }
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({
    required this.userLabel,
    required this.isAdmin,
    required this.isAnonymous,
    required this.busy,
    required this.error,
    required this.onSignOut,
  });

  final String userLabel;
  final bool isAdmin;
  final bool isAnonymous;
  final bool busy;
  final String? error;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final detail = isAnonymous
        ? 'Anonymous session on this device. Sign in with Google or email to sync.'
        : isAdmin
            ? 'Signed in as $userLabel. Admin by email allowlist — cache stays on the server CLI.'
            : 'Signed in as $userLabel. Lesson history is stored under your account.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: SyntraTheme.sans(
            color: SyntraPalette.navy,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          style: SyntraTheme.sans(
            color: SyntraPalette.inkMuted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          Text(
            error!,
            style: SyntraTheme.sans(
              color: SyntraPalette.danger,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 22),
        SyntraButton(
          label: 'Sign out',
          filled: false,
          expand: true,
          enabled: !busy,
          onPressed: onSignOut,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}
