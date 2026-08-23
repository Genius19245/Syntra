import '../models/research_origin.dart';
import 'models.dart';

/// Deterministic progress from existing agent markdown/JSON.
/// Does not call an LLM and does not re-run research.
class ProgressParser {
  const ProgressParser._();

  static LessonProgress parse(PipelineTexts texts) {
    final objectives = _extractObjectives(texts);
    final gaps = _extractGaps(texts);
    final assessment = _extractAssessment(texts.assessment);
    if (assessment == null) {
      return LessonProgress(
        objectives: [
          for (final item in objectives)
            item.copyWith(status: ObjectiveStatus.covered),
        ],
        gaps: gaps,
      );
    }
    return LessonProgress(
      objectives: _applyAssessment(objectives, assessment),
      gaps: gaps,
      assessed: true,
    );
  }
}

class _QuizItem {
  const _QuizItem({this.objectiveIndex, this.text, required this.correct});

  final int? objectiveIndex;
  final String? text;
  final bool correct;
}

final _headingRe = RegExp(r'^(#{1,6})\s+(.+?)\s*$', multiLine: true);
final _listItemRe = RegExp(
  r'^\s*(?:(?:\d+)[\.)]\s+|[-*•]\s+(?:\[[ xX]\]\s+)?)(.+)$',
);
final _checkboxRe = RegExp(r'^\s*[-*•]\s+\[([ xX])\]\s+(.+)$');
final _objectiveIndexRe = RegExp(
  r'(?:objective|learning objective|\blo)\s*(\d+)',
  caseSensitive: false,
);
final _verdictRe = RegExp(
  r'^(.*?)\s*[—–\-:|]\s*(correct|incorrect|passed?|failed?|wrong|right|yes|no)\s*\.?$',
  caseSensitive: false,
);
final _wordRe = RegExp(r"[a-z0-9']+", caseSensitive: false);
final _copyFromRe = RegExp(r'^copy from the\b', caseSensitive: false);
final _stemRe = RegExp(
  r'^(?:by the end\b|the learner will\b|learners? will\b|'
  r'students? will\b|pupils? will\b)',
  caseSensitive: false,
);

const _skipExact = {
  'specific',
  'measurable',
  'level appropriate',
  'relevant',
  'observable',
  'knowledge',
  'understanding',
  'application',
  'analysis',
  'evaluation',
  'creation',
  'high',
  'medium',
  'low',
  'core',
  'helpful',
  'advanced',
};

const _bloomNames = {
  'knowledge',
  'understanding',
  'application',
  'analysis',
  'evaluation',
  'creation',
};

List<LearningObjective> _extractObjectives(PipelineTexts texts) {
  final fromJson = _objectivesFromJson(texts.learningObjectives) ??
      _objectivesFromJson(texts.curriculum);
  if (fromJson != null && fromJson.isNotEmpty) {
    return fromJson;
  }

  final fromStructured = _objectivesFromStructuredMarkdown(
        texts.learningObjectives,
      ) ??
      _objectivesFromStructuredMarkdown(texts.curriculum);
  if (fromStructured != null && fromStructured.isNotEmpty) {
    return fromStructured;
  }

  return _objectivesFromHeadings(texts.curriculum);
}

List<LearningObjective>? _objectivesFromJson(String? raw) {
  final json = _asJsonObject(raw);
  if (json == null) return null;

  final collected = <String>[];
  final types = <String?>[];
  void take(dynamic value) {
    if (value is String) {
      final cleaned = _cleanObjective(value);
      if (cleaned != null) {
        collected.add(cleaned);
        types.add(null);
      }
      return;
    }
    if (value is Map) {
      final text = value['text'] ??
          value['objective'] ??
          value['title'] ??
          value['statement'];
      final cleaned = text is String ? _cleanObjective(text) : null;
      if (cleaned != null) {
        collected.add(cleaned);
        final bloom = value['type'] ?? value['bloom'] ?? value['bloom_type'];
        types.add(bloom is String ? bloom : null);
      }
    }
  }

  for (final key in const [
    'objectives',
    'learning_objectives',
    'learningObjectives',
  ]) {
    final value = json[key];
    if (value is List) {
      for (final item in value) {
        take(item);
      }
    }
  }

  if (collected.isEmpty) return null;
  return [
    for (var i = 0; i < collected.length; i++)
      LearningObjective(
        id: 'lo-${i + 1}',
        text: collected[i],
        bloomType: types[i],
      ),
  ];
}

