import 'dart:async';
import 'package:telephony/telephony.dart';
import 'package:flutter/services.dart';
import '../models/sms_model.dart';
import '../utils/constants.dart';

class SMSService {
  static final SMSService _instance = SMSService._internal();
  factory SMSService() => _instance;
  SMSService._internal();

  final Telephony _telephony = Telephony.instance;

  /// Read all SMS messages from the device
  Future<List<SMSMessage>> getAllSMS() async {
    try {
      final List<SmsMessage> messages = await _telephony.getInboxSms(
        columns: [
          SmsColumn.ID,
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.READ,
          SmsColumn.TYPE,
          SmsColumn.THREAD_ID,
        ],
        sortOrder: [
          OrderBy(SmsColumn.DATE, sort: Sort.DESC),
        ],
      );

      final List<SmsMessage> sentMessages = await _telephony.getSentSms(
        columns: [
          SmsColumn.ID,
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.READ,
          SmsColumn.TYPE,
          SmsColumn.THREAD_ID,
        ],
        sortOrder: [
          OrderBy(SmsColumn.DATE, sort: Sort.DESC),
        ],
      );

      // Combine inbox and sent messages
      final allMessages = [...messages, ...sentMessages];

      // Convert to our SMS model
      final List<SMSMessage> smsMessages = allMessages.map((sms) {
        return SMSMessage.fromJson({
          'id': sms.id,
          'address': sms.address,
          'body': sms.body,
          'date': sms.date,
          'read': sms.isRead ? 1 : 0,
          'type': sms.type?.index ?? 1,
          'thread_id': sms.threadId,
        });
      }).toList();

      // Sort by date (newest first)
      smsMessages.sort((a, b) => b.date.compareTo(a.date));

      return smsMessages;
    } catch (e) {
      throw Exception('Failed to read SMS messages: $e');
    }
  }

  /// Read SMS messages with pagination
  Future<List<SMSMessage>> getSMSWithPagination({
    int limit = 1000,
    int offset = 0,
  }) async {
    try {
      final List<SmsMessage> messages = await _telephony.getInboxSms(
        columns: [
          SmsColumn.ID,
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.READ,
          SmsColumn.TYPE,
          SmsColumn.THREAD_ID,
        ],
        sortOrder: [
          OrderBy(SmsColumn.DATE, sort: Sort.DESC),
        ],
      );

      final List<SmsMessage> sentMessages = await _telephony.getSentSms(
        columns: [
          SmsColumn.ID,
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.READ,
          SmsColumn.TYPE,
          SmsColumn.THREAD_ID,
        ],
        sortOrder: [
          OrderBy(SmsColumn.DATE, sort: Sort.DESC),
        ],
      );

      final allMessages = [...messages, ...sentMessages];

      // Apply pagination
      final startIndex = offset;
      final endIndex = (offset + limit).clamp(0, allMessages.length);
      final paginatedMessages = allMessages.sublist(startIndex, endIndex);

      return paginatedMessages.map((sms) {
        return SMSMessage.fromJson({
          'id': sms.id,
          'address': sms.address,
          'body': sms.body,
          'date': sms.date,
          'read': sms.isRead ? 1 : 0,
          'type': sms.type?.index ?? 1,
          'thread_id': sms.threadId,
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to read SMS messages: $e');
    }
  }

  /// Get SMS count
  Future<int> getSMSCount() async {
    try {
      final inboxMessages = await _telephony.getInboxSms();
      final sentMessages = await _telephony.getSentSms();
      return inboxMessages.length + sentMessages.length;
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
            continue; // Skip existing messages
          }

          // Write the message
          await _writeSingleSMS(message);
          successCount++;
        } catch (e) {
          errors.add('Failed to write message ${message.id}: $e');
        }
      }

      if (errors.isNotEmpty) {
        print('Some messages failed to write: ${errors.join(', ')}');
      }

      return successCount > 0;
    } catch (e) {
      throw Exception('Failed to write SMS messages: $e');
    }
  }

  /// Check if a message already exists
  Future<bool> _messageExists(SMSMessage message) async {
    try {
      // Check by address, body, and date (within 1 minute tolerance)
      final existingMessages = await _telephony.getInboxSms(
        filter: SmsFilter.where(SmsColumn.ADDRESS).equals(message.address),
      );

      final sentMessages = await _telephony.getSentSms(
        filter: SmsFilter.where(SmsColumn.ADDRESS).equals(message.address),
      );

      final allExisting = [...existingMessages, ...sentMessages];

      for (final existing in allExisting) {
        if (existing.body == message.body) {
          // Check if dates are close (within 1 minute)
          final timeDiff = (existing.date! - message.date.millisecondsSinceEpoch).abs();
          if (timeDiff < 60000) { // 60 seconds tolerance
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      return false; // If check fails, assume it doesn't exist
    }
  }

  /// Write a single SMS message
  Future<void> _writeSingleSMS(SMSMessage message) async {
    try {
      // Use platform channel to write SMS as telephony package might not support writing
      const platform = MethodChannel('sms_transfer/sms_writer');

      await platform.invokeMethod('writeSMS', {
        'address': message.address,
        'body': message.body,
        'date': message.date.millisecondsSinceEpoch,
        'read': message.isRead ? 1 : 0,
        'type': message.isSent ? 2 : 1,
        'thread_id': message.threadId,
      });
    } catch (e) {
      // Fallback: Log the message for manual import
      print('Failed to write SMS directly: $e');
      throw Exception('SMS writing not supported on this device');
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
        await Future.delayed(const Duration(milliseconds: 100));
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

      return allMessages.where((message) {
        return message.address.contains(phoneNumber) ||
            phoneNumber.contains(message.address);
      }).toList();
    } catch (e) {
      throw Exception('Failed to filter SMS by contact: $e');
    }
  }

  /// Get SMS statistics
  Future<Map<String, dynamic>> getSMSStatistics() async {
    try {
      final allMessages = await getAllSMS();

      final sentCount = allMessages.where((msg) => msg.isSent).length;
      final receivedCount = allMessages.where((msg) => !msg.isSent).length;
      final readCount = allMessages.where((msg) => msg.isRead).length;
      final unreadCount = allMessages.where((msg) => !msg.isRead).length;

      final contacts = <String>{};
      for (final message in allMessages) {
        contacts.add(message.address);
      }

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
}