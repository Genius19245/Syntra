import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/learner_brief.dart';
import '../../services/adk_client.dart';
import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mesh_background.dart';
import '../../widgets/syntra_mark.dart';
import '../../widgets/syntra_markdown.dart';
import '../../widgets/syntra_shell.dart';
import '../result/curriculum_screen.dart';

class PipelineStage {
  const PipelineStage({
    required this.id,
    required this.label,
    required this.detail,
    required this.authors,
  });

  final String id;
  final String label;
  final String detail;
  final List<String> authors;
}

enum StageStatus { pending, active, complete }

class AgentRunScreen extends StatefulWidget {
  const AgentRunScreen({super.key, required this.brief});

  final LearnerBrief brief;

  @override
  State<AgentRunScreen> createState() => _AgentRunScreenState();
}

class _AgentRunScreenState extends State<AgentRunScreen> {
  static const stages = [
    PipelineStage(
      id: 'research',
      label: 'Research',
      detail: 'Gather sources and check the facts',
      authors: [
        'research_and_profile',
        'research_agent',
        'source_researcher',
        'fact_checker',
      ],
    ),
    PipelineStage(
      id: 'profile',
      label: 'Learner profile',
      detail: 'Lock level, board, subject, and depth',
      authors: ['learner_profiler_agent'],
    ),
    PipelineStage(
      id: 'prereq',
      label: 'Prerequisites',
      detail: 'Map what must already be in place',
      authors: ['prerequisite_agent'],
    ),
    PipelineStage(
      id: 'objectives',
      label: 'Learning objectives',
      detail: 'Write measurable outcomes for the topic',
      authors: ['learning_objectives_agent'],
    ),
    PipelineStage(
      id: 'curriculum',
      label: 'Curriculum',
      detail: 'Sequence the lesson a teacher can teach',
      authors: ['curriculum_agent', 'syntra_orchestrator'],
    ),
  ];

  final AdkClient _client = AdkClient();
  final Map<String, StageStatus> _status = {
    for (final stage in stages) stage.id: StageStatus.pending,
  };
  String _liveText = '';
  String _curriculum = '';
  String? _errorTitle;
  String? _errorDetail;
  bool _running = true;

  Color get _accent => SyntraPalette.rust;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  PipelineStage? _stageFor(String? author) {
    if (author == null) return null;
    for (final stage in stages) {
      if (stage.authors.contains(author)) return stage;
    }
    return null;
  }

