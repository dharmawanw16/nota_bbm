import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum AdResult { rewarded, dismissed, unavailable }

// ID di bawah adalah ID uji Google. Ganti dengan ID AdMob asli sebelum rilis
// (termasuk APPLICATION_ID di AndroidManifest.xml).
class AdsService {
  static const bannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const rewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!_supported) return;
    await MobileAds.instance.initialize();
  }

  static Future<AdResult> showRewarded() async {
    if (!_supported) return AdResult.unavailable;
    final completer = Completer<AdResult>();
    var earned = false;

    void finish(AdResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    await RewardedAd.load(
      adUnitId: rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              finish(earned ? AdResult.rewarded : AdResult.dismissed);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              finish(AdResult.unavailable);
            },
          );
          ad.show(onUserEarnedReward: (_, _) => earned = true);
        },
        onAdFailedToLoad: (_) => finish(AdResult.unavailable),
      ),
    );
    return completer.future;
  }
}

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    if (!AdsService._supported) return;
    _ad = BannerAd(
      adUnitId: AdsService.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
