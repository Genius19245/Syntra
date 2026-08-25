import 'package:flutter/material.dart';

import '../theme/syntra_palette.dart';
import '../theme/syntra_theme.dart';

class SyntraButton extends StatefulWidget {
  const SyntraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.enabled = true,
    this.expand = false,
    this.accent = SyntraPalette.rust,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool enabled;
  final bool expand;
  final Color accent;

  @override
  State<SyntraButton> createState() => _SyntraButtonState();
}

class _SyntraButtonState extends State<SyntraButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onPressed != null;
    final filled = widget.filled;
    final background = !enabled
        ? SyntraPalette.surfaceLift
        : filled
            ? (_hovering ? widget.accent.withValues(alpha: 0.92) : widget.accent)
            : (_hovering ? SyntraPalette.surfaceLift : SyntraPalette.paper);
    final foreground = !enabled
        ? SyntraPalette.inkFaint
        : filled
            ? SyntraPalette.onAccent
            : SyntraPalette.navy;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled ? background : SyntraPalette.strokeStrong,
        ),
        boxShadow: enabled && filled
            ? [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : const [],
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: foreground),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label,
            style: SyntraTheme.sans(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: widget.expand ? SizedBox(width: double.infinity, child: child) : child,
      ),
    );
  }
}
