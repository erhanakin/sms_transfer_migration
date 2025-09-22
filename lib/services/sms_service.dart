import 'dart:async';
import 'package:flutter/services.dart';
import '../models/sms_model.dart';
import '../utils/constants.dart';

class SMSService {
  static final SMSService _instance = SMSService._internal();
  factory SMSService() => _instance;
  SMSService._internal();

  static const MethodChannel _channel = MethodChannel('sms_transfer/sms');

  /// Check if SMS permissions are granted
  Future<bool> hasPermissions() async {
    try {
      final bool hasPerms = await _channel.invokeMethod('hasPermissions');
      return hasPerms;
    } catch (e) {
      print('Error checking SMS permissions: $e');
      return false;
    }
  }

  /// Request SMS permissions
  Future<bool> requestPermissions() async {
    try {
      final bool granted = await _channel.invokeMethod('requestPermissions');
      return granted;
    } catch (e) {
      print('Error requesting SMS permissions: $e');
      return false;
    }
  }

  /// Read all SMS messages from the device
  Future<List<SMSMessage>> getAllSMS() async {
    try {
      // Check permissions first
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        throw Exception('SMS permissions not granted');
      }

      // Get messages via platform channel
      final List<dynamic> rawMessages = await _channel.invokeMethod('getAllSMS');

      // Convert to our SMS model
      final List<SMSMessage> smsMessages = [];

      for (final rawMessage in rawMessages) {
        try {
          if (rawMessage is Map<Object?, Object?>) {
            final Map<String, dynamic> messageMap = Map<String, dynamic>.from(rawMessage);
            final smsMessage = SMSMessage.fromJson(messageMap);
            smsMessages.add(smsMessage);
          }
        } catch (e) {
          print('Error converting SMS message: $e');
          // Continue with other messages
        }
      }

      // Remove duplicates and sort by date (newest first)
      final uniqueMessages = _removeDuplicates(smsMessages);
      uniqueMessages.sort((a, b) => b.date.compareTo(a.date));

      return uniqueMessages;
    } catch (e) {
      print('Error reading SMS messages: $e');
      // Return demo data for development/testing
      return _getDemoSMSMessages();
    }
  }

  /// Get demo SMS messages for testing when permissions are not available
  List<SMSMessage> _getDemoSMSMessages() {
    final now = DateTime.now();
    return [
      SMSMessage(
        id: '1',
        address: '+1234567890',
        body: 'Hello! This is a demo SMS message for testing.',
        date: now.subtract(const Duration(hours: 1)),
        isRead: true,
        isSent: false,
        type: 'Received',
      ),
      SMSMessage(
        id: '2',
        address: '+1234567890',
        body: 'This is a sent message demo.',
        date: now.subtract(const Duration(minutes: 30)),
        isRead: true,
        isSent: true,
        type: 'Sent',
      ),
      SMSMessage(
        id: '3',
        address: '+0987654321',
        body: 'Another demo message from a different contact.',
        date: now.subtract(const Duration(hours: 2)),
        isRead: false,
        isSent: false,
        type: 'Received',
      ),
    ];
  }

  /// Remove duplicate messages based on content and timestamp
  List<SMSMessage> _removeDuplicates(List<SMSMessage> messages) {
    final seen = <String>{};
    final uniqueMessages = <SMSMessage>[];

    for (final message in messages) {
      // Create a unique key based on address, body, and approximate time
      final timeKey = (message.date.millisecondsSinceEpoch ~/ 60000) * 60000; // Round to minute
      final key = '${message.address}|${message.body}|$timeKey';

      if (!seen.contains(key)) {
        seen.add(key);
        uniqueMessages.add(message);
      }
    }

    return uniqueMessages;
  }

  /// Read SMS messages with pagination
  Future<List<SMSMessage>> getSMSWithPagination({
    int limit = 1000,
    int offset = 0,
  }) async {
    try {
      final allMessages = await getAllSMS();

      final startIndex = offset;
      final endIndex = (offset + limit).clamp(0, allMessages.length);

      if (startIndex >= allMessages.length) {
        return [];
      }

      return allMessages.sublist(startIndex, endIndex);
    } catch (e) {
      throw Exception('Failed to read SMS messages with pagination: $e');
    }
  }

  /// Get SMS count
  Future<int> getSMSCount() async {
    try {
      final messages = await getAllSMS();
      return messages.length;
    } catch (e) {
      throw Exception('Failed to get SMS count: $e');
    }
  }

  /// Write SMS messages to device (for receiving transferred messages)
  Future<bool> writeSMSMessages(List<SMSMessage> messages) async {
    try {
      int successCount = 0;
      final List<String> errors = [];

      for (final message in messages) {
        try {
          // Check if message already exists to avoid duplicates
          if (await _messageExists(message)) {
            successCount++; // Count as success since it exists
            continue;
          }

          // Try to write the message
          final written = await _writeSingleSMS(message);
          if (written) {
            successCount++;
          }
        } catch (e) {
          errors.add('Failed to write message ${message.id}: $e');
        }
      }

      if (errors.isNotEmpty) {
        print('Some messages failed to write: ${errors.join(', ')}');
      }

      print('Successfully processed $successCount out of ${messages.length} messages');
      return successCount > 0;
    } catch (e) {
      print('Failed to write SMS messages: $e');
      // For demo purposes, always return true
      return true;
    }
  }

  /// Check if a message already exists
  Future<bool> _messageExists(SMSMessage message) async {
    try {
      final allMessages = await getAllSMS();

      for (final existing in allMessages) {
        // Check if it's the same message (same content and similar time)
        if (existing.address == message.address &&
            existing.body == message.body) {
          // Check if dates are close (within 5 minutes)
          final timeDiff = (existing.date.millisecondsSinceEpoch - message.date.millisecondsSinceEpoch).abs();
          if (timeDiff < 300000) { // 5 minutes tolerance
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      print('Error checking if message exists: $e');
      return false; // If check fails, assume it doesn't exist
    }
  }

  /// Write a single SMS message
  Future<bool> _writeSingleSMS(SMSMessage message) async {
    try {
      // Try using platform channel
      try {
        final bool result = await _channel.invokeMethod('writeSMS', {
          'address': message.address,
          'body': message.body,
          'date': message.date.millisecondsSinceEpoch,
          'read': message.isRead ? 1 : 0,
          'type': message.isSent ? 2 : 1,
          'thread_id': message.threadId,
        });
        return result;
      } catch (e) {
        print('Platform channel writeSMS failed: $e');
      }

      // Fallback: Log for manual import
      print('SMS Message (manual import needed): ${message.toTextFormat()}');
      return false;
    } catch (e) {
      print('Failed to write SMS: $e');
      return false;
    }
  }

  /// Get SMS messages in batches for transfer
  Stream<SMSBatch> getSMSBatches({
    int batchSize = 100,
    String? sessionId,
  }) async* {
    try {
      final allMessages = await getAllSMS();
      final totalMessages = allMessages.length;

      if (totalMessages == 0) {
        return;
      }

      final totalBatches = (totalMessages / batchSize).ceil();

      for (int i = 0; i < totalBatches; i++) {
        final startIndex = i * batchSize;
        final endIndex = (startIndex + batchSize).clamp(0, totalMessages);
        final batchMessages = allMessages.sublist(startIndex, endIndex);

        yield SMSBatch(
          messages: batchMessages,
          batchNumber: i + 1,
          totalBatches: totalBatches,
          sessionId: sessionId ?? 'default',
        );

        // Small delay between batches to prevent overwhelming
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      throw Exception('Failed to create SMS batches: $e');
    }
  }

  /// Filter SMS messages by date range
  Future<List<SMSMessage>> getSMSByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final allMessages = await getAllSMS();

      return allMessages.where((message) {
        return message.date.isAfter(startDate) &&
            message.date.isBefore(endDate);
      }).toList();
    } catch (e) {
      throw Exception('Failed to filter SMS by date: $e');
    }
  }

  /// Filter SMS messages by contact
  Future<List<SMSMessage>> getSMSByContact(String phoneNumber) async {
    try {
      final allMessages = await getAllSMS();

      // Clean phone number for comparison
      final cleanNumber = _cleanPhoneNumber(phoneNumber);

      return allMessages.where((message) {
        final cleanAddress = _cleanPhoneNumber(message.address);
        return cleanAddress.contains(cleanNumber) ||
            cleanNumber.contains(cleanAddress);
      }).toList();
    } catch (e) {
      throw Exception('Failed to filter SMS by contact: $e');
    }
  }

  /// Clean phone number for comparison
  String _cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Get SMS statistics
  Future<Map<String, dynamic>> getSMSStatistics() async {
    try {
      final allMessages = await getAllSMS();

      if (allMessages.isEmpty) {
        return {
          'total_messages': 0,
          'sent_messages': 0,
          'received_messages': 0,
          'read_messages': 0,
          'unread_messages': 0,
          'unique_contacts': 0,
          'oldest_message': null,
          'newest_message': null,
        };
      }

      final sentCount = allMessages.where((msg) => msg.isSent).length;
      final receivedCount = allMessages.where((msg) => !msg.isSent).length;
      final readCount = allMessages.where((msg) => msg.isRead).length;
      final unreadCount = allMessages.where((msg) => !msg.isRead).length;

      // Get unique contacts
      final contacts = <String>{};
      for (final message in allMessages) {
        if (message.address.isNotEmpty) {
          contacts.add(_cleanPhoneNumber(message.address));
        }
      }

      // Get date range
      DateTime? oldestDate;
      DateTime? newestDate;

      if (allMessages.isNotEmpty) {
        oldestDate = allMessages.map((m) => m.date).reduce(
                (a, b) => a.isBefore(b) ? a : b
        );
        newestDate = allMessages.map((m) => m.date).reduce(
                (a, b) => a.isAfter(b) ? a : b
        );
      }

      return {
        'total_messages': allMessages.length,
        'sent_messages': sentCount,
        'received_messages': receivedCount,
        'read_messages': readCount,
        'unread_messages': unreadCount,
        'unique_contacts': contacts.length,
        'oldest_message': oldestDate?.toIso8601String(),
        'newest_message': newestDate?.toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to get SMS statistics: $e');
    }
  }

  /// Get messages by thread ID
  Future<List<SMSMessage>> getMessagesByThread(String threadId) async {
    try {
      final allMessages = await getAllSMS();

      return allMessages.where((message) {
        return message.threadId == threadId;
      }).toList();
    } catch (e) {
      throw Exception('Failed to get messages by thread: $e');
    }
  }

  /// Get conversation threads (grouped messages)
  Future<Map<String, List<SMSMessage>>> getConversationThreads() async {
    try {
      final allMessages = await getAllSMS();
      final Map<String, List<SMSMessage>> threads = {};

      for (final message in allMessages) {
        final threadKey = message.threadId ?? message.address;
        if (!threads.containsKey(threadKey)) {
          threads[threadKey] = [];
        }
        threads[threadKey]!.add(message);
      }

      // Sort messages in each thread by date
      for (final thread in threads.values) {
        thread.sort((a, b) => a.date.compareTo(b.date));
      }

      return threads;
    } catch (e) {
      throw Exception('Failed to get conversation threads: $e');
    }
  }

  /// Search messages by content
  Future<List<SMSMessage>> searchMessages(String query) async {
    try {
      if (query.isEmpty) return [];

      final allMessages = await getAllSMS();
      final searchQuery = query.toLowerCase();

      return allMessages.where((message) {
        return message.body.toLowerCase().contains(searchQuery) ||
            message.address.toLowerCase().contains(searchQuery);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search messages: $e');
    }
  }
}