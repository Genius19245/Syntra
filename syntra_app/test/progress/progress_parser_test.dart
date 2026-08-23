import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syntra_app/progress/models.dart';
import 'package:syntra_app/progress/parser.dart';

String fixture(String name) =>
    File('test/progress/fixtures/$name').readAsStringSync();

void main() {
  test('parses structured learning-objective markdown', () {
    final progress = ProgressParser.parse(
      PipelineTexts(learningObjectives: fixture('objectives.md')),
    );

    expect(progress.objectives.map((item) => item.text).toList(), [
      'Explain how a changing magnetic flux produces an induced electromotive force.',
      'Calculate the induced EMF for a given rate of change of flux.',
      'Apply Lenz\'s law to predict the direction of an induced current.',
      'Compare Faraday\'s law statements used in A-Level exam questions.',
    ]);
    expect(progress.objectives.map((item) => item.bloomType).toList(), [
      'Understanding',
      'Application',
      'Application',
      'Analysis',
    ]);
    expect(progress.covered, hasLength(4));
    expect(progress.assessed, isFalse);
  });

  test('parses prerequisite gaps from Missing and skips mastered items', () {
    final progress = ProgressParser.parse(
      PipelineTexts(
        prerequisiteAnalysis: fixture('prerequisites.md'),
        knownKnowledge: 'Electric current and potential difference',
      ),
    );

    expect(progress.gaps.map((item) => item.text).toList(), [
      'Magnetic flux and flux density',
      'Right-hand grip rule for field direction',
    ]);
    expect(progress.gaps.every((item) => item.source == 'missing'), isTrue);
  });

  test('falls back to curriculum markdown when agent texts are absent', () {
    final progress = ProgressParser.parse(
      PipelineTexts(curriculum: fixture('curriculum.md')),
    );

    expect(progress.objectives, hasLength(3));
    expect(
      progress.objectives.first.text,
      contains('changing magnetic flux'),
    );
    expect(progress.gaps.map((item) => item.text), containsAll([
      'Magnetic flux and flux density',
      'Right-hand grip rule for field direction',
    ]));
  });

  test('extracts section headings when no objective list exists', () {
    final progress = ProgressParser.parse(
      PipelineTexts(curriculum: fixture('curriculum_headings_only.md')),
    );

    expect(progress.objectives.map((item) => item.text).toList(), [
      'Charged particles in atoms',
      'How ions form',
      'Giant ionic lattices',
    ]);
    expect(progress.gaps, isEmpty);
  });

  test('prefers structured JSON objectives and gaps', () {
    final progress = ProgressParser.parse(
      PipelineTexts(learningObjectives: fixture('objectives.json')),
    );

    expect(progress.objectives, hasLength(3));
    expect(progress.objectives.first.bloomType, 'Knowledge');
    expect(progress.objectives.first.text, startsWith('Define magnetic flux'));
  });

  test('marks objectives covered only when related quiz items are correct', () {
    final progress = ProgressParser.parse(
      PipelineTexts(
        learningObjectives: fixture('objectives.md'),
        assessment: fixture('assessment.md'),
      ),
    );

    expect(progress.assessed, isTrue);
    expect(progress.covered.map((item) => item.id).toList(), ['lo-1', 'lo-3']);
    expect(progress.remaining.map((item) => item.id).toList(), ['lo-2', 'lo-4']);
  });

  test('assessment JSON matches by objective index', () {
    final progress = ProgressParser.parse(
      PipelineTexts(
        learningObjectives: fixture('objectives.md'),
        assessment: '''
{
  "results": [
    {"objective": 2, "correct": true},
    {"objective": 1, "correct": false}
  ]
}
''',
      ),
    );

    expect(progress.covered.map((item) => item.id).toList(), ['lo-2']);
    expect(progress.remaining.first.id, 'lo-1');
  });

  test('known knowledge removes overlapping prerequisite gaps', () {
    final progress = ProgressParser.parse(
      PipelineTexts(
        prerequisiteAnalysis: fixture('prerequisites.md'),
        knownKnowledge: 'The student knows magnetic flux and flux density',
      ),
    );

    expect(
      progress.gaps.map((item) => item.text),
      isNot(contains('Magnetic flux and flux density')),
    );
    expect(
      progress.gaps.map((item) => item.text),
      contains('Right-hand grip rule for field direction'),
    );
  });

  test('core prerequisites become gaps when knowledge is missing', () {
    const markdown = '''
# Prerequisite Analysis

## Core Prerequisites
1. Balanced chemical equations
2. Mole calculations

## Learner Knowledge

Insufficient learner knowledge data.
''';
    final progress = ProgressParser.parse(
      const PipelineTexts(prerequisiteAnalysis: markdown),
    );

    expect(progress.gaps.map((item) => item.text).toList(), [
      'Balanced chemical equations',
      'Mole calculations',
    ]);
    expect(progress.gaps.first.source, 'core');
  });

  test('PipelineTexts reads existing SSE author keys only', () {
    final texts = PipelineTexts.fromAuthors(
      {
        'learning_objectives_agent': 'objectives here',
        'prerequisite_agent': 'prereqs here',
        'curriculum_agent': 'curriculum here',
        'assessment_agent': 'quiz here',
        'research_agent': 'must not be sent to a new agent',
      },
      knownKnowledge: 'current',
    );

    expect(texts.learningObjectives, 'objectives here');
    expect(texts.prerequisiteAnalysis, 'prereqs here');
    expect(texts.curriculum, 'curriculum here');
    expect(texts.assessment, 'quiz here');
    expect(texts.knownKnowledge, 'current');
  });
}
