import 'package:flutter/material.dart';

import '../theme/syntra_palette.dart';
import '../theme/syntra_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/syntra_markdown.dart';
import 'lesson_plan.dart';

class LessonPlanPanel extends StatelessWidget {
  const LessonPlanPanel({
    super.key,
    required this.plan,
    this.accent = SyntraPalette.rust,
    this.curriculumMarkdown,
    this.compact = false,
  });

  final LessonPlan plan;
  final Color accent;
  final String? curriculumMarkdown;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final minutes = plan.totalMinutes;
    final showBrief = curriculumMarkdown != null &&
        curriculumMarkdown!.trim().isNotEmpty &&
        LessonPlan.tryParse(curriculumMarkdown) == null;
    final stepLabel =
        '${plan.steps.length} step${plan.steps.length == 1 ? '' : 's'}';
    final timeLabel = minutes > 0 ? '$minutes min' : 'Timed sequence';

    if (compact) {
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 4),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  stepLabel,
                  style: SyntraTheme.sans(
                    color: SyntraPalette.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusBadge(label: timeLabel),
            ],
          ),
          subtitle: Text(
            'Teach in this order. Times are a guide, not a bell timetable.',
            style: SyntraTheme.sans(
              color: SyntraPalette.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: [
            for (final step in plan.steps) _CompactStepRow(step: step),
            if (showBrief)
              _CurriculumBrief(
                markdown: curriculumMarkdown!,
                accent: accent,
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              stepLabel,
              style: SyntraTheme.sans(
                color: SyntraPalette.navy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            StatusBadge(label: timeLabel),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Teach in this order. Times are a guide, not a bell timetable.',
          style: SyntraTheme.sans(
            color: SyntraPalette.inkMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: plan.steps.length + (showBrief ? 1 : 0),
            itemBuilder: (context, index) {
              if (showBrief && index == plan.steps.length) {
                return _CurriculumBrief(
                  markdown: curriculumMarkdown!,
                  accent: accent,
                );
              }
              return _StepCard(
                step: plan.steps[index],
                isLast: index == plan.steps.length - 1,
                accent: accent,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CompactStepRow extends StatelessWidget {
  const _CompactStepRow({required this.step});

  final LessonStep step;

  @override
  Widget build(BuildContext context) {
    final color = _difficultyColor(step.difficulty);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Text(
              '${step.step}',
              style: SyntraTheme.sans(
                color: SyntraPalette.onAccent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SyntraTheme.sans(
                    color: SyntraPalette.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (step.purpose.isNotEmpty)
                  Text(
                    step.purpose,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SyntraTheme.sans(
                      color: SyntraPalette.inkMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (step.estimatedMinutes > 0) ...[
            const SizedBox(width: 8),
            Text(
              '${step.estimatedMinutes} min',
              style: SyntraTheme.sans(
                color: SyntraPalette.inkMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.isLast,
    required this.accent,
  });

  final LessonStep step;
  final bool isLast;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = _difficultyColor(step.difficulty);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.28),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    '${step.step}',
                    style: SyntraTheme.sans(
                      color: SyntraPalette.onAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: SyntraPalette.stroke,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 14),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          step.title,
                          style: SyntraTheme.sans(
                            color: SyntraPalette.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        _MetaChip(
                          label: step.difficultyLabel,
                          color: color,
                        ),
                        if (step.estimatedMinutes > 0)
                          _MetaChip(
                            label: '${step.estimatedMinutes} min',
                            color: SyntraPalette.inkMuted,
                          ),
                      ],
                    ),
                    if (step.purpose.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _Field(label: 'Purpose', text: step.purpose),
                    ],
                    if (step.activity.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _Field(label: 'Do this', text: step.activity),
                    ],
                    if (step.concepts.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final concept in step.concepts)
                            _ConceptChip(label: concept),
                        ],
                      ),
                    ],
                    if (step.dependsOn.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Needs: ${step.dependsOn.join(' · ')}',
                        style: SyntraTheme.sans(
                          color: SyntraPalette.inkFaint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SyntraPalette.inkFaint,
                letterSpacing: 1.0,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: SyntraTheme.sans(
            color: SyntraPalette.ink,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SyntraTheme.sans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ConceptChip extends StatelessWidget {
  const _ConceptChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SyntraPalette.voidMid,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SyntraTheme.sans(
          color: SyntraPalette.navy,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CurriculumBrief extends StatelessWidget {
  const _CurriculumBrief({required this.markdown, required this.accent});

  final String markdown;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(
            'Curriculum brief',
            style: SyntraTheme.sans(
              color: SyntraPalette.navy,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            'Profile, prerequisites, and section notes',
            style: SyntraTheme.sans(
              color: SyntraPalette.inkMuted,
              fontSize: 12,
            ),
          ),
          children: [
            SizedBox(
              height: 280,
              child: SyntraMarkdownView(
                data: markdown,
                accent: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _difficultyColor(String difficulty) {
  switch (difficulty) {
    case 'foundation':
      return SyntraPalette.sage;
    case 'developing':
      return SyntraPalette.beginner;
    case 'intermediate':
      return SyntraPalette.amber;
    case 'advanced':
      return SyntraPalette.rust;
    case 'exam_application':
      return SyntraPalette.violet;
    default:
      return SyntraPalette.inkMuted;
  }
}
