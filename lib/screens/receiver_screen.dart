import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/sms_service.dart';
import '../services/network_service.dart';
import '../services/qr_service.dart';
import '../services/admob_service.dart';
import '../models/sms_model.dart';
import '../models/transfer_session.dart';
import '../utils/constants.dart';
import '../widgets/error_dialog.dart';
import '../widgets/admob_banner.dart';

class ReceiverScreen extends ConsumerStatefulWidget {
  const ReceiverScreen({super.key});

  @override
  ConsumerState<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends ConsumerState<ReceiverScreen> {
  final SMSService _smsService = SMSService();
  final NetworkService _networkService = NetworkService();
  final QRService _qrService = QRService();
  final AdMobService _adMobService = AdMobService();

  MobileScannerController? _scannerController;

  TransferSession? _transferSession;
  QRPairingData? _pairingData;
  bool _isScanning = true;
  bool _isReceiving = false;
  List<SMSMessage> _receivedMessages = [];
  int _totalExpectedMessages = 0;

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
    _initializeScanner();
  }

  void _initializeScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  void _setupMessageListener() {
    _networkService.messageStream.listen((message) {
      _handleIncomingMessage(message);
    });
  }

  void _handleIncomingMessage(TransferMessage message) {
    switch (message.type) {
      case MessageTypes.transferRequest:
        _handleTransferRequest(message);
        break;
      case MessageTypes.smsData:
        _handleSMSData(message);
        break;
      case MessageTypes.transferComplete:
        _handleTransferComplete(message);
        break;
      case MessageTypes.error:
        _handleTransferError(message);
        break;
    }
  }

  void _handleTransferRequest(TransferMessage message) {
    final totalMessages = message.data['total_messages'] ?? 0;
    setState(() {
      _totalExpectedMessages = totalMessages;
      _transferSession?.setPreparing();
    });
  }

  void _handleSMSData(TransferMessage message) {
    try {
      final batch = SMSBatch.fromJson(message.data);
      setState(() {
        _receivedMessages.addAll(batch.messages);
        _transferSession?.updateProgress(_receivedMessages.length, _totalExpectedMessages);
      });
    } catch (e) {
      print('Error handling SMS data: $e');
    }
  }

  void _handleTransferComplete(TransferMessage message) async {
    try {
      // Write received messages to device
      await _smsService.writeSMSMessages(_receivedMessages);

      setState(() {
        _transferSession?.setCompleted();
      });

      DialogHelper.showSuccess(
        context,
        title: 'Transfer Complete',
        message: 'Successfully received ${_receivedMessages.length} SMS messages.',
        onOk: () {
          _adMobService.showAdAfterAction(action: 'transfer_complete');
        },
      );
    } catch (e) {
      setState(() {
        _transferSession?.setError('Failed to save messages: $e');
      });
    }
  }

  void _handleTransferError(TransferMessage message) {
    final errorMsg = message.data['error'] ?? 'Unknown error';
    setState(() {
      _transferSession?.setError(errorMsg);
    });
  }

  void _onQRCodeDetected(BarcodeCapture capture) async {
    if (!_isScanning || capture.barcodes.isEmpty) return;

    final String? qrData = capture.barcodes.first.rawValue;
    if (qrData == null) return;

    setState(() {
      _isScanning = false;
    });

    try {
      final pairingData = _qrService.parsePairingQR(qrData);

      if (pairingData == null || !pairingData.isValid) {
        throw Exception('Invalid QR code format');
      }

      if (pairingData.isExpired) {
        throw Exception('QR code has expired. Please generate a new one.');
      }

      setState(() {
        _pairingData = pairingData;
      });

      await _initializeReceiver();

    } catch (e) {
      DialogHelper.showError(
        context,
        title: 'QR Code Error',
        message: 'Failed to process QR code.',
        details: e.toString(),
        onRetry: () {
          setState(() {
            _isScanning = true;
          });
        },
      );
    }
  }

