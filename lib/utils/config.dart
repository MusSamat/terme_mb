/// Build-time configuration. Pass via `--dart-define`:
///   flutter run --dart-define=API_URL=https://api.terme.kg/v1 \
///               --dart-define=WS_URL=wss://api.terme.kg
class AppConfig {
  // Real production backend (path is /v1, not /api/v1). Overridable via
  // --dart-define=API_URL=... for local/staging.
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.terme.kg/v1',
  );

  static const wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://api.terme.kg',
  );

  /// Public web site — share links («Поделиться»).
  static const webUrl = String.fromEnvironment('WEB_URL', defaultValue: 'https://terme.kg');

  /// Telegram bot username (search, publish, bookings in Telegram).
  static const telegramBot = String.fromEnvironment('TELEGRAM_BOT', defaultValue: 'terme_kg_bot');

  static const requestTimeout = Duration(seconds: 15);
}

/// Hive box + key names, and non-secret client flags.
class StorageKeys {
  static const box = 'terme';

  static const sessionHint = 'terme_session'; // "1" when a session may exist
  static const cachedUser = 'terme_user'; // last SelfUser JSON — for optimistic hydrate
  static const activeMode = 'terme_mode'; // passenger | driver
  static const theme = 'terme_theme'; // light | dark | system
  static const locale = 'terme_locale'; // ru | kg
  static const deferredAction = 'terme_deferred_action';
  static const recentRoutes = 'terme_recent_routes_v2'; // JSON [{from: Place, to: Place}], max 3
}
