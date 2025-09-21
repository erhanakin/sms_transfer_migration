import 'dart:convert';

class SMSMessage {
  final String id;
  final String address;
  final String body;
  final DateTime date;
  final bool isRead;
  final bool isSent;
  final String? threadId;
  final String type;

  SMSMessage({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.isRead,
    required this.isSent,
    this.threadId,
    required this.type,
  });

  factory SMSMessage.fromJson(Map<String, dynamic> json) {
    return SMSMessage(
      id: json['id']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(json['date']?.toString() ?? '0') ?? 0,
      ),
      isRead: json['read'] == 1 || json['read'] == true,
      isSent: json['type'] == 2 || json['type'] == '2',
      threadId: json['thread_id']?.toString(),
      type: _getMessageType(json['type']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'body': body,
      'date': date.millisecondsSinceEpoch,
      'read': isRead ? 1 : 0,
      'type': isSent ? 2 : 1,
      'thread_id': threadId,
      'message_type': type,
    };
  }

  Map<String, dynamic> toExportJson() {
    return {
      'id': id,
      'phone_number': address,
      'message': body,
      'date': date.toIso8601String(),
      'timestamp': date.millisecondsSinceEpoch,
      'is_read': isRead,
      'is_sent': isSent,
      'thread_id': threadId,
      'type': type,
      'formatted_date': _formatDate(),
    };
  }

  List<String> toCsvRow() {
    return [
      id,
      address,
      body.replaceAll('\n', '\\n').replaceAll('\r', '\\r'),
      _formatDate(),
      date.millisecondsSinceEpoch.toString(),
      isRead ? 'Read' : 'Unread',
      isSent ? 'Sent' : 'Received',
      threadId ?? '',
      type,
    ];
  }

  String toTextFormat() {
    final direction = isSent ? 'TO' : 'FROM';
    final status = isRead ? 'Read' : 'Unread';

    return '''
=====================================
$direction: $address
DATE: ${_formatDate()}
STATUS: $status
MESSAGE:
$body
=====================================
''';
  }

  static List<String> csvHeaders() {
    return [
      'ID',
      'Phone Number',
      'Message',
      'Date',
      'Timestamp',
      'Read Status',
      'Direction',
      'Thread ID',
      'Type',
    ];
  }

  String _formatDate() {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }

  static String _getMessageType(dynamic type) {
    switch (type?.toString()) {
      case '1':
        return 'Received';
      case '2':
        return 'Sent';
      case '3':
        return 'Draft';
      case '4':
        return 'Outbox';
      case '5':
        return 'Failed';
      case '6':
        return 'Queued';
      default:
        return 'Unknown';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SMSMessage &&
        other.id == id &&
        other.address == address &&
        other.body == body &&
        other.date == date;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    address.hashCode ^
    body.hashCode ^
    date.hashCode;
  }

  @override
  String toString() {
    return 'SMSMessage{id: $id, address: $address, body: ${body.substring(0, body.length > 50 ? 50 : body.length)}..., date: $date, isSent: $isSent}';
  }
}

class SMSBatch {
  final List<SMSMessage> messages;
  final int batchNumber;
  final int totalBatches;
  final String sessionId;

  SMSBatch({
    required this.messages,
    required this.batchNumber,
    required this.totalBatches,
    required this.sessionId,
  });

  factory SMSBatch.fromJson(Map<String, dynamic> json) {
    return SMSBatch(
      messages: (json['messages'] as List)
          .map((message) => SMSMessage.fromJson(message))
          .toList(),
      batchNumber: json['batch_number'] ?? 0,
      totalBatches: json['total_batches'] ?? 0,
      sessionId: json['session_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messages': messages.map((message) => message.toJson()).toList(),
      'batch_number': batchNumber,
      'total_batches': totalBatches,
      'session_id': sessionId,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }
}