import 'dart:convert';

import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../debug/mock_lesson.dart';
import '../../history/lesson_record.dart';
import '../../history/lesson_store.dart';
import '../../progress/models.dart';
import '../../theme/syntra_palette.dart';
import '../../theme/syntra_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mesh_background.dart';
import '../../widgets/syntra_shell.dart';
import '../result/curriculum_screen.dart';
import '../run/agent_run_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.store});

  final LessonStore? store;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final LessonStore _store = widget.store ?? LessonStore.instance;
  List<LessonRecord> _lessons = const [];
  bool _loading = true;
  String _namespace = AuthService.guestNamespace;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_load);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next =
        AuthScope.maybeOf(context)?.historyNamespace ??
        AuthService.guestNamespace;
    if (!_ready || next != _namespace) {
      _ready = true;
      _namespace = next;
      _load();
    }
  }

  @override
  void dispose() {
    _store.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    await _store.ensureSample(mockLessonRecord(), namespace: _namespace);
    final lessons = await _store.loadAll(namespace: _namespace);
    if (!mounted) return;
    setState(() {
      _lessons = lessons;
      _loading = false;
    });
  }

  void _open(LessonRecord record) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CurriculumScreen(
              brief: record.toBrief(),
              markdown: record.markdown,
              origin: record.researchOrigin,
              originBadge: record.originBadge,
              fromHistory: true,
              pipeline: _pipelineFrom(record),
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = SyntraPalette.rust;

    return Scaffold(
      body: MeshBackground(
        accent: accent,
        secondary: SyntraPalette.peach,
        child: SafeArea(
          child: SyntraPageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SyntraTopBar(
                  leading: SyntraBackButton(
                    label: 'Home',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Past lessons',
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
                  'Saved on this device. Opening a lesson does not run the pipeline again.',
                  style: SyntraTheme.sans(
                    color: SyntraPalette.inkMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: accent),
                        )
                      : _lessons.isEmpty
                      ? const _EmptyHistory()
                      : ListView.separated(
                          itemCount: _lessons.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final record = _lessons[index];
                            return _HistoryTile(
                              record: record,
                              onOpen: () => _open(record),
                              onRunAgain: () {
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    pageBuilder:
                                        (
                                          context,
                                          animation,
                                          secondaryAnimation,
                                        ) => AgentRunScreen(
                                          brief: record.toBrief(),
                                          fromHistory: true,
                                        ),
                                    transitionsBuilder:
                                        (
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
                            );
                          },
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No lessons yet',
            style: SyntraTheme.sans(
              color: SyntraPalette.navy,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When SYNTRA finishes a curriculum, it is saved here so you can reopen it without waiting on research again.',
            style: SyntraTheme.sans(
              color: SyntraPalette.inkMuted,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.record,
    required this.onOpen,
    required this.onRunAgain,
  });

  final LessonRecord record;
  final VoidCallback onOpen;
  final VoidCallback onRunAgain;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.topic.isEmpty ? 'Untitled lesson' : record.topic,
                  style: SyntraTheme.sans(
                    color: SyntraPalette.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (record.originBadge != null) ...[
                const SizedBox(width: 8),
                StatusBadge(label: record.originBadge!, filled: false),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (record.subject != null) _MetaChip(label: record.subject!),
              if (record.level != null) _MetaChip(label: record.level!),
              if (record.board != null) _MetaChip(label: record.board!),
              _MetaChip(label: record.savedLabel),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Reopen',
                style: SyntraTheme.sans(
                  color: SyntraPalette.rust,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onRunAgain,
                child: Text(
                  'Run again',
                  style: SyntraTheme.sans(
                    color: SyntraPalette.inkMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

PipelineTexts? _pipelineFrom(LessonRecord record) {
  final teacher = record.teacherPayload;
  final quiz = record.quizPayload;
  if (teacher == null && quiz == null) return null;
  return PipelineTexts(
    learningObjectives: _payloadText(teacher?['learningObjectives']),
    prerequisiteAnalysis: _payloadText(teacher?['prerequisiteAnalysis']),
    curriculum: record.markdown,
    lessonPlan: _payloadText(teacher?['lessonPlan']),
    slides: _payloadText(teacher?['slides']),
    assessment:
        _payloadText(quiz?['markdown']) ?? _payloadText(teacher?['assessment']),
    knownKnowledge: _payloadText(teacher?['knownKnowledge']),
    researchPackage: _payloadText(teacher?['researchPackage']),
    explanation: _payloadText(teacher?['explanation']),
    interaction: _payloadText(teacher?['interaction']),
    adaptation: _payloadText(teacher?['adaptation']),
    example: _payloadText(teacher?['example']),
  );
}

String? _payloadText(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  if (value is Map || value is List) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}
