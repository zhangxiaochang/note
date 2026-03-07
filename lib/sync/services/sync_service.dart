import 'dart:io';
import '../models/remote_file.dart';
import '../models/sync_state.dart';
import 'database_sync_manager.dart';
import 'sync_client_base.dart';

/// 同步服务
/// 协调整个同步流程，处理冲突解决
class SyncService {
  final SyncClientBase _client;
  final String _dbName = 'app_database.db';

  SyncService(this._client);

  /// 检查是否应该同步
  Future<bool> shouldSync() async {
    // 检查是否配置了同步
    if (!_client.isConfigured) {
      print('Sync: 客户端未配置');
      return false;
    }

    // 实际项目中还需要检查：
    // - 网络连接状态
    // - 是否只在 WiFi 下同步的设置
    // - 自动同步开关

    return true;
  }

  /// 执行同步
  Future<SyncResult> sync(SyncDirection direction) async {
    try {
      print('Sync: 开始同步流程');

      // 1. 检查是否应该同步
      if (!await shouldSync()) {
        return SyncResult.success('无需同步');
      }

      // 2. 测试连接
      print('Sync: 测试服务器连接...');
      await _client.ping();
      print('Sync: 连接成功');

      // 3. 创建远程目录结构
      await _createRemoteDirs();

      // 4. 确定同步方向
      final finalDirection = await _determineSyncDirection(direction);
      if (finalDirection == null) {
        print('Sync: 用户取消或无需同步');
        return SyncResult.success('同步已取消');
      }

      print('Sync: 同步方向: $finalDirection');

      // 5. 同步数据库
      final dbResult = await _syncDatabase(finalDirection);
      if (!dbResult.isSuccess) {
        return dbResult;
      }

      // 6. 同步文件（书籍、封面等）
      await _syncFiles();

      print('Sync: 同步完成');
      return SyncResult.success('同步成功完成');
    } catch (e) {
      print('Sync: 同步失败: $e');
      return SyncResult.failure(
        '同步失败: $e',
        SyncFailureType.networkError,
      );
    }
  }

  /// 创建远程目录结构
  Future<void> _createRemoteDirs() async {
    await _client.mkdirAll('sync_demo/data/files');
    await _client.mkdirAll('sync_demo/data/covers');
    print('Sync: 远程目录结构创建完成');
  }

  /// 确定同步方向
  Future<SyncDirection?> _determineSyncDirection(
    SyncDirection requestedDirection,
  ) async {
    final localDbPath = await _getLocalDbPath();
    final remoteDbPath = 'sync_demo/data/$_dbName';

    // 获取远程数据库信息
    final remoteFile = await _client.readProps(remoteDbPath);
    final localFile = File(localDbPath);

    // 如果远程数据库不存在，直接上传
    if (remoteFile == null) {
      print('Sync: 远程数据库不存在，将上传');
      return SyncDirection.upload;
    }

    // 如果本地数据库不存在，直接下载
    if (!await localFile.exists()) {
      print('Sync: 本地数据库不存在，将下载');
      return SyncDirection.download;
    }

    // 获取文件修改时间
    final localModTime = await localFile.lastModified();
    final remoteModTime = remoteFile.mTime!;

    print('Sync: 本地修改时间: $localModTime');
    print('Sync: 远程修改时间: $remoteModTime');

    // 如果时间差小于 5 秒，认为没有冲突
    final diff = localModTime.difference(remoteModTime).inSeconds.abs();
    if (diff < 5) {
      print('Sync: 文件时间差小于 5 秒，无需同步');
      return null;
    }

    // 如果请求双向同步，需要解决冲突
    if (requestedDirection == SyncDirection.both) {
      // 实际项目中这里应该弹出对话框让用户选择
      // 简化版本：选择较新的版本
      if (localModTime.isAfter(remoteModTime)) {
        print('Sync: 本地版本较新，将上传');
        return SyncDirection.upload;
      } else {
        print('Sync: 远程版本较新，将下载');
        return SyncDirection.download;
      }
    }

    return requestedDirection;
  }

  /// 同步数据库
  Future<SyncResult> _syncDatabase(SyncDirection direction) async {
    final localDbPath = await _getLocalDbPath();
    final remoteDbPath = 'sync_demo/data/$_dbName';

    switch (direction) {
      case SyncDirection.upload:
        return DatabaseSyncManager.safeUploadDatabase(
          client: _client,
          localDbPath: localDbPath,
          remoteDbPath: remoteDbPath,
          onProgress: (sent, total) {
            final progress = (sent / total * 100).toStringAsFixed(1);
            print('Sync: 上传进度 $progress%');
          },
        );

      case SyncDirection.download:
        return DatabaseSyncManager.safeDownloadDatabase(
          client: _client,
          remoteDbPath: remoteDbPath,
          localDbPath: localDbPath,
          onProgress: (received, total) {
            final progress = (received / total * 100).toStringAsFixed(1);
            print('Sync: 下载进度 $progress%');
          },
        );

      case SyncDirection.both:
        // 双向同步逻辑更复杂，这里简化处理
        return SyncResult.failure(
          '双向同步需要更复杂的冲突解决策略',
          SyncFailureType.unknown,
        );
    }
  }

  /// 同步文件（书籍、封面等）
  Future<void> _syncFiles() async {
    print('Sync: 开始同步文件');

    // 获取本地文件列表
    final localFilesDir = Directory('${Directory.systemTemp.path}/sync_demo_files');
    if (!await localFilesDir.exists()) {
      await localFilesDir.create(recursive: true);
    }

    final localFiles = await localFilesDir.list().toList();

    // 获取远程文件列表
    final remoteFiles = await _client.safeReadDir('sync_demo/data/files');
    final remoteFileNames = remoteFiles.map((f) => f.name).toSet();

    // 上传本地有但远程没有的文件
    for (final file in localFiles.whereType<File>()) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      if (!remoteFileNames.contains(fileName)) {
        print('Sync: 上传文件 $fileName');
        await _client.uploadFile(
          file.path,
          'sync_demo/data/files/$fileName',
        );
      }
    }

    // 下载远程有但本地没有的文件
    for (final remoteFile in remoteFiles) {
      final fileName = remoteFile.name;
      final localPath = '${localFilesDir.path}/$fileName';
      final localFile = File(localPath);

      if (!await localFile.exists()) {
        print('Sync: 下载文件 $fileName');
        await _client.downloadFile(
          'sync_demo/data/files/$fileName',
          localPath,
        );
      }
    }

    print('Sync: 文件同步完成');
  }

  /// 获取本地数据库路径
  Future<String> _getLocalDbPath() async {
    // 实际项目中应该从配置中获取
    final dbDir = Directory('${Directory.systemTemp.path}/sync_demo_db');
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    return '${dbDir.path}/$_dbName';
  }

  /// 获取同步状态
  Stream<SyncState> get syncStateStream async* {
    // 实际项目中应该使用 StreamController
    // 这里简化处理
    yield const SyncState(isSyncing: false);
  }
}