List<LearningObjective>? _objectivesFromStructuredMarkdown(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;

  final objectivesBody = _sectionBody(
        raw,
        const ['objectives'],
        preferLevel: 2,
      ) ??
      _sectionBody(
        raw,
        const ['learning objectives'],
        preferLevel: 2,
      );
  var items = _listItems(objectivesBody ?? '');
  if (items.isEmpty && objectivesBody != null) {
    items = _paragraphObjectives(objectivesBody);
  }

  final cleaned = [
    for (final item in items)
      if (_cleanObjective(item) != null) _cleanObjective(item)!,
  ];
  if (cleaned.isEmpty) return null;

  final typeBody = _sectionBody(raw, const ['objective types'], preferLevel: 2);
  final typeItems = [
    for (final item in _listItems(typeBody ?? ''))
      if (_bloomNames.contains(item.trim().toLowerCase())) item.trim(),
  ];

  return [
    for (var i = 0; i < cleaned.length; i++)
      LearningObjective(
        id: 'lo-${i + 1}',
        text: cleaned[i],
        bloomType: i < typeItems.length ? typeItems[i] : _bloomSuffix(cleaned[i]),
      ),
  ];
}

List<LearningObjective> _objectivesFromHeadings(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];

  final structure = _sectionBody(
    raw,
    const ['curriculum structure', 'lesson structure', 'teaching sections'],
    preferLevel: 2,
  );
  final headings = <String>[];
  final source = structure ?? raw;
  for (final match in _headingRe.allMatches(source)) {
    final level = match.group(1)!.length;
    if (level < 3) continue;
    final title = _stripHeadingNumber(match.group(2)!);
    final cleaned = _cleanObjective(title);
    if (cleaned != null) headings.add(cleaned);
  }
  if (headings.isEmpty) {
    final sequence = _sectionBody(
      raw,
      const ['teaching sequence'],
      preferLevel: 2,
    );
    for (final item in _listItems(sequence ?? '')) {
      final cleaned = _cleanObjective(item);
      if (cleaned != null) headings.add(cleaned);
    }
  }
  return [
    for (var i = 0; i < headings.length; i++)
      LearningObjective(id: 'lo-${i + 1}', text: headings[i]),
  ];
}

List<PrerequisiteGap> _extractGaps(PipelineTexts texts) {
  final fromJson = _gapsFromJson(texts.prerequisiteAnalysis) ??
      _gapsFromJson(texts.curriculum);
  if (fromJson != null && fromJson.isNotEmpty) {
    return _subtractKnown(fromJson, texts.knownKnowledge);
  }

  final fromMarkdown = _gapsFromMarkdown(
        texts.prerequisiteAnalysis,
        texts.knownKnowledge,
      ) ??
      _gapsFromMarkdown(texts.curriculum, texts.knownKnowledge);
  return fromMarkdown ?? const [];
}

