import 'lesson_plan.dart';
import 'slide_deck.dart';

/// Texts already present in the SSE session — no extra agent calls.
class PipelineTexts {
  const PipelineTexts({
    this.learningObjectives,
    this.prerequisiteAnalysis,
    this.curriculum,
    this.lessonPlan,
    this.slides,
    this.assessment,
    this.knownKnowledge,
    this.researchPackage,
    this.explanation,
    this.interaction,
    this.adaptation,
    this.example,
  });

  final String? learningObjectives;
  final String? prerequisiteAnalysis;
  final String? curriculum;
  final String? lessonPlan;
  final String? slides;
  final String? assessment;
  final String? knownKnowledge;
  final String? researchPackage;
  final String? explanation;
  final String? interaction;
  final String? adaptation;
  final String? example;

  bool get hasTeaching =>
      _filled(explanation) ||
      _filled(interaction) ||
      _filled(adaptation) ||
      _filled(example);

  factory PipelineTexts.fromAuthors(
    Map<String, String> byAuthor, {
    String? curriculum,
    String? knownKnowledge,
  }) {
    var learningObjectives = _first(byAuthor, const [
      'learning_objectives_agent',
      'learning_objectives',
    ]);
    var prerequisiteAnalysis = _first(byAuthor, const [
      'prerequisite_agent',
      'prerequisite_analysis',
    ]);
    var lessonPlan = _first(byAuthor, const [
      'lesson_planner_agent',
      'lesson_plan',
    ]);
    var slides = _first(byAuthor, const [
      'slide_agent',
      'slides',
    ]);
    final researchPackage = _first(byAuthor, const [
      'research_agent',
      'research_package',
      'research_and_profile',
    ]);
    final explanation = _first(byAuthor, const [
      'explanation_agent',
      'explanation',
    ]);
    final interaction = _first(byAuthor, const [
      'interaction_agent',
      'interaction',
    ]);
    final adaptation = _first(byAuthor, const [
      'adaptation_agent',
      'adaptation',
    ]);
    final example = _first(byAuthor, const [
      'example_agent',
      'example',
    ]);
    final resolvedCurriculum =
        (curriculum != null && curriculum.trim().isNotEmpty)
            ? curriculum
            : _first(byAuthor, const [
                'curriculum_agent',
                'syntra_orchestrator',
                'curriculum_plan',
              ]);

    for (final value in byAuthor.values) {
      if (slides == null && SlideDeck.tryParse(value) != null) {
        slides = value;
      }
      if (lessonPlan == null && LessonPlan.tryParse(value) != null) {
        lessonPlan = value;
      }
    }
    learningObjectives ??= researchPackage;

    return PipelineTexts(
      learningObjectives: learningObjectives,
      prerequisiteAnalysis: prerequisiteAnalysis,
      curriculum: resolvedCurriculum,
      lessonPlan: lessonPlan,
      slides: slides,
      assessment: _first(byAuthor, const [
        'assessment_agent',
        'assessment',
      ]),
      knownKnowledge: knownKnowledge,
      researchPackage: researchPackage,
      explanation: explanation,
      interaction: interaction,
      adaptation: adaptation,
      example: example,
    );
  }

  static bool _filled(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String? _first(Map<String, String> byAuthor, List<String> keys) {
    for (final key in keys) {
      final value = byAuthor[key];
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }
}

enum ObjectiveStatus { planned, covered, remaining }

class LearningObjective {
  const LearningObjective({
    required this.id,
    required this.text,
    this.bloomType,
    this.status = ObjectiveStatus.planned,
  });

  final String id;
  final String text;
  final String? bloomType;
  final ObjectiveStatus status;

  bool get covered => status == ObjectiveStatus.covered;

  LearningObjective copyWith({ObjectiveStatus? status, String? bloomType}) {
    return LearningObjective(
      id: id,
      text: text,
      bloomType: bloomType ?? this.bloomType,
      status: status ?? this.status,
    );
  }
}

class PrerequisiteGap {
  const PrerequisiteGap({
    required this.text,
    this.source = 'missing',
  });

  final String text;
  final String source;
}

class LessonProgress {
  const LessonProgress({
    this.objectives = const [],
    this.gaps = const [],
    this.assessed = false,
  });

  final List<LearningObjective> objectives;
  final List<PrerequisiteGap> gaps;
  final bool assessed;

  List<LearningObjective> get covered =>
      objectives.where((item) => item.covered).toList(growable: false);

  List<LearningObjective> get remaining =>
      objectives.where((item) => !item.covered).toList(growable: false);

  bool get isEmpty => objectives.isEmpty && gaps.isEmpty;
}
