import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/constants.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialAdReady = false;
  bool _isRewardedAdReady = false;

  static void initialize() {
    if (kDebugMode) {
      print('AdMob Service initialized');
    }
  }

  /// Get Banner Ad Unit ID based on platform
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return AdMobIds.bannerAdUnitId;
    } else if (Platform.isIOS) {
      return AdMobIds.bannerAdUnitId; // Use same for now, update if needed
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Get Interstitial Ad Unit ID based on platform
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return AdMobIds.interstitialAdUnitId;
    } else if (Platform.isIOS) {
      return AdMobIds.interstitialAdUnitId; // Use same for now, update if needed
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Get Rewarded Ad Unit ID based on platform
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return AdMobIds.rewardedAdUnitId;
    } else if (Platform.isIOS) {
      return AdMobIds.rewardedAdUnitId; // Use same for now, update if needed
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Create and load interstitial ad
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          if (kDebugMode) {
            print('Interstitial ad loaded');
          }
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _setInterstitialAdCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (kDebugMode) {
            print('Interstitial ad failed to load: $error');
          }
          _interstitialAd = null;
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  /// Show interstitial ad
  void showInterstitialAd({VoidCallback? onAdClosed}) {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          if (kDebugMode) {
            print('Interstitial ad dismissed');
          }
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdReady = false;
          onAdClosed?.call();
          // Load next ad
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          if (kDebugMode) {
            print('Interstitial ad failed to show: $error');
          }
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdReady = false;
          onAdClosed?.call();
          loadInterstitialAd();
        },
      );

      _interstitialAd!.show();
    } else {
      if (kDebugMode) {
        print('Interstitial ad not ready');
      }
      onAdClosed?.call();
      // Try to load an ad for next time
      loadInterstitialAd();
    }
  }

  /// Set interstitial ad callbacks
  void _setInterstitialAdCallbacks() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        if (kDebugMode) {
          print('Interstitial ad showed full screen');
        }
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        if (kDebugMode) {
          print('Interstitial ad dismissed full screen');
        }
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdReady = false;
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        if (kDebugMode) {
          print('Interstitial ad failed to show full screen: $error');
        }
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdReady = false;
        loadInterstitialAd();
      },
    );
  }

  /// Load rewarded ad
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          if (kDebugMode) {
            print('Rewarded ad loaded');
          }
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          _setRewardedAdCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (kDebugMode) {
            print('Rewarded ad failed to load: $error');
          }
          _rewardedAd = null;
          _isRewardedAdReady = false;
        },
      ),
    );
  }

  /// Show rewarded ad - Fixed callback type
  void showRewardedAd({
    required OnUserEarnedRewardCallback onUserEarnedReward,
    VoidCallback? onAdClosed,
  }) {
    if (_isRewardedAdReady && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          if (kDebugMode) {
            print('Rewarded ad dismissed');
          }
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdReady = false;
          onAdClosed?.call();
          loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          if (kDebugMode) {
            print('Rewarded ad failed to show: $error');
          }
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdReady = false;
          onAdClosed?.call();
          loadRewardedAd();
        },
      );

      _rewardedAd!.show(onUserEarnedReward: onUserEarnedReward);
    } else {
      if (kDebugMode) {
        print('Rewarded ad not ready');
      }
      onAdClosed?.call();
      loadRewardedAd();
    }
  }

  /// Set rewarded ad callbacks
  void _setRewardedAdCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        if (kDebugMode) {
          print('Rewarded ad showed full screen');
        }
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        if (kDebugMode) {
          print('Rewarded ad dismissed full screen');
        }
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        if (kDebugMode) {
          print('Rewarded ad failed to show full screen: $error');
        }
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        loadRewardedAd();
      },
    );
  }

  /// Create banner ad
  BannerAd createBannerAd({
    AdSize adSize = AdSize.banner,
    void Function(Ad, LoadAdError)? onAdFailedToLoad,
    void Function(Ad)? onAdLoaded,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (kDebugMode) {
            print('Banner ad loaded');
          }
          onAdLoaded?.call(ad);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          if (kDebugMode) {
            print('Banner ad failed to load: $error');
          }
          onAdFailedToLoad?.call(ad, error);
        },
        onAdOpened: (Ad ad) {
          if (kDebugMode) {
            print('Banner ad opened');
          }
        },
        onAdClosed: (Ad ad) {
          if (kDebugMode) {
            print('Banner ad closed');
          }
        },
        onAdImpression: (Ad ad) {
          if (kDebugMode) {
            print('Banner ad impression');
          }
        },
      ),
    );
  }

  /// Preload ads for better user experience
  void preloadAds() {
    loadInterstitialAd();
    loadRewardedAd();
  }

  /// Show ad after certain actions (like export completion)
  void showAdAfterAction({
    String action = 'general',
    VoidCallback? onAdClosed,
  }) {
    // Show interstitial ad after major actions
    switch (action) {
      case 'export':
      case 'transfer_complete':
        showInterstitialAd(onAdClosed: onAdClosed);
        break;
      default:
        onAdClosed?.call();
        break;
    }
  }

  /// Check if ads are ready
  bool get isInterstitialAdReady => _isInterstitialAdReady;
  bool get isRewardedAdReady => _isRewardedAdReady;

  /// Dispose all ads
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
    _isInterstitialAdReady = false;
    _isRewardedAdReady = false;
  }
}