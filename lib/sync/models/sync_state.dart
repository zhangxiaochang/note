import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_state.freezed.dart';

/// 同步方向枚举
enum SyncDirection {
  upload,    // 上传到服务器
  download,  // 从服务器下载
  both,      // 双向同步
}

/// 同步触发方式
enum SyncTrigger {
  auto,      // 自动同步
  manual,    // 手动同步
}

/// 同步状态模型
@freezed
class SyncState with _$SyncState {
  const factory SyncState({
    @Default(SyncDirection.both) SyncDirection direction,
    @Default(false) bool isSyncing,
    @Default(0) int total,
    @Default(0) int current,
    String? currentFile,
    String? error,
  }) = _SyncState;
}

/// 同步结果
class SyncResult {
  final bool isSuccess;
  final String message;
  final SyncFailureType? failureType;

  const SyncResult._(this.isSuccess, this.message, this.failureType);

  factory SyncResult.success(String message) =>
      SyncResult._(true, message, null);

  factory SyncResult.failure(String message, SyncFailureType type) =>
      SyncResult._(false, message, type);
}

/// 同步失败类型
enum SyncFailureType {
  networkError,
  authenticationError,
  validationFailed,
  replacementFailed,
  unknown,
}
