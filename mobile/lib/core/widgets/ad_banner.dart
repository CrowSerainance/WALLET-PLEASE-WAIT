import 'package:material_ui/material_ui.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// Banner ad wrapper. When ads are disabled, renders a slim placeholder strip.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!AppConfig.enableAds) return;
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AppConfig.bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner failed: $error');
        },
      ),
      request: const AdRequest(),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.enableAds) {
      return Container(
        height: 36,
        alignment: Alignment.center,
        color: AppColors.mintSoft,
        child: const Text(
          'Ads off (ENABLE_ADS=false)',
          style: TextStyle(fontSize: 12, color: AppColors.slateMuted),
        ),
      );
    }
    if (!_loaded || _ad == null) {
      return const SizedBox(height: 50);
    }
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}

/// Loads an interstitial after a successful vote when ads are enabled.
class InterstitialAdHelper {
  InterstitialAd? _ad;

  Future<void> preload() async {
    if (!AppConfig.enableAds) return;
    await InterstitialAd.load(
      adUnitId: AppConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed: $error');
          _ad = null;
        },
      ),
    );
  }

  Future<void> showIfReady() async {
    final ad = _ad;
    if (ad == null) return;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _ad = null;
      },
    );
    await ad.show();
  }

  void dispose() {
    _ad?.dispose();
  }
}
