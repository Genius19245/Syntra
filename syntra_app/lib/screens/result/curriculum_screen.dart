import 'package:flutter/material.dart';

import '../../models/learner_brief.dart';
import '../../models/research_origin.dart';
import '../../progress/lesson_plan.dart';
import '../../progress/lesson_plan_panel.dart';
import '../../progress/models.dart';
import '../../progress/parser.dart';
import '../../progress/progress_panel.dart';
import '../../progress/slide_deck.dart';
import '../../progress/slide_panel.dart';
import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mesh_background.dart';
import '../../widgets/syntra_markdown.dart';
import '../../widgets/syntra_shell.dart';
import '../intake/widgets/intake_controls.dart';
import '../run/agent_run_screen.dart';

enum TeachingPackTab { objectives, sequence, brief, notes }

class CurriculumScreen extends StatelessWidget {
  const CurriculumScreen({
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
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final badgeLabel = originBadge ??
        (origin != null && origin!.known ? origin!.badge : null);
    final progress = ProgressParser.parse(
      PipelineTexts(
        learningObjectives: pipeline?.learningObjectives,
        prerequisiteAnalysis: pipeline?.prerequisiteAnalysis,
        curriculum: pipeline?.curriculum ?? markdown,
        assessment: pipeline?.assessment,
        knownKnowledge: pipeline?.knownKnowledge ?? brief.priorKnowledge,
      ),
    );
    final lessonPlan = LessonPlan.fromSources([
      pipeline?.lessonPlan,
      pipeline?.curriculum,
      markdown,
    ]);
    final slides = SlideDeck.fromSources([
      pipeline?.slides,
    ]);

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
                    onPressed: () {
                      if (fromHistory) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).popUntil(
                          (route) => route.isFirst,
                        );
                      }
                    },
                  ),
                  trailing: TextButton.icon(
                    onPressed: () {
                      if (!fromHistory) {
                        brief.setRefreshCache(true);
                      }
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  AgentRunScreen(
                            brief: brief,
                            fromHistory: fromHistory,
                          ),
                          transitionsBuilder: (
                            context,
                            animation,
                            secondaryAnimation,
                            child,
                          ) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      fromHistory ? 'Run again' : 'Refresh this topic',
                      style: SyntraTheme.sans(
                        color: SyntraPalette.inkMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: SyntraPalette.inkMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _ResultWorkspace(
                    wide: wide,
                    topic: brief.topic,
                    markdown: markdown,
                    lessonPlan: lessonPlan,
                    slides: slides,
                    progress: progress,
                    badgeLabel: badgeLabel,
                    subject: brief.resolvedSubject,
                    level: brief.levelId,
                    board: brief.resolvedBoard,
                    goal: brief.goal?.label,
                    depth: brief.depth,
                    priorKnowledge: brief.priorKnowledge,
                    accent: accent,
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

class _ResultWorkspace extends StatefulWidget {
  const _ResultWorkspace({
    required this.wide,
    required this.topic,
    required this.markdown,
    required this.lessonPlan,
    required this.slides,
    required this.progress,
    required this.badgeLabel,
    required this.subject,
    required this.level,
    required this.board,
    required this.goal,
    required this.depth,
    required this.priorKnowledge,
    required this.accent,
  });

  final bool wide;
  final String topic;
  final String markdown;
  final LessonPlan? lessonPlan;
  final SlideDeck? slides;
  final LessonProgress progress;
  final String? badgeLabel;
  final String? subject;
  final String? level;
  final String? board;
  final String? goal;
  final String? depth;
  final String priorKnowledge;
  final Color accent;

  @override
  State<_ResultWorkspace> createState() => _ResultWorkspaceState();
}

class _ResultWorkspaceState extends State<_ResultWorkspace> {
  late TeachingPackTab _tab;
  int _slideIndex = 0;

  @override
  void initState() {
    super.initState();
    _tab = _defaultTab();
  }

  List<_PackItem> get _items {
    return [
      if (!widget.progress.isEmpty)
        const _PackItem(
          tab: TeachingPackTab.objectives,
          label: 'Objectives',
          detail: 'What the learner should be able to do',
        ),
      if (widget.lessonPlan != null)
        const _PackItem(
          tab: TeachingPackTab.sequence,
          label: 'Sequence',
          detail: 'Teach in this order',
        ),
      const _PackItem(
        tab: TeachingPackTab.brief,
        label: 'Brief',
        detail: 'Goal, depth, and prior knowledge',
      ),
      if (widget.slides != null)
        const _PackItem(
          tab: TeachingPackTab.notes,
          label: 'Notes',
          detail: 'What to say on this slide',
        ),
    ];
  }

  TeachingPackTab _defaultTab() {
    final notes = _notesFor(_slideIndex);
    if (notes != null && notes.isNotEmpty) return TeachingPackTab.notes;
    if (!widget.progress.isEmpty) return TeachingPackTab.objectives;
    if (widget.slides != null) return TeachingPackTab.notes;
    if (widget.lessonPlan != null) return TeachingPackTab.sequence;
    return TeachingPackTab.brief;
  }

  String? _notesFor(int index) {
    final deck = widget.slides;
    if (deck == null || deck.slides.isEmpty) return null;
    final i = index.clamp(0, deck.slides.length - 1);
    final text = deck.slides[i].teacherExplanation.trim();
    return text.isEmpty ? null : text;
  }

  void _select(TeachingPackTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
  }

  TeachingPackTab get _resolvedTab {
    final items = _items;
    if (items.any((item) => item.tab == _tab)) return _tab;
    return items.isNotEmpty ? items.first.tab : TeachingPackTab.brief;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final selected = _resolvedTab;

    final stage = _PresenterCard(
      topic: widget.topic,
      markdown: widget.markdown,
      lessonPlan: widget.lessonPlan,
      slides: widget.slides,
      badgeLabel: widget.badgeLabel,
      subject: widget.subject,
      level: widget.level,
      board: widget.board,
      accent: widget.accent,
      showSequence: selected == TeachingPackTab.sequence,
      slideIndex: _slideIndex,
      onSlideIndex: (index) {
        if (_slideIndex == index) return;
        setState(() => _slideIndex = index);
      },
    );

    final pack = _TeachingPackRail(
      items: items,
      selected: selected,
      accent: widget.accent,
      horizontal: !widget.wide,
      onSelect: _select,
      body: _packBody(selected),
    );

    if (widget.wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: stage),
          const SizedBox(width: 16),
          Expanded(flex: 1, child: pack),
        ],
      );
    }

    return Column(
      children: [
        pack,
        const SizedBox(height: 12),
        Expanded(flex: 3, child: stage),
      ],
    );
  }

  Widget _packBody(TeachingPackTab tab) {
    switch (tab) {
      case TeachingPackTab.objectives:
        return SingleChildScrollView(
          child: ProgressPanel(
            progress: widget.progress,
            accent: widget.accent,
            embedded: true,
          ),
        );
      case TeachingPackTab.sequence:
        return _SequenceOnBoardCue(accent: widget.accent);
      case TeachingPackTab.brief:
        return SingleChildScrollView(
          child: LiveDossier(
            level: widget.level,
            board: widget.board,
            subject: widget.subject,
            topic: widget.topic,
            goal: widget.goal,
            depth: widget.depth,
            priorKnowledge: widget.priorKnowledge,
            accent: widget.accent,
            ready: true,
            showIdentity: false,
            embedded: true,
          ),
        );
      case TeachingPackTab.notes:
        return SingleChildScrollView(
          child: _NotesPane(
            text: _notesFor(_slideIndex),
            accent: widget.accent,
          ),
        );
    }
  }
}

class _PackItem {
  const _PackItem({
    required this.tab,
    required this.label,
    required this.detail,
  });

  final TeachingPackTab tab;
  final String label;
  final String detail;
}

class _PresenterCard extends StatelessWidget {
  const _PresenterCard({
    required this.topic,
    required this.markdown,
    required this.lessonPlan,
    required this.slides,
    required this.badgeLabel,
    required this.subject,
    required this.level,
    required this.board,
    required this.accent,
    required this.showSequence,
    required this.slideIndex,
    required this.onSlideIndex,
  });

  final String topic;
  final String markdown;
  final LessonPlan? lessonPlan;
  final SlideDeck? slides;
  final String? badgeLabel;
  final String? subject;
  final String? level;
  final String? board;
  final Color accent;
  final bool showSequence;
  final int slideIndex;
  final ValueChanged<int> onSlideIndex;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glow: accent,
      selected: true,
      expand: true,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LESSON',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                    ),
              ),
              const Spacer(),
              if (badgeLabel != null)
                StatusBadge(label: badgeLabel!)
              else
                const StatusBadge(label: 'Ready to teach'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            topic,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SyntraTheme.sans(
              color: SyntraPalette.navy,
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (slides == null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (subject != null) _Chip(label: subject!),
                if (level != null) _Chip(label: level!),
                if (board != null) _Chip(label: board!),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Expanded(child: _stage()),
        ],
      ),
    );
  }

  Widget _stage() {
    if (showSequence && lessonPlan != null) {
      return LessonPlanPanel(
        plan: lessonPlan!,
        accent: accent,
        curriculumMarkdown: markdown,
      );
    }
    if (slides != null) {
      return SlidePanel(
        deck: slides!,
        accent: accent,
        subject: subject,
        level: level,
        board: board,
        initialIndex: slideIndex,
        onIndexChanged: onSlideIndex,
      );
    }
    if (lessonPlan != null) {
      return LessonPlanPanel(
        plan: lessonPlan!,
        accent: accent,
        curriculumMarkdown: markdown,
      );
    }
    return SyntraMarkdownView(
      data: markdown,
      accent: accent,
      padding: const EdgeInsets.only(bottom: 16),
    );
  }
}