  Future<void> _initializeReceiver() async {
    if (_pairingData == null) return;

    try {
      // Create transfer session
      _transferSession = TransferSession(
        sessionId: _pairingData!.sessionId,
        deviceName: _pairingData!.deviceInfo.deviceName,
        ipAddress: _pairingData!.deviceInfo.ipAddress,
        port: _pairingData!.deviceInfo.port,
        createdAt: DateTime.now(),
        mode: TransferMode.receiver,
      );

      // Check if sender device is reachable
      final isReachable = await _networkService.isDeviceReachable(
        _pairingData!.deviceInfo.ipAddress,
        _pairingData!.deviceInfo.port,
      );

      if (!isReachable) {
        throw Exception('Cannot reach sender device. Make sure both devices are on the same network.');
      }

      setState(() {
        _isReceiving = true;
        _transferSession?.setTransferring();
      });

      DialogHelper.showSuccess(
        context,
        title: 'Connected',
        message: 'Successfully connected to ${_pairingData!.deviceInfo.deviceName}. Transfer will begin shortly.',
      );

    } catch (e) {
      DialogHelper.showError(
        context,
        title: 'Connection Failed',
        message: 'Failed to connect to sender device.',
        details: e.toString(),
        showRetry: true,
        onRetry: _initializeReceiver,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive SMS Messages'),
        actions: [
          if (_isReceiving)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopReceiving,
              tooltip: 'Stop Receiving',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _pairingData == null ? _buildQRScannerView() : _buildReceivingView(),
            ),
            const AdMobBannerWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildQRScannerView() {
    return Column(
      children: [
        // Instructions Card
        Card(
          margin: const EdgeInsets.all(AppDimensions.paddingMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Column(
              children: [
                Icon(
                  Icons.qr_code,
                  size: AppDimensions.iconSizeXLarge,
                  color: AppColors.primaryColor,
                ),
                const SizedBox(height: AppDimensions.paddingMedium),
                Text(
                  'Scan QR Code',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingSmall),
                Text(
                  'Point your camera at the QR code displayed on the sending device to start receiving SMS messages.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // QR Scanner
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(AppDimensions.paddingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
              border: Border.all(
                color: AppColors.primaryColor,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onQRCodeDetected,
                  ),
                  _buildScannerOverlay(),
                ],
              ),
            ),
          ),
        ),

        // Scanner Controls
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => _scannerController?.toggleTorch(),
                icon: const Icon(Icons.flash_on),
                iconSize: AppDimensions.iconSizeLarge,
                tooltip: 'Toggle Flash',
              ),
              IconButton(
                onPressed: () => _scannerController?.switchCamera(),
                icon: const Icon(Icons.flip_camera_ios),
                iconSize: AppDimensions.iconSizeLarge,
                tooltip: 'Switch Camera',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.transparent,
          width: 0,
        ),
      ),
      child: Stack(
        children: [
          // Corner brackets
          Positioned(
            top: 50,
            left: 50,
            child: _buildCornerBracket(true, true),
          ),
          Positioned(
            top: 50,
            right: 50,
            child: _buildCornerBracket(true, false),
          ),
          Positioned(
            bottom: 50,
            left: 50,
            child: _buildCornerBracket(false, true),
          ),
          Positioned(
            bottom: 50,
            right: 50,
            child: _buildCornerBracket(false, false),
          ),
          // Scanning instruction
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMedium,
                vertical: AppDimensions.paddingSmall,
              ),
              color: Colors.black54,
              child: Text(
                'Position QR code within the frame',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerBracket(bool top, bool left) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: AppColors.primaryColor, width: 4) : BorderSide.none,
          left: left ? BorderSide(color: AppColors.primaryColor, width: 4) : BorderSide.none,
          bottom: !top ? BorderSide(color: AppColors.primaryColor, width: 4) : BorderSide.none,
          right: !left ? BorderSide(color: AppColors.primaryColor, width: 4) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildReceivingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildConnectionInfoCard(),
          const SizedBox(height: AppDimensions.paddingLarge),
          _buildTransferProgressCard(),
          const SizedBox(height: AppDimensions.paddingLarge),
          _buildReceivedMessagesSummary(),
          const SizedBox(height: AppDimensions.paddingLarge),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildConnectionInfoCard() {
    if (_pairingData == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.link,
                  color: AppColors.successColor,
                  size: AppDimensions.iconSizeLarge,
                ),
                const SizedBox(width: AppDimensions.paddingMedium),
                Expanded(
                  child: Text(
                    'Connected to Sender',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildInfoRow(
              icon: Icons.phone_android,
              label: 'Device Name',
              value: _pairingData!.deviceInfo.deviceName,
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            _buildInfoRow(
              icon: Icons.wifi,
              label: 'IP Address',
              value: _pairingData!.deviceInfo.ipAddress,
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            _buildInfoRow(
              icon: Icons.security,
              label: 'Session ID',
              value: _pairingData!.sessionId.substring(0, 8) + '...',
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

  Widget _buildTransferProgressCard() {
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
            if (_isReceiving && _totalExpectedMessages > 0) ...[
              const SizedBox(height: AppDimensions.paddingMedium),
              LinearProgressIndicator(
                value: _totalExpectedMessages > 0 ? _receivedMessages.length / _totalExpectedMessages : 0,
                backgroundColor: AppColors.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
              const SizedBox(height: AppDimensions.paddingSmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_receivedMessages.length} / $_totalExpectedMessages',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _totalExpectedMessages > 0
                        ? '${((_receivedMessages.length / _totalExpectedMessages) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedMessagesSummary() {
    if (_receivedMessages.isEmpty) return const SizedBox.shrink();

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
                Text(
                  'Received Messages',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildInfoRow(
              icon: Icons.sms,
              label: 'Total Received',
              value: _receivedMessages.length.toString(),
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            _buildInfoRow(
              icon: Icons.send,
              label: 'Sent Messages',
              value: _receivedMessages.where((msg) => msg.isSent).length.toString(),
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            _buildInfoRow(
              icon: Icons.inbox,
              label: 'Received Messages',
              value: _receivedMessages.where((msg) => !msg.isSent).length.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_transferSession != null && _transferSession!.isCompleted)
          ElevatedButton.icon(
            onPressed: _startNewReceive,
            icon: const Icon(Icons.refresh),
            label: const Text('Receive More Messages'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successColor,
              minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
            ),
          ),

        if (_isReceiving && !(_transferSession?.isCompleted ?? false))
          ElevatedButton.icon(
            onPressed: _stopReceiving,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Receiving'),
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
        return Icons.download;
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
        return 'Ready to receive';
      case TransferStatus.preparing:
        return 'Preparing to receive...';
      case TransferStatus.transferring:
        return 'Receiving messages...';
      case TransferStatus.completed:
        return 'Transfer completed successfully';
      case TransferStatus.error:
        return 'Transfer failed';
    }
  }

  void _stopReceiving() async {
    final confirmed = await DialogHelper.showWarning(
      context,
      title: 'Stop Receiving',
      message: 'Are you sure you want to stop receiving messages? Any messages not yet received will be lost.',
      confirmText: 'Stop',
      isDangerous: true,
    );

    if (confirmed) {
      _resetReceiver();
    }
  }

  void _startNewReceive() {
    _resetReceiver();
  }

  void _resetReceiver() {
    setState(() {
      _pairingData = null;
      _transferSession = null;
      _isScanning = true;
      _isReceiving = false;
      _receivedMessages.clear();
      _totalExpectedMessages = 0;
    });
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }
}