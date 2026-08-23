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
  });

  final String? learningObjectives;
  final String? prerequisiteAnalysis;
  final String? curriculum;
  final String? lessonPlan;
  final String? slides;
  final String? assessment;
  final String? knownKnowledge;

  factory PipelineTexts.fromAuthors(
    Map<String, String> byAuthor, {
    String? curriculum,
    String? knownKnowledge,
  }) {
    return PipelineTexts(
      learningObjectives: _first(byAuthor, const [
        'learning_objectives_agent',
        'learning_objectives',
      ]),
      prerequisiteAnalysis: _first(byAuthor, const [
        'prerequisite_agent',
        'prerequisite_analysis',
      ]),
      curriculum: (curriculum != null && curriculum.trim().isNotEmpty)
          ? curriculum
          : _first(byAuthor, const [
              'curriculum_agent',
              'syntra_orchestrator',
            ]),
      lessonPlan: _first(byAuthor, const [
        'lesson_planner_agent',
        'lesson_plan',
      ]),
      slides: _first(byAuthor, const [
        'slide_agent',
        'slides',
      ]),
      assessment: _first(byAuthor, const [
        'assessment_agent',
        'assessment',
      ]),
      knownKnowledge: knownKnowledge,
    );
  }

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
