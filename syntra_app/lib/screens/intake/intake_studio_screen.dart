import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/intake_catalog.dart';
import '../../models/learner_brief.dart';
import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mesh_background.dart';
import '../../widgets/syntra_button.dart';
import '../../widgets/syntra_shell.dart';
import '../run/agent_run_screen.dart';
import 'widgets/intake_controls.dart';
import 'widgets/landing_hero.dart';

class IntakeStudioScreen extends StatefulWidget {
  const IntakeStudioScreen({super.key});

  @override
  State<IntakeStudioScreen> createState() => _IntakeStudioScreenState();
}

class _IntakeStudioScreenState extends State<IntakeStudioScreen> {
  late final LearnerBrief _brief = LearnerBrief();
  late final TextEditingController _topicController = TextEditingController();
  late final TextEditingController _priorController = TextEditingController();
  late final TextEditingController _customSubjectController =
      TextEditingController();
  late final TextEditingController _customBoardController =
      TextEditingController();
  bool _composing = false;

  @override
  void initState() {
    super.initState();
    _brief.addListener(_syncControllers);
  }

  void _syncControllers() {
    if (_topicController.text != _brief.topic) {
      _topicController.value = TextEditingValue(
        text: _brief.topic,
        selection: TextSelection.collapsed(offset: _brief.topic.length),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _brief.removeListener(_syncControllers);
    _brief.dispose();
    _topicController.dispose();
    _priorController.dispose();
    _customSubjectController.dispose();
    _customBoardController.dispose();
    super.dispose();
  }

  Color get _accent => SyntraPalette.rust;

  void _launch() {
    if (!_brief.isLaunchReady) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AgentRunScreen(brief: _brief),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeshBackground(
        accent: SyntraPalette.rust,
        secondary: SyntraPalette.peach,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 480),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _composing ? _workspace(context) : _landing(),
        ),
      ),
    );
  }

  Widget _landing() {
    return LandingHero(
      key: const ValueKey('landing'),
      onCreate: () => setState(() => _composing = true),
    );
  }

  Widget _workspace(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final dossier = LiveDossier(
      level: _brief.levelId,
      board: _brief.resolvedBoard,
      subject: _brief.resolvedSubject,
      topic: _brief.topic,
      goal: _brief.goal?.label,
      depth: _brief.depth,
      priorKnowledge: _brief.priorKnowledge,
      accent: _accent,
      ready: _brief.isLaunchReady,
    );

    return SafeArea(
      key: const ValueKey('workspace'),
      child: Column(
        children: [
          SyntraPageFrame(
            padding: const EdgeInsets.fromLTRB(16, 4, 24, 0),
            child: SyntraTopBar(
              leading: SyntraBackButton(
                label: 'Home',
                onPressed: () => setState(() => _composing = false),
              ),
              trailing: SyntraButton(
                label: _brief.isLaunchReady ? 'Write lesson' : 'Fill the brief',
                enabled: _brief.isLaunchReady,
                onPressed: _launch,
              ),
            ),
          ),
          Expanded(
            child: wide
                ? SyntraPageFrame(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _BriefingCanvas(
                            brief: _brief,
                            accent: _accent,
                            nested: false,
                            topicController: _topicController,
                            priorController: _priorController,
                            customSubjectController: _customSubjectController,
                            customBoardController: _customBoardController,
                            onLaunch: _launch,
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 340,
                          child: SingleChildScrollView(child: dossier),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      dossier,
                      const SizedBox(height: 24),
                      _BriefingCanvas(
                        brief: _brief,
                        accent: _accent,
                        nested: true,
                        topicController: _topicController,
                        priorController: _priorController,
                        customSubjectController: _customSubjectController,
                        customBoardController: _customBoardController,
                        onLaunch: _launch,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BriefingCanvas extends StatelessWidget {
  const _BriefingCanvas({
    required this.brief,
    required this.accent,
    required this.nested,
    required this.topicController,
    required this.priorController,
    required this.customSubjectController,
    required this.customBoardController,
    required this.onLaunch,
  });

  final LearnerBrief brief;
  final Color accent;
  final bool nested;
  final TextEditingController topicController;
  final TextEditingController priorController;
  final TextEditingController customSubjectController;
  final TextEditingController customBoardController;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final level = brief.level;
    final showBoard = level?.showExamBoard == true;
    final showCustomBoard = level?.customBoard == true;
    final showCustomSubject = brief.subject == IntakeCatalog.customSubject;

    final children = [
      Text(
        'New lesson',
        style: SyntraTheme.sans(
          color: SyntraPalette.navy,
          fontSize: 40,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
      ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.06),
      const SizedBox(height: 8),
      Text(
        'Select a level, board, and topic. SYNTRA writes a curriculum a teacher can walk into.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
      ),
      const SizedBox(height: 16),
      FeaturePills(brief: brief, accent: accent),
      const SizedBox(height: 28),
      GlassCard(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              kicker: '01',
              title: 'Choose a level',
              subtitle: 'KS, GCSE, A-Level, university, or professional.',
            ),
            const SizedBox(height: 16),
            LevelIdentityGrid(
              selectedId: brief.levelId,
              accent: accent,
              onSelected: brief.selectLevel,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: showBoard
                  ? Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            kicker: 'Board',
                            title: 'Exam board',
                            subtitle: 'Only if this level is assessed. Never assumed.',
                          ),
                          const SizedBox(height: 14),
                          SyntraChips(
                            options: level!.boards,
                            selected: brief.board,
                            accent: accent,
                            onSelected: brief.selectBoard,
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: showCustomBoard
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SyntraField(
                        controller: customBoardController,
                        hint: 'Optional board, awarding body, or framework',
                        accent: accent,
                        onChanged: brief.setCustomBoard,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      GlassCard(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              kicker: '02',
              title: 'Subject',
              subtitle: 'Tap a chip. Custom is always available.',
            ),
            const SizedBox(height: 14),
            if (level == null)
              Text(
                'Choose a level to unlock subjects.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              SyntraChips(
                options: IntakeCatalog.subjectsFor(level),
                selected: brief.subject,
                accent: accent,
                onSelected: brief.selectSubject,
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              child: showCustomSubject
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SyntraField(
                        controller: customSubjectController,
                        hint: 'Name the subject',
                        accent: accent,
                        onChanged: brief.setCustomSubject,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 28),
            const SectionHeader(
              kicker: '03',
              title: 'Topic or chapter',
              subtitle: 'Be specific — a chapter, concept, or question.',
            ),
            const SizedBox(height: 14),
            TopicField(
              controller: topicController,
              accent: accent,
              suggestions: brief.topicSuggestions,
              onChanged: brief.setTopic,
              onSuggestionTap: (topic) {
                topicController.text = topic;
                brief.setTopic(topic);
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      GlassCard(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              kicker: '04',
              title: 'Intent and depth',
              subtitle: 'What should this curriculum actually do?',
            ),
            const SizedBox(height: 14),
            if (level == null)
              Text(
                'Goals appear once a level is chosen.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              GoalCards(
                goals: level.goals,
                selectedId: brief.goalId,
                accent: accent,
                onSelected: (goal) => brief.selectGoal(goal.id),
              ),
            const SizedBox(height: 20),
            const SectionHeader(
              kicker: '05',
              title: 'Required depth',
              subtitle: 'Clipped to what this level can hold.',
            ),
            const SizedBox(height: 14),
            if (level == null)
              Text(
                'Depth locks in with the learner identity.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              DepthSpectrum(
                stops: level.depths,
                selected: brief.depth,
                accent: accent,
                onSelected: brief.selectDepth,
              ),
            const SizedBox(height: 24),
            const SectionHeader(
              kicker: '06',
              title: 'Prior knowledge',
              subtitle: 'Optional. Helps find the real gaps.',
            ),
            const SizedBox(height: 14),
            SyntraField(
              controller: priorController,
              hint: 'e.g. GCSE double science, comfortable with algebra…',
              accent: accent,
              maxLines: 3,
              onChanged: brief.setPriorKnowledge,
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              kicker: '07',
              title: 'Verification',
              subtitle: 'Optional. Strict mode costs more time.',
            ),
            const SizedBox(height: 14),
            StrictModeToggle(
              enabled: brief.strictVerification,
              accent: accent,
              onChanged: brief.setStrictVerification,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      LaunchCta(
        enabled: brief.isLaunchReady,
        label: brief.launchLabel,
        accent: accent,
        onPressed: onLaunch,
      ),
    ];

    if (nested) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 8, 24),
      children: children,
    );
  }
}
