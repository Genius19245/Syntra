import 'package:uuid/uuid.dart';

import '../models/learner_brief.dart';
import '../models/research_origin.dart';

/// Device-local snapshot of a produced lesson. Never written to Firestore.
class LessonRecord {
  const LessonRecord({
    required this.id,
    required this.topic,
    required this.markdown,
    required this.savedAt,
    required this.brief,
    this.level,
    this.board,
    this.subject,
    this.originBadge,
    this.origin,
    this.quizPayload,
    this.teacherPayload,
  });

  final String id;
  final String topic;
  final String? level;
  final String? board;
  final String? subject;
  final String markdown;
  final DateTime savedAt;
  final String? originBadge;
  final Map<String, dynamic> brief;
  final Map<String, dynamic>? origin;
  final Map<String, dynamic>? quizPayload;
  final Map<String, dynamic>? teacherPayload;

  ResearchOrigin? get researchOrigin {
    final data = origin;
    if (data == null || data.isEmpty) return null;
    return ResearchOrigin.fromJson(data);
  }

  LearnerBrief toBrief() => LearnerBrief.fromSnapshot(brief);

  String get savedLabel {
    final local = savedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}  '
        '${two(local.hour)}:${two(local.minute)}';
  }

  factory LessonRecord.fromProduction({
    required LearnerBrief brief,
    required String markdown,
    ResearchOrigin? origin,
    Map<String, dynamic>? quizPayload,
    Map<String, dynamic>? teacherPayload,
    String? id,
    DateTime? savedAt,
  }) {
    return LessonRecord(
      id: id ?? const Uuid().v4(),
      topic: brief.topic.trim(),
      level: brief.levelId,
      board: brief.resolvedBoard,
      subject: brief.resolvedSubject,
      markdown: markdown,
      savedAt: savedAt ?? DateTime.now(),
      originBadge: origin?.known == true ? origin!.badge : null,
      brief: brief.toSnapshot(),
      origin: origin?.toJson(),
      quizPayload: quizPayload,
      teacherPayload: teacherPayload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'level': level,
      'board': board,
      'subject': subject,
      'markdown': markdown,
      'savedAt': savedAt.toIso8601String(),
      'originBadge': originBadge,
      'brief': brief,
      if (origin != null) 'origin': origin,
      if (quizPayload != null) 'quizPayload': quizPayload,
      if (teacherPayload != null) 'teacherPayload': teacherPayload,
    };
  }

  factory LessonRecord.fromJson(Map<String, dynamic> json) {
    final briefRaw = json['brief'];
    final brief = briefRaw is Map
        ? Map<String, dynamic>.from(briefRaw)
        : <String, dynamic>{
            'topic': json['topic'],
            'levelId': json['level'],
            'board': json['board'],
            'subject': json['subject'],
          };

    return LessonRecord(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : const Uuid().v4(),
      topic: (json['topic'] as String?)?.trim() ?? '',
      level: json['level'] as String?,
      board: json['board'] as String?,
      subject: json['subject'] as String?,
      markdown: (json['markdown'] as String?) ?? '',
      savedAt: _parseTime(json['savedAt']),
      originBadge: json['originBadge'] as String?,
      brief: brief,
      origin: _asStringMap(json['origin']),
      quizPayload: _asStringMap(json['quizPayload']),
      teacherPayload: _asStringMap(json['teacherPayload']),
    );
  }

  static DateTime _parseTime(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Map<String, dynamic>? _asStringMap(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }
}
