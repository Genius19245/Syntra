import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syntra_app/data/intake_catalog.dart';
import 'package:syntra_app/history/lesson_record.dart';
import 'package:syntra_app/history/lesson_store.dart';
import 'package:syntra_app/models/learner_brief.dart';
import 'package:syntra_app/models/research_origin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final savedAt = DateTime.utc(2026, 8, 22, 17, 30);

  LessonRecord sample({
    String id = 'lesson-1',
    Map<String, dynamic>? quiz,
    Map<String, dynamic>? teacher,
  }) {
    const origin = ResearchOrigin(
      ragUsed: true,
      webUsed: false,
      retrievalMode: 'RAG_ONLY',
    );
    final brief = LearnerBrief()
      ..selectLevel(IntakeCatalog.levelById('GCSE'))
      ..selectBoard('AQA')
      ..selectSubject('Physics')
      ..setTopic('Electricity')
      ..selectGoal('exam')
      ..selectDepth('GCSE');

    return LessonRecord.fromProduction(
      id: id,
      savedAt: savedAt,
      brief: brief,
      markdown: '# Electricity\n\nTeach circuits first.',
      origin: origin,
      quizPayload: quiz,
      teacherPayload: teacher,
    );
  }

  test('serializes and deserializes a produced lesson', () {
    final record = sample(
      quiz: {
        'questions': ['What is current?'],
      },
      teacher: {'notes': 'Warm up with a demo.'},
    );

    final encoded = LessonStore.encodeList([record]);
    final decoded = LessonStore.decodeList(encoded);

    expect(decoded, hasLength(1));
    final restored = decoded.single;
    expect(restored.id, 'lesson-1');
    expect(restored.topic, 'Electricity');
    expect(restored.level, 'GCSE');
    expect(restored.board, 'AQA');
    expect(restored.subject, 'Physics');
    expect(restored.markdown, '# Electricity\n\nTeach circuits first.');
    expect(restored.savedAt.toUtc(), savedAt);
    expect(restored.originBadge, 'Reused from SYNTRA cache');
    expect(restored.researchOrigin?.fromCache, isTrue);
    expect(restored.quizPayload, {'questions': ['What is current?']});
    expect(restored.teacherPayload, {'notes': 'Warm up with a demo.'});

    final brief = restored.toBrief();
    expect(brief.topic, 'Electricity');
    expect(brief.levelId, 'GCSE');
    expect(brief.resolvedBoard, 'AQA');
    expect(brief.resolvedSubject, 'Physics');
    expect(brief.goalId, 'exam');
  });

  test('round-trips a record through toJson/fromJson without optional payloads', () {
    final json = sample().toJson();
    expect(json.containsKey('quizPayload'), isFalse);
    expect(json.containsKey('teacherPayload'), isFalse);

    final restored = LessonRecord.fromJson(json);
    expect(restored.quizPayload, isNull);
    expect(restored.teacherPayload, isNull);
    expect(restored.originBadge, 'Reused from SYNTRA cache');
    expect(restored.brief['topic'], 'Electricity');
  });

  test('decodeList skips malformed rows and empty input', () {
    expect(LessonStore.decodeList(null), isEmpty);
    expect(LessonStore.decodeList(''), isEmpty);
    expect(LessonStore.decodeList('{"not":"a list"}'), isEmpty);

    final mixed = LessonStore.decodeList('''
[
  {"id":"ok","topic":"Magnets","markdown":"# Magnets","savedAt":"2026-08-22T10:00:00Z","brief":{"topic":"Magnets"}},
  "ignore me",
  {"id":"also-ok","topic":"Osmosis","markdown":"# Osmosis","savedAt":"2026-08-21T10:00:00Z","brief":{"topic":"Osmosis"}}
]
''');
    expect(mixed.map((item) => item.topic).toList(), ['Magnets', 'Osmosis']);
  });

  test('store save/load uses local preferences, newest first', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LessonStore(preferences: prefs);

    await store.save(sample(id: 'older', quiz: null));
    await store.save(
      sample(id: 'newer').copyWithTopic('Updated electricity'),
    );

    final loaded = await store.loadAll();
    expect(loaded.map((item) => item.id).toList(), ['newer', 'older']);
    expect(prefs.getString(LessonStore.storageKey()), isNotNull);
    expect(
      prefs.getString(LessonStore.storageKey()),
      contains('Updated electricity'),
    );
    expect(prefs.getString(LessonStore.prefsKey), isNull);
  });

  test('ensureSample writes a pack once and leaves it in place', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LessonStore(preferences: prefs);
    const id = 'syntra.sample.coastal-landscapes';

    await store.ensureSample(sample(id: id));
    await store.ensureSample(sample(id: id).copyWithTopic('Should not replace'));

    final loaded = await store.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, id);
    expect(loaded.single.topic, 'Electricity');
  });

  test('namespaces keep teacher history apart on device', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LessonStore(preferences: prefs);

    await store.save(sample(id: 'guest-lesson'), namespace: 'guest');
    await store.save(sample(id: 'teacher-lesson'), namespace: 'uid-42');

    expect(
      (await store.loadAll(namespace: 'guest')).map((item) => item.id),
      ['guest-lesson'],
    );
    expect(
      (await store.loadAll(namespace: 'uid-42')).map((item) => item.id),
      ['teacher-lesson'],
    );
  });
}

extension on LessonRecord {
  LessonRecord copyWithTopic(String topic) {
    return LessonRecord(
      id: id,
      topic: topic,
      level: level,
      board: board,
      subject: subject,
      markdown: markdown,
      savedAt: savedAt,
      originBadge: originBadge,
      brief: {...brief, 'topic': topic},
      origin: origin,
      quizPayload: quizPayload,
      teacherPayload: teacherPayload,
    );
  }
}
