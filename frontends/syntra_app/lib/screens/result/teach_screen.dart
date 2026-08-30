import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learner_brief.dart';
import '../../progress/models.dart';
import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mesh_background.dart';
import '../../widgets/syntra_markdown.dart';
import '../../widgets/syntra_shell.dart';

enum TeachStudioTab { explanation, example, interaction }

class TeachScreen extends StatelessWidget {
  const TeachScreen({
    super.key,
    required this.topic,
    this.subject,
    this.level,
    this.board,
    this.explanation,
    this.example,
    this.adaptation,
    this.interaction,
    this.mock = false,
    this.standalone = false,
  });

  factory TeachScreen.fromPipeline({
    Key? key,
    required LearnerBrief brief,
    required PipelineTexts pipeline,
    bool mock = false,
    bool standalone = false,
  }) {
    return TeachScreen(
      key: key,
      topic: brief.topic.trim().isEmpty ? 'Untitled lesson' : brief.topic.trim(),
      subject: brief.resolvedSubject,
      level: brief.levelId,
      board: brief.resolvedBoard,
      explanation: pipeline.explanation,
      example: pipeline.example,
      adaptation: pipeline.adaptation,
      interaction: pipeline.interaction,
      mock: mock,
      standalone: standalone,
    );
  }

  final String topic;
  final String? subject;
  final String? level;
  final String? board;
  final String? explanation;
  final String? example;
  final String? adaptation;
  final String? interaction;
  final bool mock;
  final bool standalone;

