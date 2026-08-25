import 'package:flutter/material.dart';

import '../../models/learner_brief.dart';
import '../../models/research_origin.dart';
import '../../progress/lesson_plan.dart';
import '../../progress/models.dart';
import '../../progress/slide_deck.dart';
import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mesh_background.dart';
import '../../widgets/syntra_button.dart';
import '../../widgets/syntra_shell.dart';
import '../history/history_screen.dart';
import 'curriculum_screen.dart';

class LessonReadyScreen extends StatelessWidget {
  const LessonReadyScreen({
    super.key,
    required this.brief,
    required this.markdown,
    this.origin,
    this.originBadge,
    this.fromHistory = false,
    this.pipeline,
  });

  final LearnerBrief brief;
  final String markdown;
  final ResearchOrigin? origin;
  final String? originBadge;
  final bool fromHistory;
  final PipelineTexts? pipeline;

  @override
  Widget build(BuildContext context) {
    const accent = SyntraPalette.rust;
    final lessonPlan = LessonPlan.fromSources([
      pipeline?.lessonPlan,
      pipeline?.curriculum,
      markdown,
    ]);
    final slides = SlideDeck.fromSources([
      pipeline?.slides,
      pipeline?.curriculum,
      markdown,
    ]);
    final stepCount = lessonPlan?.steps.length ?? 0;
    final minutes = (lessonPlan != null && lessonPlan.totalMinutes > 0)
        ? lessonPlan.totalMinutes
        : (slides?.totalMinutes ?? 0);
    final badgeLabel = originBadge ??
        (origin != null && origin!.known ? origin!.badge : null);

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
                    label: fromHistory ? 'Past lessons' : 'New brief',
                    onPressed: () => _newBrief(context),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.32),
                                    blurRadius: 22,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: SyntraPalette.onAccent,
                                size: 38,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Lesson Ready!',
                              textAlign: TextAlign.center,
                              style: SyntraTheme.serif(
                                color: SyntraPalette.navy,
                                fontSize: 36,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Your lesson is compiled and saved to Past lessons.',
                              textAlign: TextAlign.center,
                              style: SyntraTheme.sans(
                                color: SyntraPalette.inkMuted,
                                fontSize: 15,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            GlassCard(
                              glow: accent,
                              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LESSON SUMMARY',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: accent),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    brief.topic.trim().isEmpty
                                        ? 'Untitled lesson'
                                        : brief.topic.trim(),
                                    style: SyntraTheme.serif(
                                      color: SyntraPalette.navy,
                                      fontSize: 22,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (brief.resolvedSubject != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      brief.resolvedSubject!,
                                      style: SyntraTheme.sans(
                                        color: SyntraPalette.inkMuted,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (brief.levelId != null)
                                        _Pill(label: brief.levelId!),
                                      if (stepCount > 0)
                                        _StatChip(
                                          icon: Icons.view_agenda_outlined,
                                          label:
                                              '$stepCount step${stepCount == 1 ? '' : 's'}',
                                        ),
                                      if (minutes > 0)
                                        _StatChip(
                                          icon: Icons.schedule_rounded,
                                          label: '$minutes min',
                                        ),
                                      if (badgeLabel != null)
                                        StatusBadge(label: badgeLabel),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            SyntraButton(
                              key: const ValueKey('lesson-ready-view'),
                              label: 'View Lesson',
                              icon: Icons.visibility_outlined,
                              expand: true,
                              onPressed: () => _viewLesson(context),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: SyntraButton(
                                    key: const ValueKey('lesson-ready-history'),
                                    label: 'Past lessons',
                                    icon: Icons.history_rounded,
                                    filled: false,
                                    expand: true,
                                    onPressed: () => _pastLessons(context),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SyntraButton(
                                    key: const ValueKey('lesson-ready-new'),
                                    label: 'New brief',
                                    icon: Icons.add_rounded,
                                    filled: false,
                                    expand: true,
                                    onPressed: () => _newBrief(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  void _viewLesson(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CurriculumScreen(
          brief: brief,
          markdown: markdown,
          origin: origin,
          originBadge: originBadge,
          fromHistory: fromHistory,
          pipeline: pipeline,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _pastLessons(BuildContext context) {
    if (fromHistory) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HistoryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _newBrief(BuildContext context) {
    if (fromHistory) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE6F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SyntraTheme.sans(
          color: SyntraPalette.navy,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: SyntraPalette.voidMid,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: SyntraPalette.navy),
          const SizedBox(width: 6),
          Text(
            label,
            style: SyntraTheme.sans(
              color: SyntraPalette.navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
