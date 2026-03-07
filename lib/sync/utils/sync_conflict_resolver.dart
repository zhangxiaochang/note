import 'dart:io';
import '../models/remote_file.dart';

/// 同步冲突解决器
/// 提供多种冲突解决策略
class SyncConflictResolver {
  /// 冲突解决策略
  final ConflictResolutionStrategy strategy;

  SyncConflictResolver({
    this.strategy = ConflictResolutionStrategy.newerWins,
  });

  /// 解决冲突
  ///
  /// [localFile] 本地文件
  /// [remoteFile] 远程文件信息
  ///
  /// 返回应该采用的文件来源
  ConflictResolution resolve(File localFile, RemoteFile remoteFile) {
    switch (strategy) {
      case ConflictResolutionStrategy.newerWins:
        return _resolveByNewer(localFile, remoteFile);

      case ConflictResolutionStrategy.localWins:
        return ConflictResolution.useLocal;

      case ConflictResolutionStrategy.remoteWins:
        return ConflictResolution.useRemote;

      case ConflictResolutionStrategy.askUser:
        // 实际项目中应该弹出对话框
        return _resolveByNewer(localFile, remoteFile);

      case ConflictResolutionStrategy.merge:
        // 数据库合并需要更复杂的逻辑
        return ConflictResolution.needsMerge;
    }
  }

  /// 基于时间戳解决冲突（选择较新的）
  ConflictResolution _resolveByNewer(
    File localFile,
    RemoteFile remoteFile,
  ) {
    final localModTime = localFile.lastModifiedSync();
    final remoteModTime = remoteFile.mTime;

    if (remoteModTime == null) {
      return ConflictResolution.useLocal;
    }

    // 如果时间差小于阈值，认为没有冲突
    final diff = localModTime.difference(remoteModTime).inSeconds.abs();
    if (diff < 5) {
      return ConflictResolution.noConflict;
    }

    return localModTime.isAfter(remoteModTime)
        ? ConflictResolution.useLocal
        : ConflictResolution.useRemote;
  }

  /// 检查是否存在冲突
  static bool hasConflict(File localFile, RemoteFile? remoteFile) {
    if (!localFile.existsSync()) return false;
    if (remoteFile == null) return false;

    final localModTime = localFile.lastModifiedSync();
    final remoteModTime = remoteFile.mTime;

    if (remoteModTime == null) return false;

    final diff = localModTime.difference(remoteModTime).inSeconds.abs();
    return diff >= 5; // 5秒以上差异视为冲突
  }

  /// 获取冲突详情
  static ConflictDetails getConflictDetails(
    File localFile,
    RemoteFile remoteFile,
  ) {
    return ConflictDetails(
      localPath: localFile.path,
      remotePath: remoteFile.path ?? '',
      localSize: localFile.lengthSync(),
      remoteSize: remoteFile.size ?? 0,
      localModTime: localFile.lastModifiedSync(),
      remoteModTime: remoteFile.mTime,
    );
  }
}

/// 冲突解决策略枚举
enum ConflictResolutionStrategy {
  newerWins,   // 较新的版本优先
  localWins,   // 本地版本优先
  remoteWins,  // 远程版本优先
  askUser,     // 询问用户
  merge,       // 尝试合并（需要特殊处理）
}

/// 冲突解决结果
enum ConflictResolution {
  useLocal,      // 使用本地版本
  useRemote,     // 使用远程版本
  noConflict,    // 无冲突
  needsMerge,    // 需要合并
}

/// 冲突详情
class ConflictDetails {
  final String localPath;
  final String remotePath;
  final int localSize;
  final int remoteSize;
  final DateTime localModTime;
  final DateTime? remoteModTime;

  ConflictDetails({
    required this.localPath,
    required this.remotePath,
    required this.localSize,
    required this.remoteSize,
    required this.localModTime,
    this.remoteModTime,
  });

  @override
  String toString() {
    return '''冲突详情:
  本地: $localPath
    大小: ${(localSize / 1024).toStringAsFixed(2)} KB
    修改时间: $localModTime
  远程: $remotePath
    大小: ${(remoteSize / 1024).toStringAsFixed(2)} KB
    修改时间: $remoteModTime''';  }
}
