import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mesh_background.dart';
import '../../widgets/syntra_shell.dart';

/// Ops notes for allowlisted admins. Never reads Firestore `research_cache`.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    final email = auth?.currentUser?.email?.trim();

    return Scaffold(
      body: MeshBackground(
        accent: SyntraPalette.rust,
        secondary: SyntraPalette.peach,
        child: SafeArea(
          child: SyntraPageFrame(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SyntraTopBar(
                    leading: SyntraBackButton(
                      label: 'Home',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Admin',
                    style: SyntraTheme.sans(
                      color: SyntraPalette.navy,
                      fontSize: 32,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Allowlisted by signed-in email. This screen does not open Firestore.',
                    style: SyntraTheme.sans(
                      color: SyntraPalette.inkMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: SyntraPalette.sage.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'isAdmin',
                            style: SyntraTheme.sans(
                              color: SyntraPalette.sage,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          email != null && email.isNotEmpty
                              ? email
                              : 'Signed in',
                          style: SyntraTheme.sans(
                            color: SyntraPalette.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Google Sign-In is OAuth — SYNTRA never stores a Google password. '
                          'Email/password, if you use it, is checked by Firebase Auth only.',
                          style: SyntraTheme.sans(
                            color: SyntraPalette.inkMuted,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'research_cache hits',
                          style: SyntraTheme.sans(
                            color: SyntraPalette.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cache stays Admin SDK on the server. Flutter must not read or write '
                          'syntra/workspace/research_cache. To see which topics pay off, run this CLI from the repo root:',
                          style: SyntraTheme.sans(
                            color: SyntraPalette.inkMuted,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          'python scripts/cache_hits.py',
                          style: SyntraTheme.sans(
                            color: SyntraPalette.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
