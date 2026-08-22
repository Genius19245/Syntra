/// SYNTRA teaching engine on Cloud Run.
///
/// `flutter run` uses this URL with no extra flags.
///
/// Local ADK instead:
///   flutter run --dart-define=ADK_BASE_URL=http://127.0.0.1:8000
///   ./scripts/dev.sh
abstract final class AdkConfig {
  static const cloudRunUrl =
      'https://syntra-orchestrator-459448503831.us-central1.run.app';

  static const baseUrl = String.fromEnvironment(
    'ADK_BASE_URL',
    defaultValue: cloudRunUrl,
  );

  static const appName = String.fromEnvironment(
    'ADK_APP_NAME',
    defaultValue: 'syntra_orchestrator',
  );

  static Uri get uri {
    final raw = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse(raw);
  }
}
