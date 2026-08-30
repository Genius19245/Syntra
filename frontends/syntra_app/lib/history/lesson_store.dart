import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_service.dart';
import '../models/learner_brief.dart';
import '../models/research_origin.dart';
import 'history_keys.dart';
import 'lesson_record.dart';

/// Per-teacher lesson history on this device.
///
/// Uses [SharedPreferences] only. Do not write `syntra/workspace/research_cache`
/// — that collection stays Admin SDK / Research Agent.
class LessonStore extends ChangeNotifier {
  LessonStore({SharedPreferences? preferences}) : _preferences = preferences;

  static const prefsKey = 'syntra.lesson_history.v1';
  static const maxEntries = 50;

  static LessonStore instance = LessonStore();

  SharedPreferences? _preferences;

  static String storageKey([String namespace = AuthService.guestNamespace]) {
    return HistoryKeys.prefixed(prefsKey, uid: namespace);
  }

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  static String encodeList(List<LessonRecord> records) {
    return jsonEncode([for (final record in records) record.toJson()]);
  }

  static List<LessonRecord> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final records = <LessonRecord>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          records.add(LessonRecord.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          continue;
        }
      }
      return records;
    } catch (_) {
      return const [];
    }
  }

  Future<List<LessonRecord>> loadAll({
    String namespace = AuthService.guestNamespace,
  }) async {
    final prefs = await _prefs();
    final namespaced = decodeList(prefs.getString(storageKey(namespace)));
    if (namespaced.isNotEmpty) return namespaced;
    if (namespace == AuthService.guestNamespace) {
      return decodeList(prefs.getString(prefsKey));
    }
    return namespaced;
  }

  Future<void> save(
    LessonRecord record, {
    String namespace = AuthService.guestNamespace,
  }) async {
    final existing = await loadAll(namespace: namespace);
    final next = [
      record,
      ...existing.where((item) => item.id != record.id),
    ].take(maxEntries).toList();
    final prefs = await _prefs();
    await prefs.setString(storageKey(namespace), encodeList(next));
    notifyListeners();
  }

  Future<void> ensureSample(
    LessonRecord sample, {
    String namespace = AuthService.guestNamespace,
  }) async {
    try {
      final existing = await loadAll(namespace: namespace);
      if (existing.any((item) => item.id == sample.id)) return;
      await save(sample, namespace: namespace);
    } catch (_) {}
  }

  /// Local write of an already-produced curriculum. Does not re-run the pipeline.
  Future<LessonRecord> saveProducedLesson({
    required LearnerBrief brief,
    required String markdown,
    ResearchOrigin? origin,
    Map<String, dynamic>? quizPayload,
    Map<String, dynamic>? teacherPayload,
    String namespace = AuthService.guestNamespace,
  }) async {
    final record = LessonRecord.fromProduction(
      brief: brief,
      markdown: markdown,
      origin: origin,
      quizPayload: quizPayload,
      teacherPayload: teacherPayload,
    );
    await save(record, namespace: namespace);
    return record;
  }
}