  void _markActive(PipelineStage stage) {
    const parallel = {'research', 'profile'};
    final index = stages.indexWhere((item) => item.id == stage.id);
    for (var i = 0; i < stages.length; i++) {
      final item = stages[i];
      if (item.id == stage.id) {
        if (_status[item.id] != StageStatus.complete) {
          _status[item.id] = StageStatus.active;
        }
        continue;
      }
      if (parallel.contains(item.id) && parallel.contains(stage.id)) {
        continue;
      }
      if (i < index && _status[item.id] == StageStatus.active) {
        _status[item.id] = StageStatus.complete;
      }
    }
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _errorTitle = null;
      _errorDetail = null;
      _liveText = '';
      _curriculum = '';
      for (final stage in stages) {
        _status[stage.id] = StageStatus.pending;
      }
    });

    try {
      final userId = 'syntra-${const Uuid().v4()}';
      final sessionId = await _client.createSession(userId: userId);
      final completeByAuthor = <String, String>{};

      await for (final event in _client.runSse(
        userId: userId,
        sessionId: sessionId,
        message: widget.brief.toIntakePrompt(),
      )) {
        if (!mounted) return;
        if (event.error != null) {
          throw AdkException(event.error!);
        }

        final stage = _stageFor(event.author);
        if (stage != null) {
          _markActive(stage);
        }

        if (event.hasText) {
          final text = event.text!;
          if (event.partial) {
            _liveText =
                text.length >= _liveText.length ? text : _liveText + text;
          } else {
            _liveText = text;
            if (event.author != null) {
              completeByAuthor[event.author!] = text;
            }
            if (event.author == 'curriculum_agent' ||
                event.author == 'syntra_orchestrator') {
              _curriculum = text;
            }
          }
        }
        setState(() {});
      }

      if (_curriculum.trim().isEmpty) {
        _curriculum = completeByAuthor['curriculum_agent'] ??
            completeByAuthor['syntra_orchestrator'] ??
            (completeByAuthor.isNotEmpty
                ? completeByAuthor.values.last
                : _liveText);
      }

      for (final stage in stages) {
        _status[stage.id] = StageStatus.complete;
      }

      if (!mounted) return;
      if (_curriculum.trim().isEmpty) {
        throw AdkException(
          'The lesson came back empty.',
          detail: 'The agents finished without a curriculum. Try again.',
        );
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CurriculumScreen(brief: widget.brief, markdown: _curriculum),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final exception = error is AdkException ? error : null;
      setState(() {
        _running = false;
        _errorTitle = exception?.message ?? 'SYNTRA could not finish this lesson.';
        _errorDetail = exception?.detail ?? error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final split = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: MeshBackground(
        accent: _accent,
        secondary: widget.brief.level?.accentSecondary,
        child: SafeArea(
          child: SyntraPageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SyntraTopBar(
                  leading: SyntraBackButton(
                    label: 'Brief',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SyntraMark(size: 48),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _errorTitle == null
                                ? 'SYNTRA is opening the lesson'
                                : 'The lesson paused',
                            style: SyntraTheme.sans(
                              color: SyntraPalette.navy,
                              fontSize: 32,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _errorTitle == null
                                ? 'Gathering sources and initialising the planning workspace.'
                                : '${widget.brief.resolvedSubject ?? 'Topic'}  ·  ${widget.brief.topic}',
                            style: SyntraTheme.sans(
                              color: SyntraPalette.inkMuted,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: split
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 340,
                              child: _PipelineCard(
                                stages: stages,
                                status: _status,
                                accent: _accent,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _StatusPanel(
                                running: _running,
                                errorTitle: _errorTitle,
                                errorDetail: _errorDetail,
                                liveText: _liveText,
                                accent: _accent,
                                onRetry: _run,
                                onBack: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          children: [
                            _PipelineCard(
                              stages: stages,
                              status: _status,
                              accent: _accent,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 320,
                              child: _StatusPanel(
                                running: _running,
                                errorTitle: _errorTitle,
                                errorDetail: _errorDetail,
                                liveText: _liveText,
                                accent: _accent,
                                onRetry: _run,
                                onBack: () => Navigator.of(context).pop(),
                              ),
                            ),
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

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({
    required this.stages,
    required this.status,
    required this.accent,
  });

  final List<PipelineStage> stages;
  final Map<String, StageStatus> status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glow: accent,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PIPELINE PROGRESS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < stages.length; index++)
            _PipelineRow(
              index: index + 1,
              stage: stages[index],
              status: status[stages[index].id] ?? StageStatus.pending,
              accent: accent,
              isLast: index == stages.length - 1,
            ),
        ],
      ),
    );
  }
}

class _PipelineRow extends StatelessWidget {
  const _PipelineRow({
    required this.index,
    required this.stage,
    required this.status,
    required this.accent,
    required this.isLast,
  });

  final int index;
  final PipelineStage stage;
  final StageStatus status;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StageStatus.pending => SyntraPalette.inkFaint,
      StageStatus.active => accent,
      StageStatus.complete => SyntraPalette.sage,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                _StepMark(index: index, status: status, color: color),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: status == StageStatus.complete
                          ? SyntraPalette.sage.withValues(alpha: 0.45)
                          : SyntraPalette.stroke,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 8 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.label,
                    style: SyntraTheme.sans(
                      color: SyntraPalette.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status == StageStatus.active
                        ? 'In progress'
                        : stage.detail,
                    style: SyntraTheme.sans(
                      color: status == StageStatus.active
                          ? accent
                          : SyntraPalette.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepMark extends StatelessWidget {
  const _StepMark({
    required this.index,
    required this.status,
    required this.color,
  });

  final int index;
  final StageStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status == StageStatus.pending ? Colors.transparent : color,
        border: Border.all(color: color, width: 1.6),
        boxShadow: status == StageStatus.active
            ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10)]
            : const [],
      ),
      child: status == StageStatus.complete
          ? const Icon(Icons.check, size: 14, color: SyntraPalette.onAccent)
          : Text(
              '$index',
              style: SyntraTheme.sans(
                color: status == StageStatus.active
                    ? SyntraPalette.onAccent
                    : color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.running,
    required this.errorTitle,
    required this.errorDetail,
    required this.liveText,
    required this.accent,
    required this.onRetry,
    required this.onBack,
  });

  final bool running;
  final String? errorTitle;
  final String? errorDetail;
  final String liveText;
  final Color accent;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final failed = errorTitle != null;

    return GlassCard(
      glow: failed ? SyntraPalette.danger : accent,
      selected: !failed,
      expand: true,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MockupChrome(accent: failed ? SyntraPalette.danger : accent),
          const SizedBox(height: 18),
          Text(
            failed ? 'COULD NOT CONNECT' : 'LIVE WORKSPACE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: failed ? SyntraPalette.danger : accent,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            failed
                ? errorTitle!
                : (liveText.trim().isEmpty
                    ? 'Gathering resources and initialising the planning workspace.'
                    : 'Drafting as the agents work'),
            style: SyntraTheme.sans(
              color: SyntraPalette.navy,
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: failed
                ? Text(
                    errorDetail ?? '',
                    style: SyntraTheme.sans(
                      color: SyntraPalette.inkMuted,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  )
                : liveText.trim().isEmpty
                    ? Text(
                        'Research, profile, prerequisites, and objectives appear here as they land.',
                        style: SyntraTheme.sans(
                          color: SyntraPalette.inkMuted,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      )
                    : SyntraLiveMarkdown(
                        data: liveText,
                        accent: accent,
                      ),
          ),
          if (running) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 4,
                color: accent,
                backgroundColor: SyntraPalette.stroke,
              ),
            ),
          ],
          if (failed) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _PanelButton(
                    label: 'Retry',
                    filled: true,
                    accent: accent,
                    onPressed: onRetry,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PanelButton(
                    label: 'Back to brief',
                    filled: false,
                    accent: accent,
                    onPressed: onBack,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.filled,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: filled ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SyntraTheme.sans(
              color: filled ? SyntraPalette.onAccent : accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
