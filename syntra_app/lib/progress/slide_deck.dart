import '../models/research_origin.dart';

const _allowedDifficulty = {
  'foundation',
  'developing',
  'intermediate',
  'advanced',
  'exam_application',
};

const _allowedVisual = {
  'none',
  'diagram',
  'ai_generated',
  'image',
  'graph',
  'equation',
  'timeline',
  'comparison',
  'flowchart',
  'interactive',
};

class VisualAsset {
  const VisualAsset({
    required this.prompt,
    required this.educationalPurpose,
    this.aspectRatio = '16:9',
    this.assetId,
    this.status,
    this.url,
  });

  final String prompt;
  final String educationalPurpose;
  final String aspectRatio;
  final String? assetId;
  final String? status;
  final String? url;

  bool get ready => url != null && url!.trim().isNotEmpty;
}

class DiagramSpec {
  const DiagramSpec({
    required this.diagramType,
    required this.subject,
    required this.description,
    this.concepts = const [],
  });

  final String diagramType;
  final String subject;
  final String description;
  final List<String> concepts;
}

class Slide {
  const Slide({
    required this.number,
    required this.title,
    required this.purpose,
    required this.visualType,
    required this.difficulty,
    this.content = const [],
    this.visualDescription = '',
    this.equation,
    this.teacherExplanation = '',
    this.interaction,
    this.estimatedMinutes = 0,
    this.visualAsset,
    this.diagramSpec,
  });

  final int number;
  final String title;
  final String purpose;
  final List<String> content;
  final String visualType;
  final String visualDescription;
  final String? equation;
  final String teacherExplanation;
  final String? interaction;
  final int estimatedMinutes;
  final String difficulty;
  final VisualAsset? visualAsset;
  final DiagramSpec? diagramSpec;

  bool get hasVisual =>
      visualType != 'none' || visualAsset != null || diagramSpec != null;

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

  String get visualLabel {
    switch (visualType) {
      case 'ai_generated':
      case 'image':
        return visualAsset?.ready == true ? 'Image' : 'Illustration';
      case 'diagram':
        return 'Diagram';
      case 'graph':
        return 'Graph';
      case 'equation':
        return 'Equation';
      case 'timeline':
        return 'Timeline';
      case 'comparison':
        return 'Comparison';
      case 'flowchart':
        return 'Flowchart';
      case 'interactive':
        return 'Interactive';
      default:
        return 'Board';
    }
  }
}

class SlideDeck {
  const SlideDeck({required this.slides, this.lessonTitle});

  final List<Slide> slides;
  final String? lessonTitle;

  bool get isEmpty => slides.isEmpty;

  int get totalMinutes => slides.fold<int>(
        0,
        (sum, slide) => sum + slide.estimatedMinutes,
      );

  static SlideDeck? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final json = extractJsonMap(raw);
    if (json == null) return null;
    final list = json['slides'];
    if (list is! List || list.isEmpty) return null;

    final slides = <Slide>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) continue;
      final data = Map<String, dynamic>.from(item);
      final title = _string(data['title']);
      if (title == null) continue;
      slides.add(
        Slide(
          number: _int(data['slide_number'] ?? data['slideNumber'] ?? data['slide']) ??
              (i + 1),
          title: title,
          purpose: _string(data['purpose']) ?? '',
          content: _stringList(data['content'] ?? data['bullets']),
          visualType: _visual(data['visual_type'] ?? data['visualType']),
          visualDescription: _string(
                data['visual_description'] ?? data['visualDescription'],
              ) ??
              '',
          equation: _equation(data['equation']),
          teacherExplanation: _string(
                data['teacher_explanation'] ?? data['teacherExplanation'],
              ) ??
              '',
          interaction: _string(data['interaction']),
          estimatedMinutes: _int(
                data['estimated_minutes'] ?? data['estimatedMinutes'],
              ) ??
              0,
          difficulty: _difficulty(data['difficulty']),
          visualAsset: _visualAsset(
            data['visual_asset'] ??
                data['visualAsset'] ??
                data['image_asset'] ??
                data['imageAsset'],
          ),
          diagramSpec: _diagramSpec(
            data['diagram_spec'] ?? data['diagramSpec'],
          ),
        ),
      );
    }
    if (slides.isEmpty) return null;
    return SlideDeck(
      slides: List.unmodifiable(slides),
      lessonTitle: _string(json['lesson_title'] ?? json['lessonTitle']),
    );
  }

  static SlideDeck? fromSources(Iterable<String?> sources) {
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

  static String _visual(Object? value) {
    final label = _string(value)?.toLowerCase().replaceAll(' ', '_');
    if (label == 'image' || label == 'ai_image') return 'ai_generated';
    if (label != null && _allowedVisual.contains(label)) return label;
    return 'none';
  }

  static String? _equation(Object? value) {
    if (value is String) return _string(value);
    if (value is Map) {
      return _string(value['equation'] ?? value['latex'] ?? value['text']);
    }
    return null;
  }

  static VisualAsset? _visualAsset(Object? value) {
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);
    final prompt = _string(data['prompt']) ?? '';
    final purpose = _string(
          data['educational_purpose'] ?? data['educationalPurpose'],
        ) ??
        '';
    final url = _string(data['url']);
    if (prompt.isEmpty && purpose.isEmpty && url == null) return null;
    return VisualAsset(
      prompt: prompt,
      educationalPurpose: purpose,
      aspectRatio:
          _string(data['aspect_ratio'] ?? data['aspectRatio']) ?? '16:9',
      assetId: _string(data['asset_id'] ?? data['assetId']),
      status: _string(data['status']),
      url: url,
    );
  }

  static DiagramSpec? _diagramSpec(Object? value) {
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);
    final description = _string(data['description']) ?? '';
    final diagramType = _string(data['diagram_type'] ?? data['diagramType']) ?? '';
    if (description.isEmpty && diagramType.isEmpty) return null;
    return DiagramSpec(
      diagramType: diagramType,
      subject: _string(data['subject']) ?? '',
      description: description,
      concepts: _stringList(data['concepts']),
    );
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
        if (item is String && item.trim().isNotEmpty)
          item.trim()
        else if (item != null && item is! Map)
          item.toString().trim(),
    ].where((item) => item.isNotEmpty).toList(growable: false);
  }
}