class _TeachingPackRail extends StatelessWidget {
  const _TeachingPackRail({
    required this.items,
    required this.selected,
    required this.accent,
    required this.horizontal,
    required this.onSelect,
    required this.body,
  });

  final List<_PackItem> items;
  final TeachingPackTab selected;
  final Color accent;
  final bool horizontal;
  final ValueChanged<TeachingPackTab> onSelect;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                _PackChip(
                  label: item.label,
                  selected: item.tab == selected,
                  onTap: () => onSelect(item.tab),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: GlassCard(
              glow: accent,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: body,
            ),
          ),
        ],
      );
    }

    return GlassCard(
      glow: accent,
      expand: true,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TEACHING PACK',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++)
            _PackRow(
              index: i + 1,
              item: items[i],
              selected: items[i].tab == selected,
              isLast: i == items.length - 1,
              accent: accent,
              onTap: () => onSelect(items[i].tab),
            ),
          const SizedBox(height: 8),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.index,
    required this.item,
    required this.selected,
    required this.isLast,
    required this.accent,
    required this.onTap,
  });

  final int index;
  final _PackItem item;
  final bool selected;
  final bool isLast;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : SyntraPalette.inkFaint;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('teaching-pack-${item.tab.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 10 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? accent : Colors.transparent,
                        border: Border.all(color: color, width: 1.6),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.32),
                                  blurRadius: 10,
                                ),
                              ]
                            : const [],
                      ),
                      child: Text(
                        '$index',
                        style: SyntraTheme.sans(
                          color: selected ? SyntraPalette.onAccent : color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 18,
                        margin: const EdgeInsets.only(top: 6),
                        color: selected
                            ? accent.withValues(alpha: 0.35)
                            : SyntraPalette.stroke,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: SyntraTheme.sans(
                        color: SyntraPalette.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.detail,
                      style: SyntraTheme.sans(
                        color: selected ? accent : SyntraPalette.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackChip extends StatelessWidget {
  const _PackChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('teaching-pack-chip-$label'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? SyntraPalette.rust : SyntraPalette.voidMid,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: SyntraTheme.sans(
            color: selected ? SyntraPalette.onAccent : SyntraPalette.navy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SequenceOnBoardCue extends StatelessWidget {
  const _SequenceOnBoardCue({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ON THE BOARD',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sequence is on the board. Steps, times, and purposes are in the lesson panel.',
          style: SyntraTheme.sans(
            color: SyntraPalette.navy,
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NotesPane extends StatelessWidget {
  const _NotesPane({required this.text, required this.accent});

  final String? text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAY THIS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          (text == null || text!.isEmpty)
              ? 'No spoken cue on this slide. Advance when the class has the idea.'
              : text!,
          style: SyntraTheme.sans(
            color: SyntraPalette.navy,
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