List<PrerequisiteGap>? _gapsFromJson(String? raw) {
  final json = _asJsonObject(raw);
  if (json == null) return null;

  final missing = _stringList(
    json['missing'] ??
        json['gaps'] ??
        (json['learner_knowledge'] is Map
            ? (json['learner_knowledge'] as Map)['missing']
            : null),
  );
  if (missing.isNotEmpty) {
    return [for (final item in missing) PrerequisiteGap(text: item)];
  }

  final recommended = _stringList(
    json['recommended_preparation'] ?? json['recommendedPreparation'],
  );
  if (recommended.isNotEmpty) {
    return [
      for (final item in recommended)
        PrerequisiteGap(text: item, source: 'recommended'),
    ];
  }

  final core = _stringList(
    json['core'] ??
        (json['structured'] is Map
            ? (json['structured'] as Map)['core']
            : null),
  );
  if (core.isNotEmpty) {
    return [for (final item in core) PrerequisiteGap(text: item, source: 'core')];
  }
  return null;
}

List<PrerequisiteGap>? _gapsFromMarkdown(String? raw, String? knownKnowledge) {
  if (raw == null || raw.trim().isEmpty) return null;

  final missingBody = _sectionBody(
    raw,
    const ['missing'],
    preferLevel: 3,
  );
  var items = [
    for (final item in _listItems(missingBody ?? ''))
      if (_cleanGap(item) != null) _cleanGap(item)!,
  ];
  var source = 'missing';

  if (items.isEmpty) {
    final recommended = _sectionBody(
      raw,
      const ['recommended preparation', 'recommended revision'],
      preferLevel: 2,
    );
    items = [
      for (final item in _listItems(recommended ?? ''))
        if (_cleanGap(item) != null) _cleanGap(item)!,
    ];
    source = 'recommended';
  }

  final knowledgeUnavailable = RegExp(
    r'insufficient learner knowledge',
    caseSensitive: false,
  ).hasMatch(raw);
  final knownEmpty = knownKnowledge == null || knownKnowledge.trim().isEmpty;

  if (items.isEmpty && (knowledgeUnavailable || knownEmpty)) {
    final core = _sectionBody(
      raw,
      const ['core prerequisites', 'prerequisites'],
      preferLevel: 2,
    );
    items = [
      for (final item in _listItems(core ?? ''))
        if (_cleanGap(item) != null) _cleanGap(item)!,
    ];
    source = 'core';
  }

  if (items.isEmpty) return null;
  final gaps = [
    for (final item in items) PrerequisiteGap(text: item, source: source),
  ];
  return _subtractKnown(gaps, knownKnowledge);
}

List<PrerequisiteGap> _subtractKnown(
  List<PrerequisiteGap> gaps,
  String? knownKnowledge,
) {
  if (knownKnowledge == null || knownKnowledge.trim().isEmpty) return gaps;
  return [
    for (final gap in gaps)
      if (!_overlaps(gap.text, knownKnowledge)) gap,
  ];
}

List<_QuizItem>? _extractAssessment(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final fromJson = _assessmentFromJson(raw);
  if (fromJson != null && fromJson.isNotEmpty) return fromJson;
  final fromMarkdown = _assessmentFromMarkdown(raw);
  if (fromMarkdown.isEmpty) return null;
  return fromMarkdown;
}

List<_QuizItem>? _assessmentFromJson(String? raw) {
  final json = _asJsonObject(raw);
  if (json == null) return null;
  final items = json['results'] ??
      json['items'] ??
      json['questions'] ??
      json['quiz'] ??
      json['answers'];
  if (items is! List) return null;

  final parsed = <_QuizItem>[];
  for (final item in items) {
    if (item is! Map) continue;
    final correct = _asCorrect(
      item['correct'] ?? item['passed'] ?? item['score'] ?? item['result'],
    );
    if (correct == null) continue;
    final index = _asIndex(
      item['objective_index'] ??
          item['objectiveIndex'] ??
          item['objective'] ??
          item['lo'] ??
          item['index'],
    );
    final textValue = item['text'] ??
        item['prompt'] ??
        item['question'] ??
        (item['objective'] is String ? item['objective'] : null);
    parsed.add(
      _QuizItem(
        objectiveIndex: index,
        text: textValue is String ? textValue.trim() : null,
        correct: correct,
      ),
    );
  }
  return parsed.isEmpty ? null : parsed;
}

