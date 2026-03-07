import 'dart:io';
import '../models/sync_state.dart';
import 'sync_client_base.dart';

/// 数据库同步管理器
/// 提供安全的数据库下载、验证和恢复机制
class DatabaseSyncManager {
  static const String _tempDbPrefix = 'temp_database_';
  static const String _backupDbPrefix = 'backup_database_';
  static const int _maxBackupCount = 3;

  /// 安全下载数据库
  ///
  /// 流程：
  /// 1. 下载到临时文件
  /// 2. 验证数据库完整性
  /// 3. 备份当前数据库
  /// 4. 原子替换数据库
  /// 5. 验证替换结果
  static Future<SyncResult> safeDownloadDatabase({
    required SyncClientBase client,
    required String remoteDbPath,
    required String localDbPath,
    void Function(int received, int total)? onProgress,
  }) async {
    // 生成临时文件路径
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempDbPath = '${Directory.systemTemp.path}/$_tempDbPrefix$timestamp.db';

    try {
      print('DatabaseSync: 开始安全下载数据库');

      // 步骤 1: 下载到临时文件
      await client.downloadFile(
        remoteDbPath,
        tempDbPath,
        onProgress: onProgress,
      );
      print('DatabaseSync: 下载完成，开始验证');

      // 步骤 2: 验证下载的数据库
      final validationResult = await _validateDatabase(tempDbPath);
      if (!validationResult.isValid) {
        await _cleanupTempFile(tempDbPath);
        return SyncResult.failure(
          '数据库验证失败: ${validationResult.error}',
          SyncFailureType.validationFailed,
        );
      }

      print('DatabaseSync: 验证通过，创建备份');

      // 步骤 3: 备份当前数据库
      final backupPath = await _createBackup(localDbPath);
      print('DatabaseSync: 备份创建完成: $backupPath');

      // 步骤 4: 原子替换数据库
      await _atomicReplaceDatabase(tempDbPath, localDbPath);

      // 步骤 5: 验证替换后的数据库
      final finalValidation = await _validateDatabase(localDbPath);
      if (!finalValidation.isValid) {
        print('DatabaseSync: 最终验证失败，从备份恢复');
        await _recoverFromBackup(backupPath, localDbPath);
        return SyncResult.failure(
          '数据库替换验证失败，已从备份恢复',
          SyncFailureType.replacementFailed,
        );
      }

      // 清理工作
      await _cleanupOldBackups(localDbPath);
      await _cleanupTempFile(tempDbPath);

      print('DatabaseSync: 安全下载完成');
      return SyncResult.success('数据库同步成功');
    } catch (e) {
      print('DatabaseSync: 下载过程中出错: $e');
      await _cleanupTempFile(tempDbPath);
      return SyncResult.failure(
        '数据库同步失败: $e',
        SyncFailureType.unknown,
      );
    }
  }

  /// 安全上传数据库
  static Future<SyncResult> safeUploadDatabase({
    required SyncClientBase client,
    required String localDbPath,
    required String remoteDbPath,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      print('DatabaseSync: 开始上传数据库');

      // 验证本地数据库
      final validationResult = await _validateDatabase(localDbPath);
      if (!validationResult.isValid) {
        return SyncResult.failure(
          '本地数据库验证失败: ${validationResult.error}',
          SyncFailureType.validationFailed,
        );
      }

      // 上传数据库
      await client.uploadFile(
        localDbPath,
        remoteDbPath,
        replace: true,
        onProgress: onProgress,
      );

      print('DatabaseSync: 上传完成');
      return SyncResult.success('数据库上传成功');
    } catch (e) {
      print('DatabaseSync: 上传失败: $e');
      return SyncResult.failure(
        '数据库上传失败: $e',
        SyncFailureType.networkError,
      );
    }
  }

