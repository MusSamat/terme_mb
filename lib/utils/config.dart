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

  /// Active auth providers (mirror of web AUTH_TELEGRAM_ONLY flag).
  /// MVP: phone OTP (via Telegram DM) + Telegram bot deep-link.
  /// google/apple/phone_password are implemented but hidden until enabled.
  static const authProviders = <String>{'phone_otp', 'telegram_bot'};

  static const requestTimeout = Duration(seconds: 15);

  /// While true, data providers serve the bundled mock data. Defaults to false
  /// so the app talks to the real backend at API_URL; pass
  /// --dart-define=USE_MOCK=true to demo without a backend.
  static const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);
}

/// Hive box + key names, and non-secret client flags.
class StorageKeys {
  static const box = 'terme';

  static const sessionHint = 'terme_session'; // "1" when a session may exist
  static const activeMode = 'terme_mode'; // passenger | driver
  static const theme = 'terme_theme'; // light | dark | system
  static const locale = 'terme_locale'; // ru | kg
  static const onboardingSeen = 'terme_onboarding_seen';
  static const deferredAction = 'terme_deferred_action';
  static const notifPrefsPrefix = 'terme_notif_prefs_'; // + userId
  static const celebratedPrefix = 'terme_celebrated_'; // + bookingId
  static const draftCreate = 'terme_draft_create';
  static const recentRoutes = 'terme_recent_routes'; // List<String> "from|to", max 3
  static const anonId = 'terme_anon_id';
}
