import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syntra_app/auth/fake_auth_service.dart';
import 'package:syntra_app/data/intake_catalog.dart';
import 'package:syntra_app/history/history_keys.dart';
import 'package:syntra_app/history/lesson_record.dart';
import 'package:syntra_app/history/lesson_store.dart';
import 'package:syntra_app/models/learner_brief.dart';

void main() {
  test('prefixes guest and uid without rewriting the store bucket name', () {
    expect(
      HistoryKeys.prefixed(HistoryKeys.bucket),
      'guest/syntra.lesson_history.v1',
    );
    expect(
      HistoryKeys.prefixed(HistoryKeys.bucket, uid: '  '),
      'guest/syntra.lesson_history.v1',
    );
    expect(
      HistoryKeys.prefixed(HistoryKeys.bucket, uid: 'teacher-1'),
      'teacher-1/syntra.lesson_history.v1',
    );
    expect(
      LessonStore.storageKey('teacher-1'),
      HistoryKeys.prefixed(LessonStore.prefsKey, uid: 'teacher-1'),
    );
  });

  test('LessonStore keeps guest and signed-in buckets apart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LessonStore(preferences: prefs);
    final auth = FakeAuthService();

    final guest = _record('guest-id', 'Magnets');
    final signedIn = _record('uid-id', 'Osmosis');

    await store.save(guest, namespace: auth.historyNamespace);
    await auth.signInWithGoogle();
    await store.save(signedIn, namespace: auth.historyNamespace);

    expect(
      (await store.loadAll(namespace: 'guest')).map((item) => item.id),
      ['guest-id'],
    );
    expect(
      (await store.loadAll(namespace: 'google-test-uid')).map((item) => item.id),
      ['uid-id'],
    );
    expect(
      prefs.getString(HistoryKeys.forService(FakeAuthService())),
      contains('Magnets'),
    );
    expect(
      prefs.getString(HistoryKeys.forService(auth)),
      contains('Osmosis'),
    );
  });
}

LessonRecord _record(String id, String topic) {
  final brief = LearnerBrief()
    ..selectLevel(IntakeCatalog.levelById('GCSE'))
    ..selectBoard('AQA')
    ..selectSubject('Physics')
    ..setTopic(topic);

  return LessonRecord.fromProduction(
    id: id,
    brief: brief,
    markdown: '# $topic',
    savedAt: DateTime.utc(2026, 8, 22),
  );
}
