import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import '../models/sms_model.dart';
import '../models/transfer_session.dart';
import '../utils/constants.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  HttpServer? _server;
  final StreamController<TransferMessage> _messageController = StreamController.broadcast();
  final StreamController<DeviceInfo> _deviceDiscoveryController = StreamController.broadcast();

  Stream<TransferMessage> get messageStream => _messageController.stream;
  Stream<DeviceInfo> get deviceDiscoveryStream => _deviceDiscoveryController.stream;

  /// Get device IP address
  Future<String?> getDeviceIP() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      print('🌐 Device IP: $wifiIP');
      return wifiIP;
    } catch (e) {
      print('❌ Error getting device IP: $e');
      return null;
    }
  }

  /// Get device network info
  Future<Map<String, dynamic>> getNetworkInfo() async {
    try {
      final info = NetworkInfo();
      final wifiName = await info.getWifiName();
      final wifiIP = await info.getWifiIP();
      final wifiBSSID = await info.getWifiBSSID();

      final networkInfo = {
        'wifi_name': wifiName,
        'wifi_ip': wifiIP,
        'wifi_bssid': wifiBSSID,
      };

      print('🌐 Network info: $networkInfo');
      return networkInfo;
    } catch (e) {
      print('❌ Error getting network info: $e');
      return {};
    }
  }

  /// Start HTTP server for receiving transfers
  Future<bool> startServer({
    int port = 8080,
    required String sessionId,
    required DeviceInfo deviceInfo,
  }) async {
    try {
      // Stop existing server if running
      await stopServer();

      print('🚀 Starting HTTP server on port $port...');
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);

      print('✅ Server bound successfully to 0.0.0.0:$port');
      print('📱 Device IP: ${deviceInfo.ipAddress}');
      print('🔐 Session ID: $sessionId');

      // Listen to incoming requests
      _server!.listen(
            (HttpRequest request) async {
          print('📨 Incoming ${request.method} ${request.uri.path} from ${request.connectionInfo?.remoteAddress}');
          await _handleRequest(request, sessionId, deviceInfo);
        },
        onError: (error) {
          print('❌ Server error: $error');
        },
        onDone: () {
          print('🛑 Server closed');
        },
      );

      return true;
    } catch (e) {
      print('❌ Failed to start server: $e');
      return false;
    }
  }

  /// Stop HTTP server
  Future<void> stopServer() async {
    try {
      if (_server != null) {
        await _server!.close(force: true);
        _server = null;
        print('🛑 Server stopped successfully');
      }
    } catch (e) {
      print('❌ Error stopping server: $e');
    }
  }

  /// Handle incoming HTTP requests
  Future<void> _handleRequest(
      HttpRequest request,
      String sessionId,
      DeviceInfo deviceInfo,
      ) async {
    try {
      // Enable CORS for all requests
      _setCorsHeaders(request.response);

      if (request.method == 'OPTIONS') {
        print('✅ OPTIONS preflight request handled');
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final path = request.uri.path;
      print('🛣️  Processing ${request.method} $path');

      switch (path) {
        case '/discover':
          await _handleDiscoveryEndpoint(request, sessionId, deviceInfo);
          break;
        case '/sms-transfer':
          await _handleTransferEndpoint(request, sessionId);
          break;
        case '/health':
          await _handleHealthCheck(request);
          break;
        default:
          print('❌ Unknown endpoint: $path');
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('Endpoint not found: $path');
          await request.response.close();
      }
    } catch (e) {
      print('❌ Error handling request: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Internal server error: $e');
        await request.response.close();
      } catch (closeError) {
        print('❌ Error closing error response: $closeError');
      }
    }
  }

  /// Set CORS headers
  void _setCorsHeaders(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    response.headers.set('Access-Control-Max-Age', '86400');
  }

  /// Handle health check endpoint
  Future<void> _handleHealthCheck(HttpRequest request) async {
    try {
      print('💗 Health check requested');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
        'server': 'SMS Transfer Service'
      }));
      await request.response.close();
      print('✅ Health check response sent');
    } catch (e) {
      print('❌ Health check error: $e');
      rethrow;
    }
  }

  /// Handle discovery endpoint
  Future<void> _handleDiscoveryEndpoint(
      HttpRequest request,
      String sessionId,
      DeviceInfo deviceInfo,
      ) async {
    try {
      print('🔍 Discovery request: ${request.method}');

      if (request.method == 'GET') {
        // Simple GET request - respond with device info
        final response = {
          'type': 'discovery_response',
          'device_info': deviceInfo.toJson(),
          'session_id': sessionId,
          'timestamp': DateTime.now().toIso8601String(),
        };

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
        print('✅ Discovery GET response sent');
      } else if (request.method == 'POST') {
        // POST request with discovery data
        final body = await _readRequestBody(request);
        print('📥 Discovery POST body: ${body.substring(0, body.length.clamp(0, 200))}...');

        final data = jsonDecode(body);
        final message = TransferMessage.fromJson(data);

        if (message.type == MessageTypes.discovery) {
          final discoveredDevice = DeviceInfo.fromJson(message.data);
          print('🎯 Device discovered: ${discoveredDevice.deviceName} at ${discoveredDevice.ipAddress}');

          // Notify listeners about discovered device
          _deviceDiscoveryController.add(discoveredDevice);

          // Send response
          final response = TransferMessage.discoveryResponse(deviceInfo, sessionId);
          request.response.headers.contentType = ContentType.json;
          request.response.write(response.toJsonString());
          await request.response.close();
          print('✅ Discovery POST response sent');
        } else {
          throw Exception('Invalid discovery message type: ${message.type}');
        }
      } else {
        throw Exception('Unsupported method for discovery: ${request.method}');
      }
    } catch (e) {
      print('❌ Discovery error: $e');
      rethrow;
    }
  }

  /// Handle transfer endpoint
  Future<void> _handleTransferEndpoint(
      HttpRequest request,
      String sessionId,
      ) async {
    try {
      if (request.method != 'POST') {
        throw Exception('Transfer endpoint only supports POST');
      }

      final body = await _readRequestBody(request);
      print('📥 Transfer data received: ${body.length} bytes');

      final data = jsonDecode(body);
      final message = TransferMessage.fromJson(data);

      print('📨 Transfer message type: ${message.type}');
      print('🔐 Session ID match: ${message.sessionId == sessionId}');

      // Forward message to listeners
      _messageController.add(message);

      // Send acknowledgment
      final ackResponse = {
        'status': 'received',
        'message_type': message.type,
        'session_id': sessionId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(ackResponse));
      await request.response.close();

      print('✅ Transfer message processed and acknowledged');
    } catch (e) {
      print('❌ Transfer error: $e');
      rethrow;
    }
  }

  /// Read request body as string
  Future<String> _readRequestBody(HttpRequest request) async {
    try {
      final completer = Completer<String>();
      final buffer = StringBuffer();

      request.listen(
            (data) {
          buffer.write(utf8.decode(data));
        },
        onDone: () {
          completer.complete(buffer.toString());
        },
        onError: (error) {
          completer.completeError(error);
        },
      );

      return await completer.future.timeout(const Duration(seconds: 30));
    } catch (e) {
      print('❌ Error reading request body: $e');
      rethrow;
    }
  }

  /// Send HTTP POST request
  Future<http.Response> _sendHttpPost({
    required String url,
    required Map<String, dynamic> data,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      print('📤 Sending POST to $url');
      print('📤 Data size: ${jsonEncode(data).length} bytes');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      ).timeout(timeout);

      print('📥 Response ${response.statusCode} from $url');
      if (response.statusCode != 200) {
        print('❌ Response body: ${response.body}');
      }

      return response;
    } catch (e) {
      print('❌ HTTP POST error to $url: $e');
      rethrow;
    }
  }

  /// Send SMS batch to receiver
  Future<bool> sendSMSBatch({
    required String receiverIP,
    required int receiverPort,
    required SMSBatch batch,
    required String sessionId,
  }) async {
    try {
      final url = 'http://$receiverIP:$receiverPort/sms-transfer';

      print('📤 Sending SMS batch ${batch.batchNumber}/${batch.totalBatches}');
      print('📊 Batch contains ${batch.messages.length} messages');

      final message = TransferMessage(
        type: MessageTypes.smsData,
        data: batch.toJson(),
        sessionId: sessionId,
        timestamp: DateTime.now(),
      );

      final response = await _sendHttpPost(
        url: url,
        data: message.toJson(),
        timeout: const Duration(seconds: 60), // Longer timeout for large batches
      );

      final success = response.statusCode == HttpStatus.ok;

      if (success) {
        print('✅ SMS batch ${batch.batchNumber} sent successfully');
      } else {
        print('❌ Failed to send SMS batch: HTTP ${response.statusCode}');
        print('❌ Response: ${response.body}');
      }

      return success;
    } catch (e) {
      print('❌ Error sending SMS batch: $e');
      return false;
    }
  }

  /// Send transfer request (notify receiver)
  Future<bool> sendTransferRequest({
    required String receiverIP,
    required int receiverPort,
    required String sessionId,
    required int totalMessages,
  }) async {
    try {
      final url = 'http://$receiverIP:$receiverPort/sms-transfer';

      print('📤 Sending transfer request for $totalMessages messages');

      final message = TransferMessage(
        type: MessageTypes.transferRequest,
        data: {
          'total_messages': totalMessages,
          'session_id': sessionId,
          'timestamp': DateTime.now().toIso8601String(),
        },
        sessionId: sessionId,
        timestamp: DateTime.now(),
      );

      final response = await _sendHttpPost(
        url: url,
        data: message.toJson(),
      );

      final success = response.statusCode == HttpStatus.ok;

      if (success) {
        print('✅ Transfer request sent successfully');
      } else {
        print('❌ Failed to send transfer request: HTTP ${response.statusCode}');
      }

      return success;
    } catch (e) {
      print('❌ Error sending transfer request: $e');
      return false;
    }
  }

  /// Send transfer completion message
  Future<bool> sendTransferComplete({
    required String receiverIP,
    required int receiverPort,
    required String sessionId,
    required int totalMessages,
  }) async {
    try {
      final url = 'http://$receiverIP:$receiverPort/sms-transfer';

      print('📤 Sending transfer complete notification');

      final message = TransferMessage(
        type: MessageTypes.transferComplete,
        data: {
          'total_messages': totalMessages,
          'completed_at': DateTime.now().toIso8601String(),
          'session_id': sessionId,
        },
        sessionId: sessionId,
        timestamp: DateTime.now(),
      );

      final response = await _sendHttpPost(
        url: url,
        data: message.toJson(),
      );

      final success = response.statusCode == HttpStatus.ok;

      if (success) {
        print('✅ Transfer complete notification sent');
      } else {
        print('❌ Failed to send transfer complete: HTTP ${response.statusCode}');
      }

      return success;
    } catch (e) {
      print('❌ Error sending transfer complete: $e');
      return false;
    }
  }

  /// Check if device is reachable
  Future<bool> isDeviceReachable(String ipAddress, int port) async {
    try {
      print('🔍 Checking reachability: $ipAddress:$port');

      // Try health check first
      final healthUrl = 'http://$ipAddress:$port/health';
      final response = await http.get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 10));

      final isReachable = response.statusCode == HttpStatus.ok;

      if (isReachable) {
        print('✅ Device is reachable (health check passed)');
        try {
          final healthData = jsonDecode(response.body);
          print('💗 Health status: ${healthData['status']}');
        } catch (e) {
          print('📄 Health response: ${response.body}');
        }
      } else {
        print('❌ Device not reachable: HTTP ${response.statusCode}');
      }

      return isReachable;
    } catch (e) {
      print('❌ Device not reachable: $e');
      return false;
    }
  }

  /// Send discovery request to specific device
  Future<DeviceInfo?> sendDiscoveryRequest({
    required String targetIP,
    required int targetPort,
    required String sessionId,
    required DeviceInfo deviceInfo,
  }) async {
    try {
      final url = 'http://$targetIP:$targetPort/discover';

      print('🔍 Sending discovery to $targetIP:$targetPort');

      final message = TransferMessage.discovery(deviceInfo, sessionId);
      final response = await _sendHttpPost(
        url: url,
        data: message.toJson(),
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == HttpStatus.ok) {
        final responseData = jsonDecode(response.body);
        final responseMessage = TransferMessage.fromJson(responseData);

        if (responseMessage.type == MessageTypes.discoveryResponse) {
          final discoveredDevice = DeviceInfo.fromJson(responseMessage.data);
          print('✅ Discovery successful: ${discoveredDevice.deviceName}');
          return discoveredDevice;
        }
      }

      print('❌ Discovery failed: HTTP ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Discovery error: $e');
      return null;
    }
  }

  /// Send error message
  Future<void> sendError({
    required String receiverIP,
    required int receiverPort,
    required String sessionId,
    required String errorMessage,
  }) async {
    try {
      final url = 'http://$receiverIP:$receiverPort/sms-transfer';

      final message = TransferMessage.error(errorMessage, sessionId);
      await _sendHttpPost(
        url: url,
        data: message.toJson(),
        timeout: const Duration(seconds: 10),
      );

      print('✅ Error message sent');
    } catch (e) {
      print('❌ Failed to send error message: $e');
    }
  }

  /// Get network status
  Future<ConnectionStatus> getNetworkStatus() async {
    try {
      final deviceIP = await getDeviceIP();
      if (deviceIP == null) {
        return ConnectionStatus.disconnected;
      }

      // Try to connect to Google DNS
      try {
        final socket = await Socket.connect('8.8.8.8', 53,
            timeout: const Duration(seconds: 5));
        await socket.close();
        print('✅ Network connectivity verified');
        return ConnectionStatus.connected;
      } catch (e) {
        print('❌ Network connectivity check failed: $e');
        return ConnectionStatus.error;
      }
    } catch (e) {
      print('❌ Network status error: $e');
      return ConnectionStatus.error;
    }
  }

  /// Dispose resources
  void dispose() {
    print('🧹 Disposing NetworkService...');
    stopServer();
    _messageController.close();
    _deviceDiscoveryController.close();
    print('✅ NetworkService disposed');
  }
}