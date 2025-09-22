import 'dart:convert';
import '../utils/constants.dart';
import '../utils/file_utils.dart';

class ExportedFileInfo {
  final String name;
  final String path;
  final int size;
  final DateTime createdAt;
  final ExportFormat format;

  ExportedFileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.createdAt,
    required this.format,
  });

  factory ExportedFileInfo.fromJson(Map<String, dynamic> json) {
    return ExportedFileInfo(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      size: json['size'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      format: ExportFormat.values.firstWhere(
            (f) => f.name == json['format'],
        orElse: () => ExportFormat.txt,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'size': size,
      'created_at': createdAt.toIso8601String(),
      'format': format.name,
    };
  }

  String get formattedSize => FileUtils.formatFileSize(size);
  String get formattedDate => FileUtils.formatDate(createdAt);

  @override
  String toString() {
    return 'ExportedFileInfo{name: $name, size: $formattedSize, format: ${format.name}}';
  }
}

class ExportProgress {
  final int current;
  final int total;
  final String status;
  final String? filePath;
  final bool hasError;

  ExportProgress({
    required this.current,
    required this.total,
    required this.status,
    this.filePath,
    this.hasError = false,
  });

  factory ExportProgress.fromJson(Map<String, dynamic> json) {
    return ExportProgress(
      current: json['current'] ?? 0,
      total: json['total'] ?? 0,
      status: json['status'] ?? '',
      filePath: json['file_path'],
      hasError: json['has_error'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current': current,
      'total': total,
      'status': status,
      'file_path': filePath,
      'has_error': hasError,
    };
  }

  double get progress {
    if (total == 0) return 0.0;
    return (current / total).clamp(0.0, 1.0);
  }

  String get progressPercentage {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  bool get isCompleted => current >= total && !hasError;

  ExportProgress copyWith({
    int? current,
    int? total,
    String? status,
    String? filePath,
    bool? hasError,
  }) {
    return ExportProgress(
      current: current ?? this.current,
      total: total ?? this.total,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      hasError: hasError ?? this.hasError,
    );
  }

  @override
  String toString() {
    return 'ExportProgress{current: $current, total: $total, status: $status, progress: $progressPercentage}';
  }
}

/// File information model (moved from file_utils.dart for better organization)
class FileInfo {
  final String name;
  final String path;
  final int size;
  final DateTime createdAt;
  final ExportFormat format;

  FileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.createdAt,
    required this.format,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      size: json['size'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      format: ExportFormat.values.firstWhere(
            (f) => f.name == json['format'],
        orElse: () => ExportFormat.txt,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'size': size,
      'created_at': createdAt.toIso8601String(),
      'format': format.name,
    };
  }

  String get extension => FileUtils.getFileExtension(path);
  String get nameWithoutExtension => FileUtils.getFileNameWithoutExtension(path);
  String get formattedSize => FileUtils.formatFileSize(size);
  String get formattedDate => FileUtils.formatDate(createdAt);

  @override
  String toString() {
    return 'FileInfo{name: $name, size: $formattedSize, created: $formattedDate}';
  }
}