import 'package:flutter/material.dart';

import '../../models/learner_brief.dart';
import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mesh_background.dart';
import '../../widgets/syntra_markdown.dart';
import '../../widgets/syntra_shell.dart';
import '../intake/widgets/intake_controls.dart';

class CurriculumScreen extends StatelessWidget {
  const CurriculumScreen({
    super.key,
    required this.brief,
    required this.markdown,
  });

  final LearnerBrief brief;
  final String markdown;

  @override
  Widget build(BuildContext context) {
    const accent = SyntraPalette.rust;
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final dossier = LiveDossier(
      level: brief.levelId,
      board: brief.resolvedBoard,
      subject: brief.resolvedSubject,
      topic: brief.topic,
      goal: brief.goal?.label,
      depth: brief.depth,
      priorKnowledge: brief.priorKnowledge,
      accent: accent,
      ready: true,
    );
    final plan = GlassCard(
      glow: accent,
      selected: true,
      expand: true,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CURRICULUM BRIEF',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                    ),
              ),
              const Spacer(),
              const StatusBadge(label: 'Ready to teach'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            brief.topic,
            style: SyntraTheme.sans(
              color: SyntraPalette.navy,
              fontSize: 30,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (brief.resolvedSubject != null)
                _Chip(label: brief.resolvedSubject!),
              if (brief.levelId != null) _Chip(label: brief.levelId!),
              if (brief.resolvedBoard != null) _Chip(label: brief.resolvedBoard!),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SyntraMarkdownView(
              data: markdown,
              accent: accent,
              padding: const EdgeInsets.only(bottom: 16),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: MeshBackground(
        accent: accent,
        secondary: SyntraPalette.peach,
        child: SafeArea(
          child: SyntraPageFrame(
            padding: const EdgeInsets.fromLTRB(16, 4, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SyntraTopBar(
                  leading: SyntraBackButton(
                    label: 'New brief',
                    onPressed: () => Navigator.of(context).popUntil(
                      (route) => route.isFirst,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: wide
                      ? Row(
                          children: [
                            Expanded(flex: 2, child: plan),
                            const SizedBox(width: 16),
                            Expanded(child: dossier),
                          ],
                        )
                      : ListView(
                          children: [
                            SizedBox(height: 520, child: plan),
                            const SizedBox(height: 16),
                            dossier,
                          ],
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: SyntraPalette.voidMid,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SyntraTheme.sans(
          color: SyntraPalette.navy,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
