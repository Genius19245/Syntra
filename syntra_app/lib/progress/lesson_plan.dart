import '../models/research_origin.dart';

const _allowedDifficulty = {
  'foundation',
  'developing',
  'intermediate',
  'advanced',
  'exam_application',
};

class LessonStep {
  const LessonStep({
    required this.step,
    required this.title,
    required this.purpose,
    required this.activity,
    required this.estimatedMinutes,
    required this.difficulty,
    this.concepts = const [],
    this.dependsOn = const [],
  });

  final int step;
  final String title;
  final String purpose;
  final String activity;
  final int estimatedMinutes;
  final String difficulty;
  final List<String> concepts;
  final List<String> dependsOn;

  String get difficultyLabel {
    switch (difficulty) {
      case 'exam_application':
        return 'Exam application';
      case 'foundation':
      case 'developing':
      case 'intermediate':
      case 'advanced':
        return '${difficulty[0].toUpperCase()}${difficulty.substring(1)}';
      default:
        return difficulty;
    }
  }
}

class LessonPlan {
  const LessonPlan({required this.steps});

  final List<LessonStep> steps;

  bool get isEmpty => steps.isEmpty;

  int get totalMinutes => steps.fold<int>(
        0,
        (sum, step) => sum + step.estimatedMinutes,
      );

  static LessonPlan? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final json = extractJsonMap(raw);
    if (json == null) return null;
    final list = json['lesson_sequence'] ??
        json['lessonSequence'] ??
        json['lesson_sequence'] ??
        json['lessonSequence'];
    if (list is! List || list.isEmpty) return null;

    final steps = <LessonStep>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) continue;
      final data = Map<String, dynamic>.from(item);
      final title = _string(data['title']);
      if (title == null) continue;
      final difficulty = _difficulty(data['difficulty']);
      steps.add(
        LessonStep(
          step: _int(data['step']) ?? (i + 1),
          title: title,
          purpose: _string(data['purpose']) ?? '',
          activity: _string(data['activity']) ?? '',
          estimatedMinutes: _int(
                data['estimated_minutes'] ?? data['estimatedMinutes'],
              ) ??
              0,
          difficulty: difficulty,
          concepts: _stringList(data['concepts']),
          dependsOn: _stringList(data['depends_on'] ?? data['dependsOn']),
        ),
      );
    }
    if (steps.isEmpty) return null;
    return LessonPlan(steps: List.unmodifiable(steps));
  }

  static LessonPlan? fromSources(Iterable<String?> sources) {
    for (final source in sources) {
      final parsed = tryParse(source);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String _difficulty(Object? value) {
    final label = _string(value)?.toLowerCase().replaceAll(' ', '_');
    if (label != null && _allowedDifficulty.contains(label)) return label;
    return 'foundation';
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? const [] : [trimmed];
    }
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }
}
