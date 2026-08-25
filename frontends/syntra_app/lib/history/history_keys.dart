import '../auth/auth_service.dart';

/// Prefixes the history store key. Does not own persistence.
///
/// [LessonStore] keeps save/load. This only builds `{uid}/{key}` so
/// signed-in teachers do not share a guest bucket.
abstract final class HistoryKeys {
  static const guestNamespace = AuthService.guestNamespace;
  static const bucket = 'syntra.lesson_history.v1';

  static String namespaceForUid(String? uid) =>
      AuthService.namespaceForUid(uid);

  /// `{guest|uid}/{key}` — used by [LessonStore.storageKey].
  static String prefixed(String key, {String? uid}) {
    return '${namespaceForUid(uid)}/$key';
  }

  static String forService(AuthService auth, [String key = bucket]) {
    return prefixed(key, uid: auth.currentUser?.uid);
  }
}
