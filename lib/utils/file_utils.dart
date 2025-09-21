import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class FileUtils {
  /// Format file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Format date in readable format
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  /// Get file extension from path
  static String getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }

  /// Get file name without extension
  static String getFileNameWithoutExtension(String filePath) {
    final fileName = filePath.split('/').last;
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex != -1) {
      return fileName.substring(0, lastDotIndex);
    }
    return fileName;
  }

  /// Check if file exists
  static Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// Create directory if it doesn't exist
  static Future<Directory> ensureDirectoryExists(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Get app documents directory
  static Future<Directory> getAppDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get app cache directory
  static Future<Directory> getAppCacheDirectory() async {
    return await getTemporaryDirectory();
  }

  /// Get external storage directory (Android)
  static Future<Directory?> getExternalStorageDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory();
    }
    return null;
  }

  /// Copy file to new location
  static Future<File> copyFile(String sourcePath, String destinationPath) async {
    final sourceFile = File(sourcePath);
    final destinationFile = File(destinationPath);

    // Ensure destination directory exists
    final destinationDir = Directory(destinationFile.parent.path);
    if (!await destinationDir.exists()) {
      await destinationDir.create(recursive: true);
    }

    return await sourceFile.copy(destinationPath);
  }

  /// Move file to new location
  static Future<File> moveFile(String sourcePath, String destinationPath) async {
    await copyFile(sourcePath, destinationPath);
    await File(sourcePath).delete();
    return File(destinationPath);
  }

  /// Delete file
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Read file as string
  static Future<String> readFileAsString(String filePath) async {
    final file = File(filePath);
    return await file.readAsString();
  }

  /// Read file as bytes
  static Future<Uint8List> readFileAsBytes(String filePath) async {
    final file = File(filePath);
    return await file.readAsBytes();
  }

  /// Write string to file
  static Future<File> writeStringToFile(String filePath, String content) async {
    final file = File(filePath);

    // Ensure directory exists
    final directory = Directory(file.parent.path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return await file.writeAsString(content);
  }

  /// Write bytes to file
  static Future<File> writeBytesToFile(String filePath, Uint8List bytes) async {
    final file = File(filePath);

    // Ensure directory exists
    final directory = Directory(file.parent.path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return await file.writeAsBytes(bytes);
  }

  /// Get file info
  static Future<FileInfo> getFileInfo(String filePath) async {
    final file = File(filePath);
    final stat = await file.stat();
    final fileName = filePath.split('/').last;

    return FileInfo(
      name: fileName,
      path: filePath,
      size: stat.size,
      created: stat.changed,
      modified: stat.modified,
      isDirectory: stat.type == FileSystemEntityType.directory,
    );
  }

  /// List files in directory
  static Future<List<FileInfo>> listFilesInDirectory(
      String directoryPath, {
        String? extension,
        bool recursive = false,
      }) async {
    final directory = Directory(directoryPath);
    final List<FileInfo> files = [];

    if (!await directory.exists()) {
      return files;
    }

    await for (final entity in directory.list(recursive: recursive)) {
      if (entity is File) {
        final fileInfo = await getFileInfo(entity.path);

        if (extension == null || fileInfo.name.toLowerCase().endsWith('.$extension')) {
          files.add(fileInfo);
        }
      }
    }

    return files;
  }

  /// Get directory size
  static Future<int> getDirectorySize(String directoryPath) async {
    final directory = Directory(directoryPath);
    int totalSize = 0;

    if (!await directory.exists()) {
      return totalSize;
    }

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        totalSize += stat.size;
      }
    }

    return totalSize;
  }

  /// Clean up old files
  static Future<int> cleanupOldFiles(
      String directoryPath, {
        Duration maxAge = const Duration(days: 30),
      }) async {
    final directory = Directory(directoryPath);
    int deletedCount = 0;

    if (!await directory.exists()) {
      return deletedCount;
    }

    final cutoffDate = DateTime.now().subtract(maxAge);

    await for (final entity in directory.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        if (stat.changed.isBefore(cutoffDate)) {
          try {
            await entity.delete();
            deletedCount++;
          } catch (e) {
            // Ignore errors when deleting individual files
          }
        }
      }
    }

    return deletedCount;
  }

  /// Validate file path
  static bool isValidFilePath(String filePath) {
    try {
      File(filePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sanitize file name
  static String sanitizeFileName(String fileName) {
    // Remove invalid characters for file names
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    return fileName.replaceAll(invalidChars, '_');
  }

  /// Generate unique file name
  static String generateUniqueFileName(String baseName, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${baseName}_$timestamp.$extension';
  }

  /// Check available storage space
  static Future<int> getAvailableStorageSpace() async {
    try {
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final stat = await directory.stat();
          return stat.size;
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final stat = await directory.stat();
      return stat.size;
    } catch (e) {
      return 0;
    }
  }
}

/// File information model
class FileInfo {
  final String name;
  final String path;
  final int size;
  final DateTime created;
  final DateTime modified;
  final bool isDirectory;

  FileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.created,
    required this.modified,
    required this.isDirectory,
  });

  String get extension => FileUtils.getFileExtension(path);
  String get nameWithoutExtension => FileUtils.getFileNameWithoutExtension(path);
  String get formattedSize => FileUtils.formatFileSize(size);
  String get formattedCreated => FileUtils.formatDate(created);
  String get formattedModified => FileUtils.formatDate(modified);

  @override
  String toString() {
    return 'FileInfo{name: $name, size: $formattedSize, created: $formattedCreated}';
  }
}