  static void open(
    BuildContext context, {
    required String topic,
    String? subject,
    String? level,
    String? board,
    String? explanation,
    String? example,
    String? adaptation,
    String? interaction,
    bool mock = false,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => TeachScreen(
          topic: topic,
          subject: subject,
          level: level,
          board: board,
          explanation: explanation,
          example: example,
          adaptation: adaptation,
          interaction: interaction,
          mock: mock,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 880;

    return Scaffold(
      key: const ValueKey('teach-screen'),
      body: MeshBackground(
        accent: SyntraPalette.rust,
        secondary: SyntraPalette.peach,
        child: SafeArea(
          child: SyntraPageFrame(
            maxWidth: 760,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SyntraTopBar(
                  subtitle: 'Teaching Studio',
                  leading: standalone
                      ? null
                      : SyntraBackButton(
                          label: 'Lesson',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                  trailing: mock
                      ? const StatusBadge(label: 'Mock pack')
                      : const StatusBadge(label: 'Ready to teach'),
                ),
                const SizedBox(height: 18),
                Text(
                  topic,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SyntraTheme.sans(
                    color: SyntraPalette.navy,
                    fontSize: wide ? 32 : 26,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (subject != null) _MetaChip(label: subject!),
                    if (level != null) _MetaChip(label: level!),
                    if (board != null) _MetaChip(label: board!),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TeachStudioBody(
                    explanation: explanation,
                    example: example,
                    adaptation: adaptation,
                    interaction: interaction,
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

/// Shared canvas used by the full studio page and the lesson board.
class TeachStudioBody extends StatefulWidget {
  const TeachStudioBody({
    super.key,
    this.explanation,
    this.example,
    this.adaptation,
    this.interaction,
  });

  final String? explanation;
  final String? example;
  final String? adaptation;
  final String? interaction;

  @override
  State<TeachStudioBody> createState() => _TeachStudioBodyState();
}

class _TeachStudioBodyState extends State<TeachStudioBody> {
  TeachStudioTab _tab = TeachStudioTab.explanation;
  bool _adaptationOpen = false;
  late final TextEditingController _askController;
  InteractionTurn? _activeTurn;
  int _askNonce = 0;

  @override
  void initState() {
    super.initState();
    final desk = InteractionDesk.parse(widget.interaction);
    _activeTurn = desk.primary;
    _askController = TextEditingController(text: desk.primary?.question ?? '');
    if (desk.primary != null) {
      _tab = TeachStudioTab.interaction;
    }
  }

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
  }

  InteractionDesk get _desk => InteractionDesk.parse(widget.interaction);

  AdaptationCue get _cue => AdaptationCue.parse(widget.adaptation);

  void _ask(String question) {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _askNonce += 1;
      _activeTurn = _desk.turnFor(trimmed);
      _askController.text = _activeTurn?.question ?? trimmed;
      _askController.selection = TextSelection.collapsed(
        offset: _askController.text.length,
      );
      _tab = TeachStudioTab.interaction;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cue = _cue;
    return Column(
      key: const ValueKey('teach-studio-body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cue.hasSignal) ...[
          _AdaptationSidecar(
            cue: cue,
            expanded: _adaptationOpen,
            onToggle: () => setState(() => _adaptationOpen = !_adaptationOpen),
          ),
          const SizedBox(height: 8),
        ],
        _StudioModeBar(
          selected: _tab,
          onSelect: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: switch (_tab) {
                TeachStudioTab.interaction => _InteractionWell(
                    desk: _desk,
                    active: _activeTurn,
                    askNonce: _askNonce,
                    askController: _askController,
                    onAsk: _ask,
                  ),
                TeachStudioTab.explanation => _ExplanationPane(
                    empty: _emptyFor(_tab),
                    text: widget.explanation,
                  ),
                TeachStudioTab.example => _ScriptPane(
                    empty: _emptyFor(_tab),
                    text: widget.example,
                  ),
              },
            ),
          ),
        ),
      ],
    );
  }

  static String _emptyFor(TeachStudioTab tab) {
    switch (tab) {
      case TeachStudioTab.explanation:
        return 'Explanation appears here after the Explanation Agent runs.';
      case TeachStudioTab.example:
        return 'The Example Agent fills this after Explanation, Interaction, or Adaptation asks for it.';
      case TeachStudioTab.interaction:
        return 'Interaction appears when a student asks a question.';
    }
  }
}

class _ScriptPane extends StatelessWidget {
  const _ScriptPane({required this.empty, required this.text});

  final String empty;
  final String? text;

  static const _accent = SyntraPalette.rust;

  @override
  Widget build(BuildContext context) {
    final filled = text != null && text!.trim().isNotEmpty;
    return SizedBox.expand(
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: filled
                ? SyntraMarkdownView(
                    data: text!,
                    accent: _accent,
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                  )
                    .animate()
                    .fadeIn(duration: 280.ms)
                    .slideY(begin: 0.03, duration: 320.ms, curve: Curves.easeOutCubic)
                : Text(
                    empty,
                    style: SyntraTheme.sans(
                      color: SyntraPalette.inkMuted,
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ExplanationPane extends StatelessWidget {
  const _ExplanationPane({required this.empty, required this.text});

  final String empty;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final script = ExplanationScript.parse(text);
    if (!script.hasContent) {
      return _ScriptPane(empty: empty, text: text);
    }
    return SizedBox.expand(
      key: const ValueKey('teach-studio-explanation-pane'),
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (script.concept != null || script.level != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (script.concept != null)
                        _QuietChip(label: script.concept!),
                      if (script.level != null)
                        _QuietChip(label: script.level!),
                    ],
                  ),
                if (script.sayThis != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Say this',
                    style: SyntraTheme.sans(
                      color: SyntraPalette.rust,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    script.sayThis!,
                    key: const ValueKey('teach-studio-say-this'),
                    style: SyntraTheme.sans(
                      color: SyntraPalette.navy,
                      fontSize: 20,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
                if (script.freeze != null) ...[
                  const SizedBox(height: 16),
                  DecoratedBox(
                    key: const ValueKey('teach-studio-freeze'),
                    decoration: BoxDecoration(
                      color: SyntraPalette.undergraduate.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: SyntraPalette.undergraduate.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Center(
                        child: Text(
                          script.freeze!,
                          textAlign: TextAlign.center,
                          style: SyntraTheme.sans(
                            color: SyntraPalette.navy,
                            fontSize: 20,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (script.body != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    script.body!,
                    style: SyntraTheme.serif(
                      color: SyntraPalette.ink,
                      fontSize: 16,
                      height: 1.55,
                    ),
                  ),
                ],
                if (script.classroomMove != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    script.classroomMove!,
                    style: SyntraTheme.sans(
                      color: SyntraPalette.sage,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (script.watchFor.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Watch for',
                    style: SyntraTheme.sans(
                      color: SyntraPalette.rust,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in script.watchFor) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: SyntraPalette.rust,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: SyntraTheme.sans(
                                color: SyntraPalette.navy,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                if (script.limits != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    script.limits!,
                    style: SyntraTheme.sans(
                      color: SyntraPalette.inkFaint,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            )
                .animate()
                .fadeIn(duration: 280.ms)
                .slideY(begin: 0.03, duration: 320.ms, curve: Curves.easeOutCubic),
          ),
        ),
      ),
    );
  }
}

class _InteractionWell extends StatelessWidget {
  const _InteractionWell({
    required this.desk,
    required this.active,
    required this.askNonce,
    required this.askController,
    required this.onAsk,
  });

  final InteractionDesk desk;
  final InteractionTurn? active;
  final int askNonce;
  final TextEditingController askController;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: RadialGradient(
          center: const Alignment(0, -0.85),
          radius: 1.15,
          colors: [
            SyntraPalette.rust.withValues(alpha: 0.18),
            SyntraPalette.paper.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(color: SyntraPalette.rust.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: SyntraPalette.rust.withValues(alpha: 0.16),
            blurRadius: 48,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  if (active == null)
                    Text(
                      desk.emptyMessage,
                      style: SyntraTheme.sans(
                        color: SyntraPalette.inkMuted,
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else ...[
                    _StudentBubble(
                      key: ValueKey('q-$askNonce-${active!.question}'),
                      question: active!.question,
                    )
                        .animate()
                        .fadeIn(duration: 220.ms)
                        .slideX(
                          begin: 0.08,
                          duration: 320.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 16),
                    _ReplyCard(
                      key: ValueKey('r-$askNonce-${active!.question}'),
                      turn: active!,
                    )
                        .animate()
                        .fadeIn(delay: 80.ms, duration: 280.ms)
                        .slideY(
                          begin: 0.06,
                          delay: 80.ms,
                          duration: 320.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ],
              ),
            ),
            if (desk.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < desk.suggestions.length; i++)
                    _SuggestionChip(
                      index: i,
                      label: desk.suggestions[i],
                      selected: _same(desk.suggestions[i], active?.question),
                      onTap: () => onAsk(desk.suggestions[i]),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _AskBar(controller: askController, onSubmit: onAsk),
          ],
        ),
      ),
    );
  }

  static bool _same(String a, String? b) =>
      b != null && a.trim().toLowerCase() == b.trim().toLowerCase();
}

class _StudentBubble extends StatelessWidget {
  const _StudentBubble({super.key, required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          key: const ValueKey('teach-studio-student-question'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: SyntraPalette.navy,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Student',
                style: SyntraTheme.sans(
                  color: SyntraPalette.peach,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                question,
                textAlign: TextAlign.right,
                style: SyntraTheme.sans(
                  color: SyntraPalette.onAccent,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({super.key, required this.turn});

  final InteractionTurn turn;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          key: const ValueKey('teach-studio-reply-card'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: SyntraPalette.rust,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fade(begin: 0.35, end: 1, duration: 900.ms),
                  ),
                  TextSpan(
                    text: 'SYNTRA',
                    style: SyntraTheme.sans(
                      color: SyntraPalette.rust,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              turn.reply,
              style: SyntraTheme.sans(
                color: SyntraPalette.navy,
                fontSize: 18,
                height: 1.45,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            if (turn.teachingNote != null) ...[
              const SizedBox(height: 12),
              Text(
                turn.teachingNote!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SyntraTheme.sans(
                  color: SyntraPalette.sage,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AskBar extends StatefulWidget {
  const _AskBar({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  State<_AskBar> createState() => _AskBarState();
}

class _AskBarState extends State<_AskBar> {
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      key: const ValueKey('teach-studio-ask-bar'),
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
      decoration: BoxDecoration(
        color: SyntraPalette.paper,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: focused ? SyntraPalette.rust : SyntraPalette.stroke,
          width: focused ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: SyntraPalette.rust.withValues(alpha: focused ? 0.22 : 0.1),
            blurRadius: focused ? 28 : 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('teach-studio-ask-field'),
              controller: widget.controller,
              focusNode: _focus,
              minLines: 1,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: SyntraTheme.sans(
                color: SyntraPalette.navy,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Ask as the student…',
                hintStyle: SyntraTheme.sans(
                  color: SyntraPalette.inkFaint,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const ValueKey('teach-studio-ask-send'),
            onPressed: _send,
            tooltip: 'Send',
            style: IconButton.styleFrom(
              backgroundColor: SyntraPalette.rust,
              foregroundColor: SyntraPalette.onAccent,
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.index,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('teach-studio-suggestion-$index'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Text(
          label,
          style: SyntraTheme.sans(
            color: selected ? SyntraPalette.rust : SyntraPalette.inkMuted,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ).copyWith(
            decoration:
                selected ? TextDecoration.underline : TextDecoration.none,
            decorationColor: SyntraPalette.rust,
            decorationThickness: 1.4,
          ),
        ),
      ),
    );
  }
}

class _AdaptationSidecar extends StatelessWidget {
  const _AdaptationSidecar({
    required this.cue,
    required this.expanded,
    required this.onToggle,
  });

  final AdaptationCue cue;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('teach-studio-adaptation-banner'),
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _SagePulse(),
                if (cue.stayOnStep) ...[
                  const SizedBox(width: 8),
                  const _QuietChip(label: 'Stay on step'),
                ],
                if (cue.action != null) ...[
                  const SizedBox(width: 8),
                  _QuietChip(label: cue.action!),
                ],
                const Spacer(),
                Icon(
                  key: const ValueKey('teach-studio-adaptation-toggle'),
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: SyntraPalette.inkFaint,
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              if (cue.learnerState != null)
                _SidecarLine(label: 'Learner', value: cue.learnerState!),
              if (cue.guidance != null) ...[
                const SizedBox(height: 6),
                Text(
                  cue.guidance!,
                  style: SyntraTheme.sans(
                    color: SyntraPalette.inkMuted,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (cue.revisit.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Revisit: ${cue.revisit.join(' · ')}',
                  key: const ValueKey('teach-studio-adaptation-revisit'),
                  style: SyntraTheme.sans(
                    color: SyntraPalette.navy,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ],
          ),
        ),
      ),
    );
  }
}

class _SagePulse extends StatefulWidget {
  const _SagePulse();

  @override
  State<_SagePulse> createState() => _SagePulseState();
}

class _SagePulseState extends State<_SagePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.45, end: 0).animate(ring),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1.85).animate(ring),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SyntraPalette.sage.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: SyntraPalette.sage,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidecarLine extends StatelessWidget {
  const _SidecarLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: SyntraTheme.sans(
              color: SyntraPalette.inkFaint,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: SyntraTheme.sans(
              color: SyntraPalette.navy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietChip extends StatelessWidget {
  const _QuietChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.replaceAll('_', ' '),
      style: SyntraTheme.sans(
        color: SyntraPalette.inkFaint,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StudioModeBar extends StatelessWidget {
  const _StudioModeBar({
    required this.selected,
    required this.onSelect,
  });

  final TeachStudioTab selected;
  final ValueChanged<TeachStudioTab> onSelect;

  static const _labels = {
    TeachStudioTab.explanation: 'Explanation',
    TeachStudioTab.example: 'Example',
    TeachStudioTab.interaction: 'Interaction',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tab in TeachStudioTab.values)
          _StudioTabChip(
            tab: tab,
            selected: tab == selected,
            onTap: () => onSelect(tab),
          ),
      ],
    );
  }
}

class _StudioTabChip extends StatelessWidget {
  const _StudioTabChip({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final TeachStudioTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('teach-studio-tab-${tab.name}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? SyntraPalette.rust.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _StudioModeBar._labels[tab]!,
            style: SyntraTheme.sans(
              color: selected ? SyntraPalette.rust : SyntraPalette.inkFaint,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
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

class AdaptationCue {
  const AdaptationCue({
    this.stayOnStep = false,
    this.action,
    this.learnerState,
    this.guidance,
    this.revisit = const [],
  });

  final bool stayOnStep;
  final String? action;
  final String? learnerState;
  final String? guidance;
  final List<String> revisit;

  bool get hasSignal =>
      stayOnStep ||
      (action != null && action!.trim().isNotEmpty) ||
      revisit.isNotEmpty ||
      (guidance != null && guidance!.trim().isNotEmpty);

  factory AdaptationCue.parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const AdaptationCue();
    final text = raw.trim();
    var stay = false;
    String? action;
    String? learnerState;
    String? guidance;
    var revisit = <String>[];

    final jsonMatch = RegExp(r'```json\s*(\{[\s\S]*?\})\s*```').firstMatch(text);
    if (jsonMatch != null) {
      try {
        final decoded = jsonDecode(jsonMatch.group(1)!) as Map<String, dynamic>;
        stay = decoded['stay_on_step'] == true;
        action = decoded['action']?.toString();
        final concepts = decoded['revisit_concepts'];
        if (concepts is List) {
          revisit = [
            for (final item in concepts)
              if (item.toString().trim().isNotEmpty) item.toString().trim(),
          ];
        }
      } catch (_) {}
    }

    learnerState ??= _section(text, 'Learner state');
    action ??= _section(text, 'Action');
    guidance ??= _section(text, 'Guidance');
    final stayText = _section(text, 'Stay on step');
    if (stayText != null) {
      stay = RegExp(r'yes|true', caseSensitive: false).hasMatch(stayText);
    }
    final revisitBlock = _section(text, 'Revisit');
    if (revisit.isEmpty && revisitBlock != null) {
      revisit = [
        for (final line in revisitBlock.split('\n'))
          if (line.trim().startsWith('-'))
            line.replaceFirst(RegExp(r'^-\s*'), '').trim()
          else if (line.trim().isNotEmpty && !line.trim().startsWith('```'))
            line.trim(),
      ].where((item) => item.isNotEmpty).toList();
    }

    return AdaptationCue(
      stayOnStep: stay,
      action: action?.split('\n').first.trim(),
      learnerState: learnerState?.split('\n').first.trim(),
      guidance: guidance,
      revisit: revisit,
    );
  }
}

class ExplanationScript {
  const ExplanationScript({
    this.concept,
    this.level,
    this.sayThis,
    this.body,
    this.freeze,
    this.classroomMove,
    this.watchFor = const [],
    this.limits,
  });

  final String? concept;
  final String? level;
  final String? sayThis;
  final String? body;
  final String? freeze;
  final String? classroomMove;
  final List<String> watchFor;
  final String? limits;

  bool get hasContent =>
      (sayThis != null && sayThis!.isNotEmpty) ||
      (body != null && body!.isNotEmpty) ||
      (freeze != null && freeze!.isNotEmpty);

  factory ExplanationScript.parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const ExplanationScript();
    }
    final text = raw.trim();
    var freeze = _section(text, 'Freeze');
    if (freeze != null) {
      freeze = freeze.replaceAll('**', '').trim();
      if (freeze.contains('\n')) {
        freeze = freeze.split('\n').first.trim();
      }
      if (freeze.isEmpty) freeze = null;
    }
    final watchBlock =
        _section(text, 'Watch for') ?? _section(text, 'Misconceptions');
    return ExplanationScript(
      concept: _firstLine(_section(text, 'Concept')),
      level: _firstLine(_section(text, 'Level')),
      sayThis: _section(text, 'Say this'),
      body: _section(text, 'Explanation'),
      freeze: freeze,
      classroomMove: _section(text, 'Classroom move'),
      watchFor: _bulletItems(watchBlock),
      limits: _section(text, 'Limits'),
    );
  }
}

class InteractionTurn {
  const InteractionTurn({
    required this.question,
    required this.reply,
    this.teachingNote,
  });

  final String question;
  final String reply;
  final String? teachingNote;
}

class InteractionDesk {
  const InteractionDesk({
    this.intent,
    this.turns = const [],
    this.suggestions = const [],
  });

  final String? intent;
  final List<InteractionTurn> turns;
  final List<String> suggestions;

  InteractionTurn? get primary => turns.isEmpty ? null : turns.first;

  String get emptyMessage =>
      'No student turn yet. Ask a question to hear the Interaction Agent.';

  InteractionTurn? turnFor(String question) {
    final needle = _normAsk(question);
    if (needle.isEmpty) return null;
    for (final turn in turns) {
      final q = _normAsk(turn.question);
      if (q == needle || q.contains(needle) || needle.contains(q)) {
        return InteractionTurn(
          question: question.trim(),
          reply: turn.reply,
          teachingNote: turn.teachingNote,
        );
      }
    }
    return InteractionTurn(
      question: question.trim(),
      reply:
          'Stay on this step. Ask about fetch, the zigzag, or why the spit curves. Do not jump to a new landform yet.',
      teachingNote: 'Unmatched question. Keep them on the current sequence.',
    );
  }

  factory InteractionDesk.parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const InteractionDesk();
    final text = raw.trim();
    final intent = _section(text, 'Intent');
    final reply = _section(text, 'Reply');
    final note = _section(text, 'Teaching note');
    var question = _quotedAsk(text) ?? _section(text, 'Student question');

    final suggestions = <String>[];
    final suggested = _section(text, 'Suggested questions');
    if (suggested != null) {
      for (final line in suggested.split('\n')) {
        final item = line.replaceFirst(RegExp(r'^[-*]\s*'), '').trim();
        if (item.isNotEmpty) suggestions.add(item);
      }
    }

    final turns = <InteractionTurn>[];
    if (question != null &&
        question.trim().isNotEmpty &&
        reply != null &&
        reply.trim().isNotEmpty) {
      turns.add(
        InteractionTurn(
          question: question.trim(),
          reply: reply.trim(),
          teachingNote: note?.trim(),
        ),
      );
    }

    final others = _section(text, 'Other answers');
    if (others != null) {
      final blocks = RegExp(
        r'\*\*(.+?)\*\*\s*\n([\s\S]*?)(?=\n\*\*|\s*$)',
      );
      for (final match in blocks.allMatches(others.trim())) {
        final q = match.group(1)!.trim();
        final r = match.group(2)!.trim();
        if (q.isEmpty || r.isEmpty) continue;
        turns.add(InteractionTurn(question: q, reply: r));
        if (!suggestions.any((item) => item.toLowerCase() == q.toLowerCase())) {
          suggestions.add(q);
        }
      }
    }

    if (question != null &&
        question.trim().isNotEmpty &&
        !suggestions.any(
          (item) => item.toLowerCase() == question!.trim().toLowerCase(),
        )) {
      suggestions.insert(0, question.trim());
    }

    return InteractionDesk(
      intent: intent?.split('\n').first.trim(),
      turns: turns,
      suggestions: suggestions,
    );
  }
}

String? _section(String text, String heading) {
  final pattern = RegExp(
    '^##\\s+$heading\\s*\$',
    multiLine: true,
    caseSensitive: false,
  );
  final match = pattern.firstMatch(text);
  if (match == null) return null;
  final rest = text.substring(match.end);
  final next = RegExp(r'^##\s+', multiLine: true).firstMatch(rest);
  final body = (next == null ? rest : rest.substring(0, next.start)).trim();
  return body.isEmpty ? null : body;
}

String? _quotedAsk(String text) {
  final match = RegExp(
    r'Student asked:\s*[“"](.+?)[”"]',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(text);
  return match?.group(1)?.trim();
}

String _normAsk(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String? _firstLine(String? text) {
  if (text == null) return null;
  final line = text.split('\n').first.trim();
  return line.isEmpty ? null : line;
}

List<String> _bulletItems(String? block) {
  if (block == null || block.trim().isEmpty) return const [];
  return [
    for (final line in block.split('\n'))
      if (line.trim().isNotEmpty)
        line.trim().replaceFirst(RegExp(r'^[-*]\s*'), '').trim(),
  ];
}
