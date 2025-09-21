import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sms_service.dart';
import '../services/export_service.dart';
import '../services/admob_service.dart';
import '../models/sms_model.dart';
import '../utils/constants.dart';
import '../widgets/error_dialog.dart';
import '../widgets/progress_indicator_widget.dart';
import '../widgets/admob_banner.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  final SMSService _smsService = SMSService();
  final ExportService _exportService = ExportService();
  final AdMobService _adMobService = AdMobService();

  List<SMSMessage> _smsMessages = [];
  List<FileInfo> _exportedFiles = [];
  bool _isLoading = false;
  bool _isExporting = false;
  ExportFormat _selectedFormat = ExportFormat.csv;
  ExportProgress? _exportProgress;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load SMS messages and exported files
      final futures = await Future.wait([
        _smsService.getAllSMS(),
        _exportService.getExportedFiles(),
      ]);

      setState(() {
        _smsMessages = futures[0] as List<SMSMessage>;
        _exportedFiles = futures[1] as List<FileInfo>;
      });
    } catch (e) {
      if (mounted) {
        DialogHelper.showError(
          context,
          title: 'Loading Error',
          message: 'Failed to load SMS messages.',
          details: e.toString(),
          showRetry: true,
          onRetry: _loadData,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startExport() async {
    if (_smsMessages.isEmpty) {
      DialogHelper.showError(
        context,
        title: 'No Messages',
        message: 'No SMS messages found to export.',
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = null;
    });

    try {
      // Show export options dialog
      final confirmed = await _showExportConfirmationDialog();
      if (!confirmed) {
        setState(() {
          _isExporting = false;
        });
        return;
      }

      // Start export with progress tracking
      await for (final progress in _exportService.exportSMSInBatches(
        messages: _smsMessages,
        format: _selectedFormat,
      )) {
        setState(() {
          _exportProgress = progress;
        });

        if (progress.isCompleted) {
          break;
        }
      }

      // Refresh exported files list
      await _loadExportedFiles();

      // Show success dialog
      DialogHelper.showSuccess(
        context,
        title: 'Export Complete',
        message: 'Successfully exported ${_smsMessages.length} SMS messages to ${_selectedFormat.name.toUpperCase()} format.',
        actionText: 'Share File',
        onAction: () async {
          if (_exportProgress?.filePath != null) {
            await _exportService.shareExportedFile(_exportProgress!.filePath!);
          }
        },
        onOk: () {
          _adMobService.showAdAfterAction(action: 'export');
        },
      );

    } catch (e) {
      DialogHelper.showError(
        context,
        title: 'Export Failed',
        message: 'Failed to export SMS messages.',
        details: e.toString(),
        showRetry: true,
        onRetry: _startExport,
      );
    } finally {
      setState(() {
        _isExporting = false;
        _exportProgress = null;
      });
    }
  }

  Future<bool> _showExportConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export ${_smsMessages.length} Messages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export format: ${_selectedFormat.name.toUpperCase()}'),
            const SizedBox(height: AppDimensions.paddingMedium),
            Text(
              'This will create a new export file with all your SMS messages. The process may take a few minutes for large message collections.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Export'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _loadExportedFiles() async {
    try {
      final files = await _exportService.getExportedFiles();
      setState(() {
        _exportedFiles = files;
      });
    } catch (e) {
      print('Failed to load exported files: $e');
    }
  }

  Future<void> _shareFile(FileInfo fileInfo) async {
    try {
      await _exportService.shareExportedFile(fileInfo.path);
    } catch (e) {
      DialogHelper.showError(
        context,
        title: 'Share Failed',
        message: 'Failed to share the exported file.',
        details: e.toString(),
      );
    }
  }

  Future<void> _deleteFile(FileInfo fileInfo) async {
    final confirmed = await DialogHelper.showWarning(
      context,
      title: 'Delete Export',
      message: 'Are you sure you want to delete "${fileInfo.name}"? This action cannot be undone.',
      confirmText: 'Delete',
      isDangerous: true,
    );

    if (confirmed) {
      try {
        await _exportService.deleteExportedFile(fileInfo.path);
        await _loadExportedFiles();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File deleted successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );
      } catch (e) {
        DialogHelper.showError(
          context,
          title: 'Delete Failed',
          message: 'Failed to delete the exported file.',
          details: e.toString(),
        );
      }
    }
  }

  Future<void> _clearAllFiles() async {
    if (_exportedFiles.isEmpty) return;

    final confirmed = await DialogHelper.showWarning(
      context,
      title: 'Clear All Exports',
      message: 'Are you sure you want to delete all exported files? This action cannot be undone.',
      confirmText: 'Clear All',
      isDangerous: true,
    );

    if (confirmed) {
      try {
        await _exportService.clearAllExportedFiles();
        await _loadExportedFiles();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All exported files cleared'),
            backgroundColor: AppColors.successColor,
          ),
        );
      } catch (e) {
        DialogHelper.showError(
          context,
          title: 'Clear Failed',
          message: 'Failed to clear exported files.',
          details: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export SMS Messages'),
        actions: [
          if (_exportedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllFiles,
              tooltip: 'Clear All Exports',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LoadingOverlay(
                isLoading: _isLoading,
                message: 'Loading SMS messages...',
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SMS Info Card
                      _buildSMSInfoCard(),

                      const SizedBox(height: AppDimensions.paddingLarge),

                      // Export Options Card
                      _buildExportOptionsCard(),

                      const SizedBox(height: AppDimensions.paddingLarge),

                      // Export Progress Card
                      if (_isExporting) _buildExportProgressCard(),

                      // Exported Files Section
                      _buildExportedFilesSection(),
                    ],
                  ),
                ),
              ),
            ),
            const AdMobBannerWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildSMSInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.message,
                  color: AppColors.primaryColor,
                  size: AppDimensions.iconSizeLarge,
                ),
                const SizedBox(width: AppDimensions.paddingMedium),
                Expanded(
                  child: Text(
                    'SMS Messages',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    icon: Icons.sms,
                    label: 'Total Messages',
                    value: _smsMessages.length.toString(),
                    color: AppColors.primaryColor,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    icon: Icons.send,
                    label: 'Sent',
                    value: _smsMessages.where((msg) => msg.isSent).length.toString(),
                    color: AppColors.successColor,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    icon: Icons.inbox,
                    label: 'Received',
                    value: _smsMessages.where((msg) => !msg.isSent).length.toString(),
                    color: AppColors.accentColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: AppDimensions.iconSizeLarge,
        ),
        const SizedBox(height: AppDimensions.paddingSmall),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildExportOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Options',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            Text(
              'Choose export format:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            Wrap(
              spacing: AppDimensions.paddingSmall,
              runSpacing: AppDimensions.paddingSmall,
              children: ExportFormat.values.map((format) {
                return ChoiceChip(
                  label: Text(format.name.toUpperCase()),
                  selected: _selectedFormat == format,
                  onSelected: _isExporting ? null : (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFormat = format;
                      });
                    }
                  },
                  selectedColor: AppColors.primaryColor.withOpacity(0.3),
                  labelStyle: TextStyle(
                    color: _selectedFormat == format
                        ? AppColors.primaryColor
                        : AppColors.textSecondary,
                    fontWeight: _selectedFormat == format
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildFormatDescription(),
            const SizedBox(height: AppDimensions.paddingLarge),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isExporting || _smsMessages.isEmpty ? null : _startExport,
                icon: _isExporting
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.file_download),
                label: Text(_isExporting ? 'Exporting...' : 'Start Export'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatDescription() {
    String description;
    IconData icon;

    switch (_selectedFormat) {
      case ExportFormat.csv:
        description = 'Comma-separated values - Compatible with Excel and spreadsheet applications';
        icon = Icons.table_chart;
        break;
      case ExportFormat.xlsx:
        description = 'Excel format - Formatted spreadsheet with columns and styling';
        icon = Icons.grid_on;
        break;
      case ExportFormat.json:
        description = 'JSON format - Structured data for developers and advanced users';
        icon = Icons.code;
        break;
      case ExportFormat.txt:
        description = 'Plain text - Human-readable format for viewing and printing';
        icon = Icons.text_snippet;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primaryColor,
            size: AppDimensions.iconSizeMedium,
          ),
          const SizedBox(width: AppDimensions.paddingMedium),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportProgressCard() {
    if (_exportProgress == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Progress',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            LinearProgressIndicator(
              value: _exportProgress!.progress,
              backgroundColor: AppColors.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _exportProgress!.status,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  _exportProgress!.progressPercentage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportedFilesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder,
                  color: AppColors.primaryColor,
                  size: AppDimensions.iconSizeLarge,
                ),
                const SizedBox(width: AppDimensions.paddingMedium),
                Expanded(
                  child: Text(
                    'Exported Files',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${_exportedFiles.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            if (_exportedFiles.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.textSecondary,
                      size: AppDimensions.iconSizeMedium,
                    ),
                    const SizedBox(width: AppDimensions.paddingMedium),
                    Expanded(
                      child: Text(
                        'No exported files yet. Start by exporting your SMS messages.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exportedFiles.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final file = _exportedFiles[index];
                  return _buildFileListItem(file);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileListItem(FileInfo file) {
    return ListTile(
      leading: Icon(
        _getFileIcon(file.format),
        color: _getFileColor(file.format),
        size: AppDimensions.iconSizeLarge,
      ),
      title: Text(
        file.name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${file.formattedSize} • ${file.formattedDate}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            file.format.name.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _getFileColor(file.format),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) {
          switch (action) {
            case 'share':
              _shareFile(file);
              break;
            case 'delete':
              _deleteFile(file);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'share',
            child: Row(
              children: [
                Icon(Icons.share),
                SizedBox(width: AppDimensions.paddingSmall),
                Text('Share'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: AppColors.errorColor),
                SizedBox(width: AppDimensions.paddingSmall),
                Text('Delete', style: TextStyle(color: AppColors.errorColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(ExportFormat format) {
    switch (format) {
      case ExportFormat.csv:
        return Icons.table_chart;
      case ExportFormat.xlsx:
        return Icons.grid_on;
      case ExportFormat.json:
        return Icons.code;
      case ExportFormat.txt:
        return Icons.text_snippet;
    }
  }

  Color _getFileColor(ExportFormat format) {
    switch (format) {
      case ExportFormat.csv:
        return Colors.green;
      case ExportFormat.xlsx:
        return Colors.blue;
      case ExportFormat.json:
        return Colors.orange;
      case ExportFormat.txt:
        return Colors.grey;
    }
  }
}