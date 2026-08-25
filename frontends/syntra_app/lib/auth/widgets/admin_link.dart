import 'package:flutter/material.dart';

import '../../screens/admin/admin_screen.dart';
import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../auth_service.dart';

/// Discreet Admin entry. Hidden unless [AuthService.isAdmin].
/// Does not query Firestore.
class AdminLink extends StatelessWidget {
  const AdminLink({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    if (auth == null || !auth.isAdmin) {
      return const SizedBox.shrink();
    }

    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AdminScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      style: TextButton.styleFrom(
        foregroundColor: SyntraPalette.inkMuted,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      child: Text(
        'Admin',
        style: SyntraTheme.sans(
          color: SyntraPalette.inkMuted,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
