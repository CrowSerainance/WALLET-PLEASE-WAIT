import 'package:flutter/foundation.dart';

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

// Evaluated by the Dart compiler when constructing the release entry point.
class ReleaseConfiguration {
  const ReleaseConfiguration()
      : assert(!kReleaseMode || !AppConfig.useMockData,
            'Release builds require USE_MOCK_DATA=false'),
        assert(
            !kReleaseMode ||
                (AppConfig.supabaseAnonKey != '' &&
                    AppConfig.supabaseAnonKey != 'local-anon-key'),
            'Set SUPABASE_ANON_KEY for release'),
        assert(
            !kReleaseMode ||
                (AppConfig.supabaseUrl != '' &&
                    AppConfig.supabaseUrl != 'http://127.0.0.1:54321'),
            'Set SUPABASE_URL for release');

  void validate() {
    if (!kReleaseMode) return;
    final url = Uri.tryParse(AppConfig.supabaseUrl);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.host == 'localhost' ||
        url.host.startsWith('127.') ||
        url.host == '::1') {
      throw StateError('Release builds require an HTTPS Supabase endpoint');
    }
  }
}
