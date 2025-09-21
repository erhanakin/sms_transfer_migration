import 'dart:convert';
import 'dart:typed_data';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import '../models/transfer_session.dart';
import '../utils/constants.dart';

class QRService {
  static final QRService _instance = QRService._internal();
  factory QRService() => _instance;
  QRService._internal();

  /// Generate QR code data for device pairing
  String generatePairingQR({
    required DeviceInfo deviceInfo,
    required String sessionId,
  }) {
    final qrData = {
      'type': 'sms_transfer_pairing',
      'version': AppConstants.version,
      'session_id': sessionId,
      'device_info': deviceInfo.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    return jsonEncode(qrData);
  }

  /// Parse QR code data
  QRPairingData? parsePairingQR(String qrData) {
    try {
      final data = jsonDecode(qrData);

      // Validate QR code type
      if (data['type'] != 'sms_transfer_pairing') {
        return null;
      }

      // Check version compatibility
      final version = data['version'] ?? '';
      if (!_isVersionCompatible(version)) {
        return null;
      }

      return QRPairingData.fromJson(data);
    } catch (e) {
      print('Failed to parse QR data: $e');
      return null;
    }
  }

  /// Check if version is compatible
  bool _isVersionCompatible(String version) {
    // For now, accept all versions
    // In the future, you can implement version checking logic
    return true;
  }

  /// Create QR code widget
  Widget createQRWidget({
    required String data,
    double size = AppDimensions.qrCodeSize,
    Color? foregroundColor,
    Color? backgroundColor,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        foregroundColor: foregroundColor ?? Colors.black,
        backgroundColor: backgroundColor ?? Colors.white,
        errorStateBuilder: (cxt, err) {
          return Container(
            width: size,
            height: size,
            color: AppColors.errorColor.withOpacity(0.1),
            child: const Center(
              child: Icon(
                Icons.error,
                color: AppColors.errorColor,
                size: AppDimensions.iconSizeLarge,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Create QR code with device info display
  Widget createPairingQRWidget({
    required DeviceInfo deviceInfo,
    required String sessionId,
    double size = AppDimensions.qrCodeSize,
  }) {
    final qrData = generatePairingQR(
      deviceInfo: deviceInfo,
      sessionId: sessionId,
    );

    return Card(
      elevation: AppDimensions.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan to Connect',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            createQRWidget(data: qrData, size: size),
            const SizedBox(height: AppDimensions.paddingMedium),
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.phone_android,
                    label: 'Device',
                    value: deviceInfo.deviceName,
                  ),
                  const SizedBox(height: AppDimensions.paddingSmall),
                  _buildInfoRow(
                    icon: Icons.wifi,
                    label: 'IP Address',
                    value: deviceInfo.ipAddress,
                  ),
                  const SizedBox(height: AppDimensions.paddingSmall),
                  _buildInfoRow(
                    icon: Icons.security,
                    label: 'Session ID',
                    value: sessionId.substring(0, 8) + '...',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: AppDimensions.iconSizeSmall,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppDimensions.paddingSmall),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppDimensions.paddingSmall),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Generate QR code as image bytes
  Future<Uint8List?> generateQRImageBytes({
    required String data,
    double size = 200,
    Color? foregroundColor,
    Color? backgroundColor,
  }) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        return null;
      }

      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: foregroundColor ?? Colors.black,
        emptyColor: backgroundColor ?? Colors.white,
      );

      final picData = await painter.toImageData(size);
      return picData?.buffer.asUint8List();
    } catch (e) {
      print('Failed to generate QR image: $e');
      return null;
    }
  }

  /// Validate QR data format
  bool isValidPairingQR(String qrData) {
    try {
      final data = jsonDecode(qrData);

      // Check required fields
      return data['type'] == 'sms_transfer_pairing' &&
          data['session_id'] != null &&
          data['device_info'] != null &&
          data['device_info']['device_name'] != null &&
          data['device_info']['ip_address'] != null;
    } catch (e) {
      return false;
    }
  }

  /// Create QR scanner result validator
  bool Function(String) createQRValidator() {
    return (String data) {
      return isValidPairingQR(data);
    };
  }
}

/// QR pairing data model
class QRPairingData {
  final String type;
  final String version;
  final String sessionId;
  final DeviceInfo deviceInfo;
  final DateTime timestamp;

  QRPairingData({
    required this.type,
    required this.version,
    required this.sessionId,
    required this.deviceInfo,
    required this.timestamp,
  });

  factory QRPairingData.fromJson(Map<String, dynamic> json) {
    return QRPairingData(
      type: json['type'] ?? '',
      version: json['version'] ?? '',
      sessionId: json['session_id'] ?? '',
      deviceInfo: DeviceInfo.fromJson(json['device_info'] ?? {}),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'version': version,
      'session_id': sessionId,
      'device_info': deviceInfo.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get isValid {
    return type == 'sms_transfer_pairing' &&
        sessionId.isNotEmpty &&
        deviceInfo.deviceName.isNotEmpty &&
        deviceInfo.ipAddress.isNotEmpty;
  }

  Duration get age {
    return DateTime.now().difference(timestamp);
  }

  bool get isExpired {
    // QR codes expire after 1 hour
    return age.inHours > 1;
  }

  @override
  String toString() {
    return 'QRPairingData{device: ${deviceInfo.deviceName}, session: ${sessionId.substring(0, 8)}...}';
  }
}