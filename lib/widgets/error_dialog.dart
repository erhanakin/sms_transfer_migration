import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? details;
  final bool showRetry;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final IconData? icon;
  final Color? iconColor;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.details,
    this.showRetry = false,
    this.onRetry,
    this.onDismiss,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      ),
      title: Row(
        children: [
          Icon(
            icon ?? Icons.error,
            color: iconColor ?? AppColors.errorColor,
            size: AppDimensions.iconSizeLarge,
          ),
          const SizedBox(width: AppDimensions.paddingMedium),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (details != null) ...[
            const SizedBox(height: AppDimensions.paddingMedium),
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                border: Border.all(
                  color: AppColors.dividerColor,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error Details:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingSmall),
                  Text(
                    details!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          child: Text(
            'Dismiss',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (showRetry)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
      ],
    );
  }
}

class SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onOk;
  final String? actionText;
  final VoidCallback? onAction;

  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    this.onOk,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      ),
      title: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppColors.successColor,
            size: AppDimensions.iconSizeLarge,
          ),
          const SizedBox(width: AppDimensions.paddingMedium),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        if (actionText != null && onAction != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction!();
            },
            child: Text(actionText!),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onOk?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.successColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class WarningDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDangerous;

  const WarningDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning,
            color: isDangerous ? AppColors.errorColor : AppColors.warningColor,
            size: AppDimensions.iconSizeLarge,
          ),
          const SizedBox(width: AppDimensions.paddingMedium),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancel?.call();
          },
          child: Text(
            cancelText,
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDangerous ? AppColors.errorColor : AppColors.warningColor,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

class LoadingDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool showProgress;
  final double? progress;
  final String? progressText;

  const LoadingDialog({
    super.key,
    required this.title,
    required this.message,
    this.showProgress = false,
    this.progress,
    this.progressText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      ),
      title: Row(
        children: [
          SizedBox(
            width: AppDimensions.iconSizeLarge,
            height: AppDimensions.iconSizeLarge,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingMedium),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: AppDimensions.paddingMedium),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
            if (progressText != null) ...[
              const SizedBox(height: AppDimensions.paddingSmall),
              Text(
                progressText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// Helper methods for showing dialogs
class DialogHelper {
  static Future<void> showError(
      BuildContext context, {
        required String title,
        required String message,
        String? details,
        bool showRetry = false,
        VoidCallback? onRetry,
      }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ErrorDialog(
          title: title,
          message: message,
          details: details,
          showRetry: showRetry,
          onRetry: onRetry,
        );
      },
    );
  }

  static Future<void> showSuccess(
      BuildContext context, {
        required String title,
        required String message,
        VoidCallback? onOk,
        String? actionText,
        VoidCallback? onAction,
      }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return SuccessDialog(
          title: title,
          message: message,
          onOk: onOk,
          actionText: actionText,
          onAction: onAction,
        );
      },
    );
  }

  static Future<bool> showWarning(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'Confirm',
        String cancelText = 'Cancel',
        bool isDangerous = false,
      }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WarningDialog(
          title: title,
          message: message,
          confirmText: confirmText,
          cancelText: cancelText,
          isDangerous: isDangerous,
          onConfirm: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
        );
      },
    );
    return result ?? false;
  }

  static void showLoading(
      BuildContext context, {
        required String title,
        required String message,
        bool showProgress = false,
        double? progress,
        String? progressText,
      }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return LoadingDialog(
          title: title,
          message: message,
          showProgress: showProgress,
          progress: progress,
          progressText: progressText,
        );
      },
    );
  }

  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }

  static Future<void> showPermissionDenied(
      BuildContext context, {
        required String feature,
      }) {
    return showError(
      context,
      title: 'Permission Required',
      message: 'This feature requires additional permissions to work properly. Please grant the necessary permissions in your device settings.',
      details: 'Feature: $feature',
      showRetry: true,
      onRetry: () {
        // This could open app settings
      },
    );
  }

  static Future<void> showNetworkError(
      BuildContext context, {
        String? details,
        VoidCallback? onRetry,
      }) {
    return showError(
      context,
      title: 'Network Error',
      message: 'Unable to connect to the network. Please check your internet connection and try again.',
      details: details,
      showRetry: true,
      onRetry: onRetry,
    );
  }

  static Future<void> showFileError(
      BuildContext context, {
        String? details,
        VoidCallback? onRetry,
      }) {
    return showError(
      context,
      title: 'File Error',
      message: 'There was an error working with the file. Please try again or check your storage permissions.',
      details: details,
      showRetry: true,
      onRetry: onRetry,
    );
  }
}