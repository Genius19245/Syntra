import 'package:flutter/material.dart';

import '../../screens/auth/sign_in_screen.dart';
import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../auth_service.dart';
import 'admin_link.dart';

/// Compact, skippable sign-in control for landing and intake top bars.
///
/// Always visible — including when Firebase is unconfigured — so Sign in
/// is findable. Tapping opens the full Sign in / Sign up page.
class SignInBar extends StatelessWidget {
  const SignInBar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    final user = auth?.currentUser;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AdminLink(),
        TextButton(
          onPressed: () => openSignInPage(context, auth: auth),
          style: TextButton.styleFrom(
            foregroundColor: SyntraPalette.navy,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                user == null ? Icons.person_outline_rounded : Icons.person_rounded,
                size: 18,
                color: SyntraPalette.navy,
              ),
              const SizedBox(width: 6),
              Text(
                user?.label ?? 'Sign in',
                style: SyntraTheme.sans(
                  color: SyntraPalette.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
