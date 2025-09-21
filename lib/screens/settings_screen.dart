import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/export_service.dart';
import '../services/sms_service.dart';
import '../utils/constants.dart';
import '../utils/permissions.dart';
import '../widgets/error_dialog.dart';
import '../widgets/admob_banner.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ExportService _exportService = ExportService();
  final SMSService _smsService = SMSService();

  Map<String, dynamic> _smsStats = {};
  int _exportedFilesCount = 0;
  String _exportDirectorySize = '0 B';
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final futures = await Future.wait([
        _smsService.getSMSStatistics(),
        _exportService.getExportedFiles(),
        _exportService.getExportDirectorySize(),
      ]);

      setState(() {
        _smsStats = futures[0] as Map<String, dynamic>;
        _exportedFilesCount = (futures[1] as List).length;
        _exportDirectorySize = _formatBytes(futures[2] as int);
      });
    } catch (e) {
      print('Failed to load settings: $e');
    } finally {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _clearExportCache() async {
    final confirmed = await DialogHelper.showWarning(
      context,
      title: 'Clear Export Cache',
      message: 'This will delete all exported files. Are you sure you want to continue?',
      confirmText: 'Clear',
      isDangerous: true,
    );

    if (confirmed) {
      try {
        await _exportService.clearAllExportedFiles();
        await _loadSettings();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export cache cleared successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );
      } catch (e) {
        DialogHelper.showError(
          context,
          title: 'Clear Failed',
          message: 'Failed to clear export cache.',
          details: e.toString(),
        );
      }
    }
  }

  Future<void> _refreshSMSData() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final stats = await _smsService.getSMSStatistics();
      setState(() {
        _smsStats = stats;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS data refreshed'),
          backgroundColor: AppColors.successColor,
        ),
      );
    } catch (e) {
      DialogHelper.showError(
        context,
        title: 'Refresh Failed',
        message: 'Failed to refresh SMS data.',
        details: e.toString(),
      );
    } finally {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _checkPermissions() async {
    final permissions = [
      Permission.sms,
      Permission.phone,
      Permission.storage,
      Permission.camera,
    ];

    final statuses = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      statuses[permission] = await permission.status;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.entries.map((entry) {
            return ListTile(
              leading: Icon(
                _getPermissionIcon(entry.key),
                color: _getPermissionColor(entry.value),
              ),
              title: Text(_getPermissionName(entry.key)),
              trailing: Text(
                _getPermissionStatusText(entry.value),
                style: TextStyle(
                  color: _getPermissionColor(entry.value),
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  IconData _getPermissionIcon(Permission permission) {
    switch (permission) {
      case Permission.sms:
        return Icons.sms;
      case Permission.phone:
        return Icons.phone;
      case Permission.storage:
        return Icons.storage;
      case Permission.camera:
        return Icons.camera_alt;
      default:
        return Icons.security;
    }
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.sms:
        return 'SMS';
      case Permission.phone:
        return 'Phone';
      case Permission.storage:
        return 'Storage';
      case Permission.camera:
        return 'Camera';
      default:
        return permission.toString();
    }
  }

  Color _getPermissionColor(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return AppColors.successColor;
      case PermissionStatus.denied:
      case PermissionStatus.permanentlyDenied:
        return AppColors.errorColor;
      case PermissionStatus.restricted:
      case PermissionStatus.limited:
        return AppColors.warningColor;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getPermissionStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App Info Section
                    _buildAppInfoSection(),

                    const SizedBox(height: AppDimensions.paddingLarge),

                    // SMS Statistics Section
                    _buildSMSStatisticsSection(),

                    const SizedBox(height: AppDimensions.paddingLarge),

                    // Export Settings Section
                    _buildExportSettingsSection(),

                    const SizedBox(height: AppDimensions.paddingLarge),

                    // Permissions Section
                    _buildPermissionsSection(),

                    const SizedBox(height: AppDimensions.paddingLarge),

                    // About Section
                    _buildAboutSection(),
                  ],
                ),
              ),
            ),
            const AdMobBannerWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info,
                  color: AppColors.primaryColor,
                  size: AppDimensions.iconSizeLarge,
                ),
                const SizedBox(width: AppDimensions.paddingMedium),
                Text(
                  'App Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildInfoRow('App Name', AppConstants.appName),
            _buildInfoRow('Version', AppConstants.version),
            _buildInfoRow('Transfer Port', AppConstants.transferPort.toString()),
            _buildInfoRow('Max Batch Size', AppConstants.maxSMSBatchSize.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildSMSStatisticsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: AppColors.primaryColor,
                  size: AppDimensions.iconSizeLarge,
                ),
                const SizedBox(width: AppDimensions.paddingMedium),
                Expanded(
                  child: Text(
                    'SMS Statistics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: _isLoadingStats
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.refresh),
                  onPressed: _isLoadingStats ? null : _refreshSMSData,
                  tooltip: 'Refresh Statistics',
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            if (_smsStats.isNotEmpty) ...[
              _buildInfoRow(
                'Total Messages',
                _smsStats['total_messages']?.toString() ?? '0',
              ),
              _buildInfoRow(
                'Sent Messages',
                _smsStats['sent_messages']?.toString() ?? '0',
              ),
              _buildInfoRow(
                'Received Messages',
                _smsStats['received_messages']?.toString() ?? '0',
              ),
              _buildInfoRow(
                'Unique Contacts',
                _smsStats['unique_contacts']?.toString() ?? '0',
              ),
              if (_smsStats['oldest_message'] != null)
                _buildInfoRow(
                  'Oldest Message',
                  DateTime.parse(_smsStats['oldest_message'])
                      .toString()
                      .split(' ')[0],
                ),
              if (_smsStats['newest_message'] != null)
                _buildInfoRow(
                  'Newest Message',
                  DateTime.parse(_smsStats['newest_message'])
                      .toString()
                      .split(' ')[0],
                ),
            ] else
              Text(
                'No SMS statistics available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.file_download,
                  color: AppColors.primaryColor,
                  size: AppDimensions.iconSizeLarge,
                ),
                const SizedBox(width: AppDimensions.paddingMedium),
                Text(
                  'Export Settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildInfoRow('Exported Files', _exportedFilesCount.toString()),
            _buildInfoRow('Cache Size', _exportDirectorySize),
            _buildInfoRow('Supported Formats', AppConstants.supportedExportFormats.join(', ')),
            const SizedBox(height: AppDimensions.paddingMedium),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exportedFilesCount > 0 ? _clearExportCache : null,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clear Export Cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warningColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: AppColors.primaryColor,
                  size: AppDimensions.iconSizeLarge,
                ),
                const SizedBox(width: AppDimensions.paddingMedium),
                Text(
                  'Permissions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            Text(
              'This app requires the following permissions to function properly:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildPermissionItem(
              Icons.sms,
              'SMS Permission',
              'Required to read and write SMS messages',
            ),
            _buildPermissionItem(
              Icons.camera_alt,
              'Camera Permission',
              'Required to scan QR codes for device pairing',
            ),
            _buildPermissionItem(
              Icons.storage,
              'Storage Permission',
              'Required to export SMS messages to files',
            ),
            _buildPermissionItem(
              Icons.phone,
              'Phone Permission',
              'Required to access SMS database',
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checkPermissions,
                icon: const Icon(Icons.check_circle),
                label: const Text('Check Permissions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSmall),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.textSecondary,
            size: AppDimensions.iconSizeMedium,
          ),
          const SizedBox(width: AppDimensions.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help,
                  color: AppColors.primaryColor,
                  size: AppDimensions.iconSizeLarge,
                ),
                const SizedBox(width: AppDimensions.paddingMedium),
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            Text(
              'SMS Transfer & Migration allows you to easily transfer SMS messages between Android devices and export them to various file formats.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            Text(
              'Features:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            _buildFeatureItem('• Transfer SMS via QR code pairing'),
            _buildFeatureItem('• Export to CSV, XLSX, JSON, TXT formats'),
            _buildFeatureItem('• Preserve message history and metadata'),
            _buildFeatureItem('• Local network transfer (no cloud)'),
            _buildFeatureItem('• Merge messages without duplicates'),
            const SizedBox(height: AppDimensions.paddingMedium),
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.privacy_tip,
                    color: AppColors.primaryColor,
                    size: AppDimensions.iconSizeMedium,
                  ),
                  const SizedBox(width: AppDimensions.paddingMedium),
                  Expanded(
                    child: Text(
                      'Your SMS messages never leave your local network. All transfers are done directly between devices.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSmall),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}