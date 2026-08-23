import 'package:flutter/material.dart';

import '../theme/syntra_palette.dart';
import '../theme/syntra_theme.dart';

class PastLessonsLink extends StatelessWidget {
  const PastLessonsLink({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.history_rounded, size: 18),
      label: Text(
        'Past lessons',
        style: SyntraTheme.sans(
          color: SyntraPalette.inkMuted,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: SyntraPalette.inkMuted,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}
