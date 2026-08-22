import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/intake_catalog.dart';
import '../../../models/learner_brief.dart';
import '../../../theme/syntra_palette.dart';
import '../../../theme/syntra_theme.dart';
import '../../../widgets/glass_card.dart';

class FeaturePills extends StatelessWidget {
  const FeaturePills({
    super.key,
    required this.brief,
    required this.accent,
  });

  final LearnerBrief brief;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final items = <(String, bool)>[
      ('Level', brief.levelId != null),
      if (brief.level?.showExamBoard == true)
        ('Board', brief.resolvedBoard != null),
      ('Subject', brief.resolvedSubject != null),
      ('Topic', brief.topic.trim().isNotEmpty),
      ('Intent', brief.goalId != null),
      if (brief.strictVerification) ('Strict', true),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: item.$2 ? accent : SyntraPalette.paper,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: item.$2 ? accent : SyntraPalette.stroke,
              ),
            ),
            child: Text(
              item.$1,
              style: SyntraTheme.sans(
                color: item.$2 ? SyntraPalette.onAccent : SyntraPalette.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class LevelIdentityGrid extends StatelessWidget {
  const LevelIdentityGrid({
    super.key,
    required this.selectedId,
    required this.accent,
    required this.onSelected,
  });

  final String? selectedId;
  final Color accent;
  final ValueChanged<EducationLevelSpec> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 720 ? 4 : (width >= 520 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: IntakeCatalog.levels.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 132,
          ),
          itemBuilder: (context, index) {
            final level = IntakeCatalog.levels[index];
            final selected = level.id == selectedId;
            return GlassCard(
              key: ValueKey(level.id),
              selected: selected,
              glow: level.accent,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(level);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: level.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: level.accent.withValues(alpha: 0.7),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    level.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: selected ? level.accent : SyntraPalette.ink,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          height: 1.25,
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class SyntraChips extends StatelessWidget {
  const SyntraChips({
    super.key,
    required this.options,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final unique = IntakeCatalog.unique(options);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in unique)
          _Chip(
            key: ValueKey(option),
            label: option,
            selected: option == selected,
            accent: accent,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(option);
            },
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : SyntraPalette.paper,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : SyntraPalette.stroke,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? SyntraPalette.onAccent : SyntraPalette.ink,
                fontSize: 13,
              ),
        ),
      ),
      ),
    );
  }
}

class TopicField extends StatelessWidget {
  const TopicField({
    super.key,
    required this.controller,
    required this.accent,
    required this.suggestions,
    required this.onChanged,
    required this.onSuggestionTap,
  });

  final TextEditingController controller;
  final Color accent;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim().toLowerCase();
    final filtered = suggestions
        .where((topic) => query.isEmpty || topic.toLowerCase().contains(query))
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          cursorColor: accent,
          style: SyntraTheme.sans(
            color: SyntraPalette.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Topic or chapter…',
            hintStyle: SyntraTheme.sans(
              color: SyntraPalette.inkFaint,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: SyntraPalette.glass,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: SyntraPalette.stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: accent, width: 1.4),
            ),
          ),
        ),
        if (filtered.isNotEmpty) ...[
          const SizedBox(height: 12),
          SyntraChips(
            options: filtered,
            selected: controller.text.trim().isEmpty
                ? null
                : suggestions.contains(controller.text.trim())
                    ? controller.text.trim()
                    : null,
            accent: accent,
            onSelected: onSuggestionTap,
          ),
        ],
      ],
    );
  }
}

class GoalCards extends StatelessWidget {
  const GoalCards({
    super.key,
    required this.goals,
    required this.selectedId,
    required this.accent,
    required this.onSelected,
  });

