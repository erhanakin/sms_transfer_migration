import 'dart:convert';
import '../utils/constants.dart';

class TransferSession {
  final String sessionId;
  final String deviceName;
  final String ipAddress;
  final int port;
  final DateTime createdAt;
  final TransferMode mode;
  TransferStatus status;
  int totalMessages;
  int transferredMessages;
  String? errorMessage;

  TransferSession({
    required this.sessionId,
    required this.deviceName,
    required this.ipAddress,
    required this.port,
    required this.createdAt,
    required this.mode,
    this.status = TransferStatus.idle,
    this.totalMessages = 0,
    this.transferredMessages = 0,
    this.errorMessage,
  });

  factory TransferSession.fromJson(Map<String, dynamic> json) {
    return TransferSession(
      sessionId: json['session_id'] ?? '',
      deviceName: json['device_name'] ?? '',
      ipAddress: json['ip_address'] ?? '',
      port: json['port'] ?? AppConstants.transferPort,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      mode: TransferMode.values.firstWhere(
            (mode) => mode.name == json['mode'],
        orElse: () => TransferMode.receiver,
      ),
      status: TransferStatus.values.firstWhere(
            (status) => status.name == json['status'],
        orElse: () => TransferStatus.idle,
      ),
      totalMessages: json['total_messages'] ?? 0,
      transferredMessages: json['transferred_messages'] ?? 0,
      errorMessage: json['error_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'device_name': deviceName,
      'ip_address': ipAddress,
      'port': port,
      'created_at': createdAt.toIso8601String(),
      'mode': mode.name,
      'status': status.name,
      'total_messages': totalMessages,
      'transferred_messages': transferredMessages,
      'error_message': errorMessage,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  double get progress {
    if (totalMessages == 0) return 0.0;
    return transferredMessages / totalMessages;
  }

  String get progressPercentage {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  bool get isCompleted => status == TransferStatus.completed;
  bool get hasError => status == TransferStatus.error;
  bool get isTransferring => status == TransferStatus.transferring;
  bool get isIdle => status == TransferStatus.idle;

  void updateProgress(int transferred, int total) {
    transferredMessages = transferred;
    totalMessages = total;
  }

  void setError(String error) {
    status = TransferStatus.error;
    errorMessage = error;
  }

  void setCompleted() {
    status = TransferStatus.completed;
    transferredMessages = totalMessages;
  }

  void setTransferring() {
    status = TransferStatus.transferring;
  }

  void setPreparing() {
    status = TransferStatus.preparing;
  }

  @override
  String toString() {
    return 'TransferSession{sessionId: $sessionId, deviceName: $deviceName, status: $status, progress: $progressPercentage}';
  }
}

class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final int port;
  final String osVersion;
  final String appVersion;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.port,
    required this.osVersion,
    required this.appVersion,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['device_id'] ?? '',
      deviceName: json['device_name'] ?? '',
      ipAddress: json['ip_address'] ?? '',
      port: json['port'] ?? AppConstants.transferPort,
      osVersion: json['os_version'] ?? '',
      appVersion: json['app_version'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'ip_address': ipAddress,
      'port': port,
      'os_version': osVersion,
      'app_version': appVersion,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  @override
  String toString() {
    return 'DeviceInfo{deviceName: $deviceName, ipAddress: $ipAddress}';
  }
}

class TransferMessage {
  final String type;
  final Map<String, dynamic> data;
  final String sessionId;
  final DateTime timestamp;

  TransferMessage({
    required this.type,
    required this.data,
    required this.sessionId,
    required this.timestamp,
  });

  factory TransferMessage.fromJson(Map<String, dynamic> json) {
    return TransferMessage(
      type: json['type'] ?? '',
      data: json['data'] ?? {},
      sessionId: json['session_id'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      'session_id': sessionId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory TransferMessage.discovery(DeviceInfo deviceInfo, String sessionId) {
    return TransferMessage(
      type: MessageTypes.discovery,
      data: deviceInfo.toJson(),
      sessionId: sessionId,
      timestamp: DateTime.now(),
    );
  }

  factory TransferMessage.discoveryResponse(DeviceInfo deviceInfo, String sessionId) {
    return TransferMessage(
      type: MessageTypes.discoveryResponse,
      data: deviceInfo.toJson(),
      sessionId: sessionId,
      timestamp: DateTime.now(),
    );
  }

  factory TransferMessage.error(String errorMessage, String sessionId) {
    return TransferMessage(
      type: MessageTypes.error,
      data: {'error': errorMessage},
      sessionId: sessionId,
      timestamp: DateTime.now(),
    );
  }
}