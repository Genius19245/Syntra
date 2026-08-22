import 'package:flutter/material.dart';

import '../theme/syntra_palette.dart';
import '../theme/syntra_theme.dart';

class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.glow,
    this.selected = false,
    this.onTap,
    this.borderRadius = 20,
    this.expand = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? glow;
  final bool selected;
  final VoidCallback? onTap;
  final double borderRadius;
  final bool expand;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final accent = widget.glow ?? SyntraPalette.rust;
    final highlighted = widget.selected || _hovering;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      width: widget.expand ? double.infinity : null,
      height: widget.expand ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: widget.selected
            ? accent.withValues(alpha: 0.08)
            : SyntraPalette.paper,
        border: Border.all(
          color: highlighted
              ? accent.withValues(alpha: widget.selected ? 0.7 : 0.35)
              : SyntraPalette.stroke,
          width: widget.selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: SyntraPalette.navy.withValues(
              alpha: highlighted ? 0.08 : 0.035,
            ),
            blurRadius: highlighted ? 28 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: widget.child,
    );

    Widget result = card;
    if (widget.expand) {
      result = SizedBox.expand(child: card);
    }

    if (widget.onTap == null) return result;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(onTap: widget.onTap, child: result),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.subtitle,
  });

  final String kicker;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(color: SyntraPalette.rust),
        ),
        const SizedBox(height: 6),
        Text(title, style: textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.filled = true,
  });

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? SyntraPalette.rust : SyntraPalette.surfaceLift,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: SyntraTheme.sans(
          color: filled ? SyntraPalette.onAccent : SyntraPalette.inkMuted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class MockupChrome extends StatelessWidget {
  const MockupChrome({super.key, this.accent = SyntraPalette.rust});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(const Color(0xFFE8A598)),
        const SizedBox(width: 6),
        _dot(const Color(0xFFE6C07A)),
        const SizedBox(width: 6),
        _dot(const Color(0xFF9BCBB0)),
        const Spacer(),
        Container(
          width: 72,
          height: 8,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
