import 'package:flutter/material.dart';

import '../theme/syntra_palette.dart';
import '../theme/syntra_theme.dart';
import '../widgets/glass_card.dart';
import 'models.dart';

class ProgressPanel extends StatelessWidget {
  const ProgressPanel({
    super.key,
    required this.progress,
    this.accent = SyntraPalette.rust,
    this.embedded = false,
    this.compact = false,
  });

  final LessonProgress progress;
  final Color accent;
  final bool embedded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final covered = progress.covered;
    final remaining = progress.remaining;
    final gaps = progress.gaps;
    final shownCovered = compact ? covered.take(4).toList() : covered;
    final shownGaps = compact ? gaps.take(3).toList() : gaps;
    final extraCovered = covered.length - shownCovered.length;
    final extraGaps = gaps.length - shownGaps.length;
    final summary = progress.assessed
        ? '${covered.length} of ${progress.objectives.length} demonstrated'
        : '${covered.length} objective${covered.length == 1 ? '' : 's'} in this lesson';

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              compact ? 'LEARNING OBJECTIVES' : 'PROGRESS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                  ),
            ),
            const Spacer(),
            StatusBadge(
              label: gaps.isEmpty ? 'No prereq gaps' : '${gaps.length} gaps',
              filled: gaps.isEmpty,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          summary,
          style: SyntraTheme.sans(
            color: SyntraPalette.navy,
            fontSize: compact ? 16 : 20,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _SectionLabel(
          label: 'Covered objectives',
          color: SyntraPalette.sage,
        ),
        const SizedBox(height: 8),
        if (covered.isEmpty)
          const _EmptyLine(text: 'No objectives marked covered yet.')
        else ...[
          for (final item in shownCovered)
            _ProgressRow(
              text: item.text,
              detail: compact ? null : item.bloomType,
              icon: Icons.check,
              color: SyntraPalette.sage,
            ),
          if (extraCovered > 0)
            _EmptyLine(text: 'And $extraCovered more.'),
        ],
        if (!compact && progress.assessed && remaining.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionLabel(
            label: 'Still to demonstrate',
            color: SyntraPalette.amber,
          ),
          const SizedBox(height: 8),
          for (final item in remaining)
            _ProgressRow(
              text: item.text,
              detail: item.bloomType,
              icon: Icons.more_horiz,
              color: SyntraPalette.amber,
            ),
        ],
        if (gaps.isNotEmpty || !compact) ...[
          const SizedBox(height: 12),
          _SectionLabel(
            label: 'Remaining prerequisite gaps',
            color: gaps.isEmpty ? SyntraPalette.sage : SyntraPalette.amber,
          ),
          const SizedBox(height: 8),
          if (gaps.isEmpty)
            const _EmptyLine(text: 'No remaining prerequisite gaps.')
          else ...[
            for (final gap in shownGaps)
              _ProgressRow(
                text: gap.text,
                detail: compact ? null : gap.source,
                icon: Icons.warning_amber_rounded,
                color: SyntraPalette.amber,
              ),
            if (extraGaps > 0) _EmptyLine(text: 'And $extraGaps more.'),
          ],
        ],
      ],
    );

    if (embedded) return body;
    return GlassCard(
      glow: accent,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: body,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            letterSpacing: 1.1,
          ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: SyntraTheme.sans(
        color: SyntraPalette.inkFaint,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.text,
    required this.icon,
    required this.color,
    this.detail,
  });

  final String text;
  final String? detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: SyntraTheme.sans(
                    color: SyntraPalette.ink,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null && detail!.trim().isNotEmpty)
                  Text(
                    detail!,
                    style: SyntraTheme.sans(
                      color: SyntraPalette.inkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
