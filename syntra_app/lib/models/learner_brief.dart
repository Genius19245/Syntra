import 'package:flutter/foundation.dart';

import '../data/intake_catalog.dart';

class LearnerBrief extends ChangeNotifier {
  String? levelId;
  String? board;
  String? customBoard;
  String? subject;
  String customSubject = '';
  String topic = '';
  String? goalId;
  String priorKnowledge = '';
  String? depth;

  EducationLevelSpec? get level =>
      levelId == null ? null : IntakeCatalog.levelById(levelId!);

  String? get resolvedSubject {
    if (subject == null) return null;
    if (subject == IntakeCatalog.customSubject) {
      final custom = customSubject.trim();
      return custom.isEmpty ? null : custom;
    }
    return subject;
  }

  String? get resolvedBoard {
    final spec = level;
    if (spec == null) return null;
    if (spec.customBoard) {
      final custom = customBoard?.trim();
      return (custom == null || custom.isEmpty) ? null : custom;
    }
    return board;
  }

  LearningGoalSpec? get goal {
    if (goalId == null || level == null) return null;
    for (final item in level!.goals) {
      if (item.id == goalId) return item;
    }
    return null;
  }

  bool get isLaunchReady =>
      levelId != null &&
      resolvedSubject != null &&
      topic.trim().isNotEmpty;

  String get launchLabel {
    switch (goalId) {
      case 'exam':
        return 'Build exam-ready curriculum';
      case 'advanced':
        return 'Design an advanced curriculum';
      case 'problems':
        return 'Launch a problem-first curriculum';
      case 'scratch':
        return 'Launch from first principles';
      default:
        return 'Launch curriculum';
    }
  }

  List<String> get topicSuggestions {
    final currentLevel = levelId;
    final currentSubject = resolvedSubject;
    if (currentLevel == null || currentSubject == null) return const [];
    return IntakeCatalog.topicsFor(
      levelId: currentLevel,
      subject: subject == IntakeCatalog.customSubject
          ? currentSubject
          : subject!,
    );
  }

  void selectLevel(EducationLevelSpec next) {
    final previousSubject = subject;
    levelId = next.id;

    if (!next.showExamBoard) {
      board = null;
    } else if (board != null && !next.boards.contains(board)) {
      board = null;
    }
    if (!next.customBoard) {
      customBoard = null;
    }

    if (depth == null || !next.depths.contains(depth)) {
      depth = next.recommendedDepth;
    }

    if (previousSubject != null &&
        previousSubject != IntakeCatalog.customSubject &&
        !next.subjects.contains(previousSubject)) {
      subject = null;
      topic = '';
    }

    if (goalId != null && !next.goals.any((goal) => goal.id == goalId)) {
      goalId = next.goals.first.id;
    }

    notifyListeners();
  }

  void selectBoard(String value) {
    board = value;
    notifyListeners();
  }

  void setCustomBoard(String value) {
    customBoard = value;
    notifyListeners();
  }

  void selectSubject(String value) {
    if (subject != value) {
      subject = value;
      if (value != IntakeCatalog.customSubject) {
        customSubject = '';
      }
    } else {
      subject = value;
    }
    notifyListeners();
  }

  void setCustomSubject(String value) {
    customSubject = value;
    notifyListeners();
  }

  void setTopic(String value) {
    topic = value;
    notifyListeners();
  }

  void selectGoal(String id) {
    goalId = id;
    notifyListeners();
  }

  void selectDepth(String value) {
    depth = value;
    notifyListeners();
  }

  void setPriorKnowledge(String value) {
    priorKnowledge = value;
    notifyListeners();
  }

  String toIntakePrompt() {
    final prior = priorKnowledge.trim().isEmpty
        ? 'Not specified'
        : priorKnowledge.trim();
    final boardLine = resolvedBoard ?? 'Not specified';
    final goalLine = goal?.label ?? 'Not specified';
    final depthLine = depth ?? 'Not specified';

    return '''
SYNTRA Intake Brief
Education Level: $levelId
Exam Board: $boardLine
Subject: $resolvedSubject
Topic: ${topic.trim()}
Learning Goal: $goalLine
Prior Knowledge: $prior
Required Depth: $depthLine

Use these fields exactly. Do not infer a different level, board, subject, topic, goal, or depth.
''';
  }
}
