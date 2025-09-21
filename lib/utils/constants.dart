import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'SMS Transfer & Migration';
  static const String version = '1.0.0';

  // Network constants
  static const int transferPort = 8080;
  static const int discoveryPort = 8081;
  static const String transferEndpoint = '/sms-transfer';
  static const String discoveryEndpoint = '/discover';

  // File constants
  static const List<String> supportedExportFormats = ['csv', 'xlsx', 'json', 'txt'];
  static const int maxSMSBatchSize = 1000;
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB

  // UI constants
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration qrScanTimeout = Duration(seconds: 60);

  // Error messages
  static const String permissionDeniedError = 'Required permissions denied';
  static const String networkError = 'Network connection error';
  static const String fileError = 'File operation error';
  static const String smsReadError = 'Failed to read SMS messages';
  static const String transferError = 'SMS transfer failed';
}

class AppColors {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color accentColor = Color(0xFF03DAC6);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFB00020);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color dividerColor = Color(0xFFBDBDBD);
}

class AppDimensions {
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  static const double borderRadius = 8.0;
  static const double cardElevation = 4.0;

  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;

  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;

  static const double qrCodeSize = 250.0;
}

class AdMobIds {
  // Test IDs - Replace with your actual AdMob IDs for production
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

// Production IDs (uncomment and replace when ready)
// static const String bannerAdUnitId = 'ca-app-pub-YOUR-ID/banner';
// static const String interstitialAdUnitId = 'ca-app-pub-YOUR-ID/interstitial';
// static const String rewardedAdUnitId = 'ca-app-pub-YOUR-ID/rewarded';
}

enum TransferMode { sender, receiver }
enum ExportFormat { csv, xlsx, json, txt }
enum ConnectionStatus { disconnected, connecting, connected, error }
enum TransferStatus { idle, preparing, transferring, completed, error }

class MessageTypes {
  static const String discovery = 'DISCOVERY';
  static const String discoveryResponse = 'DISCOVERY_RESPONSE';
  static const String transferRequest = 'TRANSFER_REQUEST';
  static const String transferResponse = 'TRANSFER_RESPONSE';
  static const String smsData = 'SMS_DATA';
  static const String transferComplete = 'TRANSFER_COMPLETE';
  static const String error = 'ERROR';
}

class FileExtensions {
  static const Map<ExportFormat, String> extensions = {
    ExportFormat.csv: '.csv',
    ExportFormat.xlsx: '.xlsx',
    ExportFormat.json: '.json',
    ExportFormat.txt: '.txt',
  };
}