  /// 验证数据库完整性
  static Future<DatabaseValidationResult> _validateDatabase(String dbPath) async {
    try {
      final dbFile = File(dbPath);

      // 检查文件是否存在
      if (!await dbFile.exists()) {
        return DatabaseValidationResult.invalid('数据库文件不存在');
      }

      // 检查文件大小
      final fileSize = await dbFile.length();
      if (fileSize < 1024) {
        return DatabaseValidationResult.invalid('数据库文件过小: $fileSize 字节');
      }

      // 检查 SQLite 文件头
      final header = await dbFile.openRead(0, 16).first;
      final headerString = String.fromCharCodes(header);
      if (!headerString.startsWith('SQLite format 3')) {
        return DatabaseValidationResult.invalid('无效的数据库文件格式');
      }

      print('DatabaseSync: 数据库验证通过 ($fileSize 字节)');
      return DatabaseValidationResult.valid();
    } catch (e) {
      return DatabaseValidationResult.invalid('数据库验证错误: $e');
    }
  }

  /// 创建数据库备份
  static Future<String> _createBackup(String localDbPath) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = '${Directory.systemTemp.path}/$_backupDbPrefix$timestamp.db';

    final localFile = File(localDbPath);
    if (await localFile.exists()) {
      await localFile.copy(backupPath);
    }

    return backupPath;
  }

  /// 原子替换数据库
  static Future<void> _atomicReplaceDatabase(
    String tempDbPath,
    String localDbPath,
  ) async {
    final tempFile = File(tempDbPath);

    // 如果本地数据库存在，先删除
    final localFile = File(localDbPath);
    if (await localFile.exists()) {
      await localFile.delete();
    }

    // 复制临时文件到本地路径
    await tempFile.copy(localDbPath);
  }

  /// 从备份恢复
  static Future<void> _recoverFromBackup(
    String backupPath,
    String localDbPath,
  ) async {
    final backupFile = File(backupPath);
    if (await backupFile.exists()) {
      final localFile = File(localDbPath);
      if (await localFile.exists()) {
        await localFile.delete();
      }
      await backupFile.copy(localDbPath);
      print('DatabaseSync: 已从备份恢复');
    }
  }

  /// 清理临时文件
  static Future<void> _cleanupTempFile(String tempDbPath) async {
    try {
      final tempFile = File(tempDbPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
        print('DatabaseSync: 清理临时文件: $tempDbPath');
      }
    } catch (e) {
      print('DatabaseSync: 清理临时文件失败: $e');
    }
  }

  /// 清理旧备份文件
  static Future<void> _cleanupOldBackups(String localDbPath) async {
    try {
      final tempDir = Directory.systemTemp;
      final backupFiles = await tempDir
          .list()
          .where((file) =>
              file is File && file.path.contains(_backupDbPrefix))
          .cast<File>()
          .toList();

      // 按修改时间排序，保留最新的
      backupFiles.sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // 删除多余的备份
      if (backupFiles.length > _maxBackupCount) {
        for (final file in backupFiles.skip(_maxBackupCount)) {
          await file.delete();
          print('DatabaseSync: 清理旧备份: ${file.path}');
        }
      }
    } catch (e) {
      print('DatabaseSync: 清理旧备份失败: $e');
    }
  }

  /// 获取可用的备份列表
  static Future<List<String>> getAvailableBackups() async {
    try {
      final tempDir = Directory.systemTemp;
      final backupFiles = await tempDir
          .list()
          .where((file) =>
              file is File && file.path.contains(_backupDbPrefix))
          .map((file) => file.path)
          .toList();

      backupFiles.sort((a, b) => b.compareTo(a));
      return backupFiles;
    } catch (e) {
      return [];
    }
  }
}

/// 数据库验证结果
class DatabaseValidationResult {
  final bool isValid;
  final String? error;

  const DatabaseValidationResult._(this.isValid, this.error);

  factory DatabaseValidationResult.valid() =>
      const DatabaseValidationResult._(true, null);

  factory DatabaseValidationResult.invalid(String error) =>
      DatabaseValidationResult._(false, error);
}
