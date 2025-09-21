import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';
import '../utils/constants.dart';

class AdMobBannerWidget extends StatefulWidget {
  final AdSize adSize;
  final EdgeInsets? margin;
  final Color? backgroundColor;

  const AdMobBannerWidget({
    super.key,
    this.adSize = AdSize.banner,
    this.margin,
    this.backgroundColor,
  });

  @override
  State<AdMobBannerWidget> createState() => _AdMobBannerWidgetState();
}

class _AdMobBannerWidgetState extends State<AdMobBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  final AdMobService _adMobService = AdMobService();

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = _adMobService.createBannerAd(
      adSize: widget.adSize,
      onAdLoaded: (Ad ad) {
        setState(() {
          _isAdLoaded = true;
        });
      },
      onAdFailedToLoad: (Ad ad, LoadAdError error) {
        setState(() {
          _isAdLoaded = false;
        });
        ad.dispose();
      },
    );

    _bannerAd?.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.all(AppDimensions.paddingSmall),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}

class AdMobLargeBannerWidget extends StatelessWidget {
  final EdgeInsets? margin;

  const AdMobLargeBannerWidget({
    super.key,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return AdMobBannerWidget(
      adSize: AdSize.largeBanner,
      margin: margin,
    );
  }
}

class AdMobMediumRectangleWidget extends StatelessWidget {
  final EdgeInsets? margin;

  const AdMobMediumRectangleWidget({
    super.key,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return AdMobBannerWidget(
      adSize: AdSize.mediumRectangle,
      margin: margin,
    );
  }
}

class AdMobSmartBannerWidget extends StatelessWidget {
  final EdgeInsets? margin;

  const AdMobSmartBannerWidget({
    super.key,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return AdMobBannerWidget(
      adSize: AdSize.fullBanner,
      margin: margin,
    );
  }
}

/// Adaptive banner that adjusts to screen width
class AdMobAdaptiveBannerWidget extends StatefulWidget {
  final EdgeInsets? margin;

  const AdMobAdaptiveBannerWidget({
    super.key,
    this.margin,
  });

  @override
  State<AdMobAdaptiveBannerWidget> createState() => _AdMobAdaptiveBannerWidgetState();
}

class _AdMobAdaptiveBannerWidgetState extends State<AdMobAdaptiveBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  final AdMobService _adMobService = AdMobService();

  @override
  void initState() {
    super.initState();
    _loadAdaptiveBannerAd();
  }

  void _loadAdaptiveBannerAd() async {
    final AnchoredAdaptiveBannerAdSize? size =
    await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) {
      return;
    }

    _bannerAd = _adMobService.createBannerAd(
      adSize: size,
      onAdLoaded: (Ad ad) {
        setState(() {
          _isAdLoaded = true;
        });
      },
      onAdFailedToLoad: (Ad ad, LoadAdError error) {
        setState(() {
          _isAdLoaded = false;
        });
        ad.dispose();
      },
    );

    _bannerAd?.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.all(AppDimensions.paddingSmall),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}