List<_QuizItem> _assessmentFromMarkdown(String? raw) {
  if (raw == null) return const [];
  final items = <_QuizItem>[];
  for (final line in raw.split('\n')) {
    final checkbox = _checkboxRe.firstMatch(line);
    if (checkbox != null) {
      items.add(
        _QuizItem(
          objectiveIndex: _indexIn(checkbox.group(2)!),
          text: _stripObjectivePrefix(checkbox.group(2)!),
          correct: checkbox.group(1)!.trim().isNotEmpty,
        ),
      );
      continue;
    }
    final list = _listItemRe.firstMatch(line);
    if (list == null) continue;
    final body = list.group(1)!.trim();
    final verdict = _verdictRe.firstMatch(body);
    if (verdict == null) continue;
    final flag = _asCorrect(verdict.group(2));
    if (flag == null) continue;
    final stem = verdict.group(1)!.trim();
    items.add(
      _QuizItem(
        objectiveIndex: _indexIn(stem) ?? _indexIn(line),
        text: _stripObjectivePrefix(stem),
        correct: flag,
      ),
    );
  }
  return items;
}

List<LearningObjective> _applyAssessment(
  List<LearningObjective> objectives,
  List<_QuizItem> items,
) {
  if (objectives.isEmpty) return objectives;
  final scores = <String, List<bool>>{
    for (final objective in objectives) objective.id: <bool>[],
  };

  final unmatched = <_QuizItem>[];
  for (final item in items) {
    LearningObjective? match;
    if (item.objectiveIndex != null) {
      final index = item.objectiveIndex!;
      if (index >= 1 && index <= objectives.length) {
        match = objectives[index - 1];
      }
    }
    if (match == null && item.text != null && item.text!.trim().isNotEmpty) {
      for (final objective in objectives) {
        if (_overlaps(objective.text, item.text!)) {
          match = objective;
          break;
        }
      }
    }
    if (match == null) {
      unmatched.add(item);
      continue;
    }
    scores[match.id]!.add(item.correct);
  }

  var cursor = 0;
  for (final item in unmatched) {
    while (cursor < objectives.length &&
        scores[objectives[cursor].id]!.isNotEmpty) {
      cursor++;
    }
    if (cursor >= objectives.length) break;
    scores[objectives[cursor].id]!.add(item.correct);
    cursor++;
  }

  return [
    for (final objective in objectives)
      objective.copyWith(
        status: scores[objective.id]!.isNotEmpty &&
                scores[objective.id]!.every((value) => value)
            ? ObjectiveStatus.covered
            : ObjectiveStatus.remaining,
      ),
  ];
}

Map<String, dynamic>? _asJsonObject(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (!(trimmed.startsWith('{') || trimmed.startsWith('```'))) return null;
  return extractJsonMap(trimmed);
}

List<String> _stringList(dynamic value) {
  if (value is String) {
    final cleaned = _cleanGap(value);
    return cleaned == null ? const [] : [cleaned];
  }
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && _cleanGap(item) != null) _cleanGap(item)!,
  ];
}

String? _sectionBody(
  String markdown,
  List<String> titles, {
  int? preferLevel,
}) {
  final wanted = titles.map(_normaliseHeading).toSet();
  final matches = _headingRe.allMatches(markdown).toList();
  for (var i = 0; i < matches.length; i++) {
    final level = matches[i].group(1)!.length;
    if (preferLevel != null && level != preferLevel) continue;
    if (!wanted.contains(_normaliseHeading(matches[i].group(2)!))) continue;
    final start = matches[i].end;
    var end = markdown.length;
    for (var j = i + 1; j < matches.length; j++) {
      if (matches[j].group(1)!.length <= level) {
        end = matches[j].start;
        break;
      }
    }
    return markdown.substring(start, end);
  }
  if (preferLevel != null) {
    return _sectionBody(markdown, titles);
  }
  return null;
}

