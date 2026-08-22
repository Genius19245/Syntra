import 'package:flutter_test/flutter_test.dart';
import 'package:syntra_app/data/intake_catalog.dart';
import 'package:syntra_app/models/learner_brief.dart';

void main() {
  test('level selection reshapes board, depth, and subject', () {
    final brief = LearnerBrief();
    brief.selectLevel(IntakeCatalog.levelById('GCSE'));

    expect(brief.level!.showExamBoard, isTrue);
    expect(brief.depth, 'GCSE');
    expect(brief.level!.boards, contains('AQA'));

    brief.selectBoard('AQA');
    brief.selectSubject('Physics');
    brief.setTopic('Electricity');

    brief.selectLevel(IntakeCatalog.levelById('Undergraduate'));

    expect(brief.board, isNull);
    expect(brief.level!.showExamBoard, isFalse);
    expect(brief.depth, 'Undergraduate');
    expect(brief.subject, 'Physics');
    expect(brief.topic, 'Electricity');
  });

  test('incompatible subject resets topic', () {
    final brief = LearnerBrief();
    brief.selectLevel(IntakeCatalog.levelById('Professional'));
    brief.selectSubject('Cybersecurity');
    brief.setTopic('Threat modelling');

    brief.selectLevel(IntakeCatalog.levelById('Primary'));

    expect(brief.subject, isNull);
    expect(brief.topic, isEmpty);
    expect(brief.level!.showExamBoard, isFalse);
  });

  test('intake prompt copies explicit fields', () {
    final brief = LearnerBrief()
      ..selectLevel(IntakeCatalog.levelById('A-Level'))
      ..selectBoard('OCR')
      ..selectSubject('Physics')
      ..setTopic('Quantum physics')
      ..selectGoal('exam')
      ..selectDepth('A-Level');

    final prompt = brief.toIntakePrompt();
    expect(prompt, contains('Education Level: A-Level'));
    expect(prompt, contains('Exam Board: OCR'));
    expect(prompt, contains('Subject: Physics'));
    expect(prompt, contains('Topic: Quantum physics'));
    expect(prompt, contains('Learning Goal: Prepare for an exam'));
    expect(prompt, contains('Strict verification: no'));
    expect(brief.isLaunchReady, isTrue);

    brief.setStrictVerification(true);
    expect(brief.toIntakePrompt(), contains('Strict verification: yes'));
  });

  test('subject and topic lists are unique', () {
    for (final level in IntakeCatalog.levels) {
      final subjects = IntakeCatalog.subjectsFor(level);
      expect(subjects.toSet().length, subjects.length, reason: level.id);
    }

    final topics = IntakeCatalog.topicsFor(
      levelId: 'A-Level',
      subject: 'Mathematics',
    );
    expect(topics.toSet().length, topics.length);
    expect(topics.where((topic) => topic == 'Calculus').length, 1);
  });
}
