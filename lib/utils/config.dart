/// Build-time configuration. Pass via `--dart-define`:
///   flutter run --dart-define=API_URL=https://api.tappjet.kg/api/v1 \
///               --dart-define=WS_URL=wss://api.tappjet.kg
class AppConfig {
  // Real production backend (path is /v1, not /api/v1). Overridable via
  // --dart-define=API_URL=... for local/staging.
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.tappjet.kg/v1',
  );

  static const wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://api.tappjet.kg',
  );

  /// Active auth providers (mirror of web AUTH_TELEGRAM_ONLY flag).
  /// MVP: phone OTP (via Telegram DM) + Telegram bot deep-link.
  /// google/apple/phone_password are implemented but hidden until enabled.
  static const authProviders = <String>{'phone_otp', 'telegram_bot'};

  static const requestTimeout = Duration(seconds: 15);

  /// While true, data providers serve the bundled mock data. Flip to false
  /// (or pass --dart-define=USE_MOCK=false) to hit the real backend at API_URL.
  static const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);
}

/// Hive box + key names, and non-secret client flags.
class StorageKeys {
  static const box = 'tappjet';

  static const sessionHint = 'tappjet_session'; // "1" when a session may exist
  static const activeMode = 'tappjet_mode'; // passenger | driver
  static const theme = 'tappjet_theme'; // light | dark | system
  static const locale = 'tappjet_locale'; // ru | kg
  static const onboardingSeen = 'tappjet_onboarding_seen';
  static const deferredAction = 'tappjet_deferred_action';
  static const notifPrefsPrefix = 'tappjet_notif_prefs_'; // + userId
  static const celebratedPrefix = 'tappjet_celebrated_'; // + bookingId
  static const draftCreate = 'tappjet_draft_create';
  static const anonId = 'tappjet_anon_id';
}