List<String> _listItems(String body) {
  final items = <String>[];
  for (final rawLine in body.split('\n')) {
    final line = rawLine.trimRight();
    final match = _listItemRe.firstMatch(line);
    if (match == null) continue;
    items.add(match.group(1)!.trim());
  }
  return items;
}

List<String> _paragraphObjectives(String body) {
  return [
    for (final line in body.split('\n'))
      if (_cleanObjective(line.trim()) != null) line.trim(),
  ];
}

String _normaliseHeading(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _stripHeadingNumber(String value) {
  return value.replaceFirst(RegExp(r'^\d+[\.)]\s*'), '').trim();
}

String _stripObjectivePrefix(String value) {
  return value
      .replaceFirst(
        RegExp(r'^(?:objective|learning objective|\blo)\s*\d+\s*[:.)-]?\s*',
            caseSensitive: false),
        '',
      )
      .trim();
}

String? _cleanObjective(String value) {
  var text = value.trim();
  if (text.isEmpty) return null;
  text = text.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'),
    (match) => match.group(1)!,
  );
  text = text.replaceAll(RegExp(r'^[*_`]+|[*_`]+$'), '');
  final bloom = _bloomSuffix(text);
  if (bloom != null) {
    text = text
        .replaceFirst(
          RegExp(
            r'\s*[\(—–\-:|]\s*(knowledge|understanding|application|analysis|evaluation|creation)\s*\)?\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }
  if (_stemRe.hasMatch(text) || _copyFromRe.hasMatch(text)) return null;
  if (_skipExact.contains(text.toLowerCase())) return null;
  if (RegExp(r'insufficient learner knowledge', caseSensitive: false)
      .hasMatch(text)) {
    return null;
  }
  final words = text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  if (words.length < 3 || text.length < 8) return null;
  return text;
}

String? _cleanGap(String value) {
  var text = value.trim();
  if (text.isEmpty) return null;
  text = text.replaceAll(RegExp(r'^[*_`]+|[*_`]+$'), '');
  if (_copyFromRe.hasMatch(text)) return null;
  if (_skipExact.contains(text.toLowerCase())) return null;
  if (RegExp(r'insufficient learner knowledge', caseSensitive: false)
      .hasMatch(text)) {
    return null;
  }
  if (text.length < 3) return null;
  return text;
}

String? _bloomSuffix(String value) {
  final match = RegExp(
    r'[\(—–\-:|]\s*(knowledge|understanding|application|analysis|evaluation|creation)\s*\)?\s*$',
    caseSensitive: false,
  ).firstMatch(value);
  final name = match?.group(1);
  if (name == null) return null;
  return name[0].toUpperCase() + name.substring(1).toLowerCase();
}

Set<String> _tokens(String value) {
  return {
    for (final match in _wordRe.allMatches(value.toLowerCase()))
      if (match.group(0)!.length > 3) match.group(0)!,
  };
}

bool _overlaps(String left, String right) {
  final a = left.trim().toLowerCase();
  final b = right.trim().toLowerCase();
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b || a.contains(b) || b.contains(a)) return true;
  final ta = _tokens(left);
  final tb = _tokens(right);
  if (ta.isEmpty || tb.isEmpty) return false;
  final shared = ta.intersection(tb).length;
  return shared / ta.length >= 0.4 || shared / tb.length >= 0.4;
}

int? _indexIn(String value) {
  final match = _objectiveIndexRe.firstMatch(value);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

int? _asIndex(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final asInt = int.tryParse(value.trim());
    if (asInt != null) return asInt;
    return _indexIn(value);
  }
  return null;
}

bool? _asCorrect(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value > 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'correct':
      case 'passed':
      case 'pass':
      case 'right':
      case 'yes':
      case 'true':
        return true;
      case 'incorrect':
      case 'failed':
      case 'fail':
      case 'wrong':
      case 'no':
      case 'false':
        return false;
    }
  }
  return null;
}
