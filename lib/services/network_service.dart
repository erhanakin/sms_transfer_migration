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
  Timer? _discoveryTimer;
  final StreamController<TransferMessage> _messageController = StreamController.broadcast();
  final StreamController<DeviceInfo> _deviceDiscoveryController = StreamController.broadcast();

  Stream<TransferMessage> get messageStream => _messageController.stream;
  Stream<DeviceInfo> get deviceDiscoveryStream => _deviceDiscoveryController.stream;

  /// Get device IP address
  Future<String?> getDeviceIP() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      return wifiIP;
    } catch (e) {
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

      return {
        'wifi_name': wifiName,
        'wifi_ip': wifiIP,
        'wifi_bssid': wifiBSSID,
      };
    } catch (e) {
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

      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);

      _server!.listen((HttpRequest request) async {
        await _handleRequest(request, sessionId, deviceInfo);
      });

      print('Server started on port $port');
      return true;
    } catch (e) {
      print('Failed to start server: $e');
      return false;
    }
  }

  /// Stop HTTP server
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      print('Server stopped');
    }
  }

  /// Handle incoming HTTP requests
  Future<void> _handleRequest(
      HttpRequest request,
      String sessionId,
      DeviceInfo deviceInfo,
      ) async {
    try {
      // Set CORS headers
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final uri = request.uri;

      switch (uri.path) {
        case AppConstants.discoveryEndpoint:
          await _handleDiscoveryRequest(request, sessionId, deviceInfo);
          break;
        case AppConstants.transferEndpoint:
          await _handleTransferRequest(request, sessionId);
          break;
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
      }
    } catch (e) {
      print('Error handling request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  /// Handle device discovery requests
  Future<void> _handleDiscoveryRequest(
      HttpRequest request,
      String sessionId,
      DeviceInfo deviceInfo,
      ) async {
    try {
      if (request.method == 'GET') {
        // Respond to discovery request
        final response = TransferMessage.discoveryResponse(deviceInfo, sessionId);

        request.response.headers.contentType = ContentType.json;
        request.response.write(response.toJsonString());
        await request.response.close();

        print('Responded to discovery request');
      } else if (request.method == 'POST') {
        // Handle discovery message
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body);
        final message = TransferMessage.fromJson(data);

        if (message.type == MessageTypes.discovery) {
          final discoveredDevice = DeviceInfo.fromJson(message.data);
          _deviceDiscoveryController.add(discoveredDevice);

          // Send response
          final response = TransferMessage.discoveryResponse(deviceInfo, sessionId);
          request.response.headers.contentType = ContentType.json;
          request.response.write(response.toJsonString());
          await request.response.close();
        }
      }
    } catch (e) {
      print('Error handling discovery request: $e');
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
    }
  }

  /// Handle SMS transfer requests
  Future<void> _handleTransferRequest(
      HttpRequest request,
      String sessionId,
      ) async {
    try {
      if (request.method == 'POST') {
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body);
        final message = TransferMessage.fromJson(data);

        _messageController.add(message);

        // Send acknowledgment
        final response = {
          'status': 'received',
          'session_id': sessionId,
          'timestamp': DateTime.now().toIso8601String(),
        };

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();

        print('Received transfer message: ${message.type}');
      }
    } catch (e) {
      print('Error handling transfer request: $e');
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
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
      final url = 'http://$receiverIP:$receiverPort${AppConstants.transferEndpoint}';

      final message = TransferMessage(
        type: MessageTypes.smsData,
        data: batch.toJson(),
        sessionId: sessionId,
        timestamp: DateTime.now(),
      );

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: message.toJsonString(),
      ).timeout(AppConstants.networkTimeout);

      return response.statusCode == HttpStatus.ok;
    } catch (e) {
      print('Failed to send SMS batch: $e');
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
      final url = 'http://$receiverIP:$receiverPort${AppConstants.transferEndpoint}';

      final message = TransferMessage(
        type: MessageTypes.transferComplete,
        data: {
          'total_messages': totalMessages,
          'completed_at': DateTime.now().toIso8601String(),
        },
        sessionId: sessionId,
        timestamp: DateTime.now(),
      );

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: message.toJsonString(),
      ).timeout(AppConstants.networkTimeout);

      return response.statusCode == HttpStatus.ok;
    } catch (e) {
      print('Failed to send transfer complete: $e');
      return false;
    }
  }

  /// Discover devices on the network
  Future<List<DeviceInfo>> discoverDevices({
    required String sessionId,
    required DeviceInfo deviceInfo,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final List<DeviceInfo> discoveredDevices = [];
      final deviceIP = await getDeviceIP();

      if (deviceIP == null) {
        throw Exception('Could not get device IP');
      }

      // Extract network prefix (e.g., "192.168.1.")
      final ipParts = deviceIP.split('.');
      if (ipParts.length != 4) {
        throw Exception('Invalid IP format');
      }

      final networkPrefix = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}';

      // Start listening for responses
      final responseSubscription = deviceDiscoveryStream.listen((device) {
        if (!discoveredDevices.any((d) => d.deviceId == device.deviceId)) {
          discoveredDevices.add(device);
        }
      });

      // Send discovery requests to all possible IPs in the network
      final List<Future> requests = [];

      for (int i = 1; i <= 254; i++) {
        final targetIP = '$networkPrefix.$i';
        if (targetIP != deviceIP) {
          requests.add(_sendDiscoveryRequest(targetIP, sessionId, deviceInfo));
        }
      }

      // Wait for timeout or all requests to complete
      await Future.wait([
        Future.delayed(timeout),
        Future.wait(requests),
      ]);

      await responseSubscription.cancel();

      return discoveredDevices;
    } catch (e) {
      print('Failed to discover devices: $e');
      return [];
    }
  }

  /// Send discovery request to a specific IP
  Future<void> _sendDiscoveryRequest(
      String targetIP,
      String sessionId,
      DeviceInfo deviceInfo,
      ) async {
    try {
      final url = 'http://$targetIP:${AppConstants.transferPort}${AppConstants.discoveryEndpoint}';

      final message = TransferMessage.discovery(deviceInfo, sessionId);

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: message.toJsonString(),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == HttpStatus.ok) {
        final responseData = jsonDecode(response.body);
        final responseMessage = TransferMessage.fromJson(responseData);

        if (responseMessage.type == MessageTypes.discoveryResponse) {
          final discoveredDevice = DeviceInfo.fromJson(responseMessage.data);
          _deviceDiscoveryController.add(discoveredDevice);
        }
      }
    } catch (e) {
      // Ignore individual request failures
    }
  }

  /// Check if device is reachable
  Future<bool> isDeviceReachable(String ipAddress, int port) async {
    try {
      final url = 'http://$ipAddress:$port${AppConstants.discoveryEndpoint}';

      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == HttpStatus.ok;
    } catch (e) {
      return false;
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
      final url = 'http://$receiverIP:$receiverPort${AppConstants.transferEndpoint}';

      final message = TransferMessage.error(errorMessage, sessionId);

      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: message.toJsonString(),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('Failed to send error message: $e');
    }
  }

  /// Get network status
  Future<ConnectionStatus> getNetworkStatus() async {
    try {
      final deviceIP = await getDeviceIP();
      if (deviceIP == null) {
        return ConnectionStatus.disconnected;
      }

      // Try to connect to a known server (like Google DNS)
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 5));
      await socket.close();

      return ConnectionStatus.connected;
    } catch (e) {
      return ConnectionStatus.error;
    }
  }

  /// Dispose resources
  void dispose() {
    _discoveryTimer?.cancel();
    stopServer();
    _messageController.close();
    _deviceDiscoveryController.close();
  }
}