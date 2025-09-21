import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/sms_service.dart';
import '../services/network_service.dart';
import '../services/qr_service.dart';
import '../services/admob_service.dart';
import '../models/sms_model.dart';
import '../models/transfer_session.dart';
import '../utils/constants.dart';
import '../widgets/error_dialog.dart';
import '../widgets/progress_indicator_widget.dart';
import '../widgets/admob_banner.dart';

class SenderScreen extends ConsumerStatefulWidget {
  const SenderScreen({super.key});

  @override
  ConsumerState<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends ConsumerState<SenderScreen> {
  final SMSService _smsService = SMSService();
  final NetworkService _networkService = NetworkService();
  final QRService _qrService = QRService();
  final AdMobService _adMobService = AdMobService();

  TransferSession? _transferSession;
  List<SMSMessage> _smsMessages = [];
  bool _isLoading = false;
  bool _isGeneratingQR = false;
  bool _isTransferring = false;
  String? _qrData;
  DeviceInfo? _deviceInfo;

  @override
  void initState() {
    super.initState();
    _initializeSender();
  }

  Future<void> _initializeSender() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load SMS messages
      await _loadSMSMessages();

      // Initialize device info
      await _initializeDeviceInfo();
    } catch (e) {
      if (mounted) {
        DialogHelper.showError(
          context,
          title: 'Initialization Error',
          message: 'Failed to initialize sender mode.',
          details: e.toString(),
          showRetry: true,
          onRetry: _initializeSender,
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

  Future<void> _loadSMSMessages() async {
    try {
      final messages = await _smsService.getAllSMS();
      setState(() {
        _smsMessages = messages;
      });
    } catch (e) {
      throw Exception('Failed to load SMS messages: $e');
    }
  }

  Future<void> _initializeDeviceInfo() async {
    try {
      final deviceIP = await _networkService.getDeviceIP();
      if (deviceIP == null) {
        throw Exception('Could not get device IP address');
      }

      _deviceInfo = DeviceInfo(
        deviceId: const Uuid().v4(),
        deviceName: 'Android Device', // You can get actual device name
        ipAddress: deviceIP,
        port: AppConstants.transferPort,
        osVersion: 'Android', // You can get actual OS version
        appVersion: AppConstants.version,
      );
    } catch (e) {
      throw Exception('Failed to initialize device info: $e');
    }
  }

  Future<void> _generateQRCode() async {
    if (_deviceInfo == null) {
      DialogHelper.showError(
        context,
        title: 'Error',
        message: 'Device information not available.',
      );
      return;
    }

    setState(() {
      _isGeneratingQR = true;
    });

    try {
      // Create transfer session
      final sessionId = const Uuid().v4();
      _transferSession = TransferSession(
        sessionId: sessionId,
        deviceName: _deviceInfo!.deviceName,
        ipAddress: _deviceInfo!.ipAddress,
        port: _deviceInfo!.port,
        createdAt: DateTime.now(),
        mode: TransferMode.sender,
        totalMessages: _smsMessages.length,
      );

      // Start server
      final serverStarted = await _networkService.startServer(
        port: _deviceInfo!.port,
        sessionId: sessionId,
        deviceInfo: _deviceInfo!,
      );

      if (!serverStarted) {
        throw Exception('Failed to start server');
      }

      // Generate QR code
      _qrData = _qrService.generatePairingQR(
        deviceInfo: _deviceInfo!,
        sessionId: sessionId,
      );

      setState(() {
        _transferSession?.setPreparing();
      });

    } catch (e) {
      DialogHelper.showError(
        context,
        title: 'QR Generation Failed',
        message: 'Failed to generate QR code for pairing.',
        details: e.toString(),
        showRetry: true,
        onRetry: _generateQRCode,
      );
    } finally {
      setState(() {
        _isGeneratingQR = false;
      });
    }
  }

  Future<void> _startTransfer(DeviceInfo receiverDevice) async {
    if (_transferSession == null) return;

    setState(() {
      _isTransferring = true;
      _transferSession?.setTransferring();
    });

    try {
      int transferredCount = 0;

      // Send SMS in batches
      await for (final batch in _smsService.getSMSBatches(
        batchSize: AppConstants.maxSMSBatchSize,
        sessionId: _transferSession!.sessionId,
      )) {
        final success = await _networkService.sendSMSBatch(
          receiverIP: receiverDevice.ipAddress,
          receiverPort: receiverDevice.port,
          batch: batch,
          sessionId: _transferSession!.sessionId,
        );

        if (success) {
          transferredCount += batch.messages.length;
          setState(() {
            _transferSession?.updateProgress(transferredCount, _smsMessages.length);
          });
        } else {
          throw Exception('Failed to send batch ${batch.batchNumber}');
        }

        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Send completion message
      await _networkService.sendTransferComplete(
        receiverIP: receiverDevice.ipAddress,
        receiverPort: receiverDevice.port,
        sessionId: _transferSession!.sessionId,
        totalMessages: _smsMessages.length,
      );

      setState(() {
        _transferSession?.setCompleted();
      });

      // Show success dialog
      DialogHelper.showSuccess(
        context,
        title: 'Transfer Complete',
        message: 'Successfully transferred ${_smsMessages.length} SMS messages to ${receiverDevice.deviceName}.',
        onOk: () {
          _adMobService.showAdAfterAction(action: 'transfer_complete');
        },
      );

    } catch (e) {
      setState(() {
        _transferSession?.setError(e.toString());
      });

      DialogHelper.showError(
        context,
        title: 'Transfer Failed',
        message: 'Failed to transfer SMS messages.',
        details: e.toString(),
        showRetry: true,
        onRetry: () => _startTransfer(receiverDevice),
      );
    } finally {
      setState(() {
        _isTransferring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send SMS Messages'),
        actions: [
          if (_transferSession != null)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopTransfer,
              tooltip: 'Stop Transfer',
            ),
        ],
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
                    // SMS Info Card
                    _buildSMSInfoCard(),

                    const SizedBox(height: AppDimensions.paddingLarge),

                    // QR Code Section
                    if (_qrData != null) _buildQRCodeSection(),

                    // Transfer Progress Section
                    if (_transferSession != null) _buildTransferProgressSection(),

                    const SizedBox(height: AppDimensions.paddingLarge),

                    // Action Buttons
                    _buildActionButtons(),
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
                    'SMS Messages Ready',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  _buildStatRow(
                    icon: Icons.sms,
                    label: 'Total Messages',
                    value: _smsMessages.length.toString(),
                  ),
                  const SizedBox(height: AppDimensions.paddingSmall),
                  _buildStatRow(
                    icon: Icons.wifi,
                    label: 'Device IP',
                    value: _deviceInfo?.ipAddress ?? 'Unknown',
                  ),
                  const SizedBox(height: AppDimensions.paddingSmall),
                  _buildStatRow(
                    icon: Icons.phone_android,
                    label: 'Device Name',
                    value: _deviceInfo?.deviceName ?? 'Unknown',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow({
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
    );
  }

  Widget _buildQRCodeSection() {
    if (_deviceInfo == null || _transferSession == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          children: [
            Text(
              'Scan QR Code on Receiving Device',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            _qrService.createPairingQRWidget(
              deviceInfo: _deviceInfo!,
              sessionId: _transferSession!.sessionId,
            ),
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
                    Icons.info_outline,
                    color: AppColors.primaryColor,
                    size: AppDimensions.iconSizeMedium,
                  ),
                  const SizedBox(width: AppDimensions.paddingMedium),
                  Expanded(
                    child: Text(
                      'Keep this screen open until the transfer is complete. Make sure both devices are connected to the same Wi-Fi network.',
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

  Widget _buildTransferProgressSection() {
    if (_transferSession == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(_transferSession!.status),
                  color: _getStatusColor(_transferSession!.status),
                  size: AppDimensions.iconSizeLarge,
                ),
                const SizedBox(width: AppDimensions.paddingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _getStatusText(_transferSession!.status),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_transferSession!.isTransferring) ...[
              const SizedBox(height: AppDimensions.paddingMedium),
              LinearProgressIndicator(
                value: _transferSession!.progress,
                backgroundColor: AppColors.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
              const SizedBox(height: AppDimensions.paddingSmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_transferSession!.transferredMessages} / ${_transferSession!.totalMessages}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _transferSession!.progressPercentage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
            if (_transferSession!.hasError) ...[
              const SizedBox(height: AppDimensions.paddingMedium),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                  border: Border.all(color: AppColors.errorColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: AppColors.errorColor,
                      size: AppDimensions.iconSizeMedium,
                    ),
                    const SizedBox(width: AppDimensions.paddingMedium),
                    Expanded(
                      child: Text(
                        _transferSession!.errorMessage ?? 'Unknown error',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_qrData == null && !_isGeneratingQR)
          ElevatedButton.icon(
            onPressed: _smsMessages.isEmpty ? null : _generateQRCode,
            icon: const Icon(Icons.qr_code),
            label: const Text('Generate QR Code'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
            ),
          ),

        if (_isGeneratingQR)
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppDimensions.paddingMedium),
                Text('Generating QR Code...'),
              ],
            ),
          ),

        if (_transferSession != null && _transferSession!.isCompleted)
          ElevatedButton.icon(
            onPressed: _resetTransfer,
            icon: const Icon(Icons.refresh),
            label: const Text('Start New Transfer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successColor,
              minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
            ),
          ),

        if (_transferSession != null && !_transferSession!.isCompleted && !_transferSession!.hasError)
          ElevatedButton.icon(
            onPressed: _stopTransfer,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Transfer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
              minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
            ),
          ),
      ],
    );
  }

  IconData _getStatusIcon(TransferStatus status) {
    switch (status) {
      case TransferStatus.idle:
        return Icons.radio_button_unchecked;
      case TransferStatus.preparing:
        return Icons.settings;
      case TransferStatus.transferring:
        return Icons.sync;
      case TransferStatus.completed:
        return Icons.check_circle;
      case TransferStatus.error:
        return Icons.error;
    }
  }

  Color _getStatusColor(TransferStatus status) {
    switch (status) {
      case TransferStatus.idle:
        return AppColors.textSecondary;
      case TransferStatus.preparing:
        return AppColors.warningColor;
      case TransferStatus.transferring:
        return AppColors.primaryColor;
      case TransferStatus.completed:
        return AppColors.successColor;
      case TransferStatus.error:
        return AppColors.errorColor;
    }
  }

  String _getStatusText(TransferStatus status) {
    switch (status) {
      case TransferStatus.idle:
        return 'Ready to start transfer';
      case TransferStatus.preparing:
        return 'Preparing for transfer...';
      case TransferStatus.transferring:
        return 'Transferring messages...';
      case TransferStatus.completed:
        return 'Transfer completed successfully';
      case TransferStatus.error:
        return 'Transfer failed';
    }
  }

  void _stopTransfer() async {
    final confirmed = await DialogHelper.showWarning(
      context,
      title: 'Stop Transfer',
      message: 'Are you sure you want to stop the current transfer? This action cannot be undone.',
      confirmText: 'Stop',
      isDangerous: true,
    );

    if (confirmed) {
      await _networkService.stopServer();
      setState(() {
        _transferSession = null;
        _qrData = null;
        _isTransferring = false;
      });
    }
  }

  void _resetTransfer() {
    setState(() {
      _transferSession = null;
      _qrData = null;
      _isTransferring = false;
    });
  }

  @override
  void dispose() {
    _networkService.stopServer();
    _networkService.dispose();
    super.dispose();
  }
}