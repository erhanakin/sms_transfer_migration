import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import '../widgets/error_dialog.dart';

class PermissionManager {
  static Future<bool> requestSMSPermissions() async {
    final permissions = [
      Permission.sms,
      Permission.phone,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every((status) => status == PermissionStatus.granted);
  }

  static Future<bool> requestStoragePermissions() async {
    final permissions = [
      Permission.storage,
      Permission.manageExternalStorage,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // For Android 11+, MANAGE_EXTERNAL_STORAGE might be needed
    bool hasBasicStorage = statuses[Permission.storage] == PermissionStatus.granted;
    bool hasManageStorage = statuses[Permission.manageExternalStorage] == PermissionStatus.granted;

    return hasBasicStorage || hasManageStorage;
  }

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  static Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status == PermissionStatus.granted;
  }

  static Future<bool> requestAllPermissions() async {
    final permissions = [
      Permission.sms,
      Permission.phone,
      Permission.storage,
      Permission.camera,
      Permission.locationWhenInUse,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // Check critical permissions
    bool hasSMS = statuses[Permission.sms] == PermissionStatus.granted;
    bool hasPhone = statuses[Permission.phone] == PermissionStatus.granted;
    bool hasStorage = statuses[Permission.storage] == PermissionStatus.granted;
    bool hasCamera = statuses[Permission.camera] == PermissionStatus.granted;

    return hasSMS && hasPhone && hasStorage && hasCamera;
  }

  static Future<bool> checkSMSPermissions() async {
    final smsStatus = await Permission.sms.status;
    final phoneStatus = await Permission.phone.status;

    return smsStatus == PermissionStatus.granted &&
        phoneStatus == PermissionStatus.granted;
  }

  static Future<bool> checkStoragePermissions() async {
    final storageStatus = await Permission.storage.status;
    final manageStorageStatus = await Permission.manageExternalStorage.status;

    return storageStatus == PermissionStatus.granted ||
        manageStorageStatus == PermissionStatus.granted;
  }

  static Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    return status == PermissionStatus.granted;
  }

  static Future<void> showPermissionDialog(
      BuildContext context,
      String title,
      String message,
      ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ErrorDialog(
          title: title,
          message: message,
          showRetry: true,
          onRetry: () {
            Navigator.of(context).pop();
            openAppSettings();
          },
        );
      },
    );
  }

  static Future<void> showSMSPermissionDialog(BuildContext context) async {
    await showPermissionDialog(
      context,
      'SMS Permission Required',
      'This app needs SMS permission to read and transfer your messages. Please grant SMS permission in the app settings.',
    );
  }

  static Future<void> showStoragePermissionDialog(BuildContext context) async {
    await showPermissionDialog(
      context,
      'Storage Permission Required',
      'This app needs storage permission to export SMS messages to files. Please grant storage permission in the app settings.',
    );
  }

  static Future<void> showCameraPermissionDialog(BuildContext context) async {
    await showPermissionDialog(
      context,
      'Camera Permission Required',
      'This app needs camera permission to scan QR codes for device pairing. Please grant camera permission in the app settings.',
    );
  }

  static Future<bool> handlePermissionDenied(
      BuildContext context,
      Permission permission,
      ) async {
    String title = 'Permission Required';
    String message = 'This permission is required for the app to function properly.';

    switch (permission) {
      case Permission.sms:
        title = 'SMS Permission Required';
        message = 'SMS permission is required to read and transfer messages.';
        break;
      case Permission.storage:
        title = 'Storage Permission Required';
        message = 'Storage permission is required to export messages to files.';
        break;
      case Permission.camera:
        title = 'Camera Permission Required';
        message = 'Camera permission is required to scan QR codes.';
        break;
      default:
        break;
    }

    await showPermissionDialog(context, title, message);
    return false;
  }

  static Future<bool> ensurePermissionsForFeature(
      BuildContext context,
      String feature,
      ) async {
    switch (feature.toLowerCase()) {
      case 'sms':
        if (!await checkSMSPermissions()) {
          final granted = await requestSMSPermissions();
          if (!granted) {
            await showSMSPermissionDialog(context);
            return false;
          }
        }
        return true;

      case 'export':
        if (!await checkStoragePermissions()) {
          final granted = await requestStoragePermissions();
          if (!granted) {
            await showStoragePermissionDialog(context);
            return false;
          }
        }
        return true;

      case 'qr':
        if (!await checkCameraPermission()) {
          final granted = await requestCameraPermission();
          if (!granted) {
            await showCameraPermissionDialog(context);
            return false;
          }
        }
        return true;

      case 'transfer':
      // Transfer needs SMS + Camera permissions
        bool hasSMS = await checkSMSPermissions();
        bool hasCamera = await checkCameraPermission();

        if (!hasSMS) {
          final granted = await requestSMSPermissions();
          if (!granted) {
            await showSMSPermissionDialog(context);
            return false;
          }
        }

        if (!hasCamera) {
          final granted = await requestCameraPermission();
          if (!granted) {
            await showCameraPermissionDialog(context);
            return false;
          }
        }

        return true;

      default:
        return await requestAllPermissions();
    }
  }
}