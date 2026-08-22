import 'package:flutter/material.dart';

import '../theme/syntra_palette.dart';
import '../theme/syntra_theme.dart';
import 'syntra_mark.dart';

class SyntraTopBar extends StatelessWidget {
  const SyntraTopBar({
    super.key,
    this.leading,
    this.trailing,
    this.subtitle = 'Lesson Planner',
  });

  final Widget? leading;
  final Widget? trailing;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
      child: Row(
        children: [
          ?leading,
          if (leading != null) const SizedBox(width: 4),
          const SyntraMark(size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SYNTRA',
                style: SyntraTheme.sans(
                  color: SyntraPalette.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                subtitle,
                style: SyntraTheme.sans(
                  color: SyntraPalette.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class SyntraBackButton extends StatelessWidget {
  const SyntraBackButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: Text(
        label.replaceFirst(RegExp(r'^←\s*'), ''),
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

class SyntraPageFrame extends StatelessWidget {
  const SyntraPageFrame({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
