/// Runtime configuration via `--dart-define`.
/// Example:
/// flutter run \
///   --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
///   --dart-define=SUPABASE_ANON_KEY=your-local-anon-key \
///   --dart-define=ENABLE_ADS=false \
///   --dart-define=USE_MOCK_DATA=true
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'local-anon-key',
  );

  static const enableAds = bool.fromEnvironment(
    'ENABLE_ADS',
    defaultValue: false,
  );

  /// When true, repositories serve in-memory seed data (no live Supabase).
  static const useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: true,
  );

  /// Google AdMob test unit IDs — replace before production.
  static const bannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );

  static const interstitialAdUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  static const deepLinkScheme = 'walletwait';
  static const httpsFallbackHost = 'holdmywallet.app';
}