  final List<LearningGoalSpec> goals;
  final String? selectedId;
  final Color accent;
  final ValueChanged<LearningGoalSpec> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < goals.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              key: ValueKey(goals[i].id),
              selected: goals[i].id == selectedId,
              glow: accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(goals[i]);
              },
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: goals[i].id == selectedId
                          ? accent
                          : SyntraPalette.inkFaint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goals[i].label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          goals[i].description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class DepthSpectrum extends StatelessWidget {
  const DepthSpectrum({
    super.key,
    required this.stops,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final List<String> stops;
  final String? selected;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glow: accent,
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: 12,
                      right: 12,
                      child: Container(
                        height: 2,
                        color: SyntraPalette.strokeStrong,
                      ),
                    ),
                    Row(
                      children: [
                        for (final stop in stops)
                          Expanded(
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onSelected(stop);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 240),
                                  width: stop == selected ? 18 : 11,
                                  height: stop == selected ? 18 : 11,
                                  decoration: BoxDecoration(
                                    color: stop == selected
                                        ? accent
                                        : SyntraPalette.surfaceLift,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: stop == selected
                                          ? accent
                                          : SyntraPalette.strokeStrong,
                                      width: 2,
                                    ),
                                    boxShadow: stop == selected
                                        ? [
                                            BoxShadow(
                                              color: accent.withValues(
                                                alpha: 0.55,
                                              ),
                                              blurRadius: 16,
                                            ),
                                          ]
                                        : const [],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final stop in stops)
                Expanded(
                  child: Text(
                    stop,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: stop == selected
                              ? accent
                              : SyntraPalette.inkMuted,
                          fontSize: 11,
                        ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class LiveDossier extends StatelessWidget {
  const LiveDossier({
    super.key,
    required this.level,
    required this.board,
    required this.subject,
    required this.topic,
    required this.goal,
    required this.depth,
    required this.priorKnowledge,
    required this.accent,
    required this.ready,
  });

  final String? level;
  final String? board;
  final String? subject;
  final String topic;
  final String? goal;
  final String? depth;
  final String priorKnowledge;
  final Color accent;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final title = topic.trim().isEmpty ? 'Curriculum brief' : topic.trim();
    return GlassCard(
      glow: accent,
      selected: ready,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LESSON BRIEF',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                    ),
              ),
              const Spacer(),
              StatusBadge(
                label: ready ? 'Ready to teach' : 'Draft',
                filled: ready,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: SyntraTheme.sans(
              color: SyntraPalette.navy,
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (subject != null) _MetaChip(label: subject!),
              if (level != null) _MetaChip(label: level!),
              if (board != null) _MetaChip(label: board!),
            ],
          ),
          const SizedBox(height: 18),
          _DossierRow(label: 'Goal', value: goal, accent: accent),
          _DossierRow(label: 'Depth', value: depth, accent: accent),
          _DossierRow(
            label: 'Prior',
            value: priorKnowledge.trim().isEmpty ? null : priorKnowledge.trim(),
            accent: accent,
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

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

class _DossierRow extends StatelessWidget {
  const _DossierRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String? value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                  ),
            ),
          ),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: SyntraTheme.sans(
                color: filled ? SyntraPalette.ink : SyntraPalette.inkFaint,
                fontSize: 15,
                fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(filled ? value! : '—'),
            ),
          ),
        ],
      ),
    );
  }
}

class StrictModeToggle extends StatelessWidget {
  const StrictModeToggle({
    super.key,
    required this.enabled,
    required this.accent,
    required this.onChanged,
  });

  final bool enabled;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      selected: enabled,
      glow: accent,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      onTap: () => onChanged(!enabled),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified lesson',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Turn the Fact Checker on. Slower, stricter claims.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 26,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: enabled ? accent : SyntraPalette.stroke,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: SyntraPalette.paper,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LaunchCta extends StatelessWidget {
  const LaunchCta({
    super.key,
    required this.enabled,
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: accent,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 24,
                    ),
                  ]
                : const [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SyntraTheme.sans(
              color: SyntraPalette.onAccent,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class SyntraField extends StatelessWidget {
  const SyntraField({
    super.key,
    required this.controller,
    required this.hint,
    required this.accent,
    required this.onChanged,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final Color accent;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      cursorColor: accent,
      style: SyntraTheme.sans(
        color: SyntraPalette.ink,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: SyntraTheme.sans(color: SyntraPalette.inkFaint),
        filled: true,
        fillColor: SyntraPalette.glass,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SyntraPalette.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent),
        ),
      ),
    );
  }
}
