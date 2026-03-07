import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sync_state.dart';
import '../services/sync_client_base.dart';
import '../services/sync_service.dart';
import '../services/webdav_client.dart';

/// 同步客户端 Provider
/// 管理同步客户端实例
final syncClientProvider = Provider<SyncClientBase?>((ref) {
  // 实际项目中应该从配置中读取
  // 这里返回 null 表示未配置
  return null;
});

/// 同步服务 Provider
final syncServiceProvider = Provider<SyncService?>((ref) {
  final client = ref.watch(syncClientProvider);
  if (client == null) return null;
  return SyncService(client);
});

/// 同步状态 Notifier
class SyncNotifier extends StateNotifier<SyncState> {
  SyncService? _syncService;

  SyncNotifier() : super(const SyncState());

  /// 设置同步服务
  void setSyncService(SyncService service) {
    _syncService = service;
  }

  /// 配置 WebDAV 客户端
  void configureWebDAV({
    required String url,
    required String username,
    required String password,
  }) {
    final client = WebdavClient(
      url: url,
      username: username,
      password: password,
    );
    _syncService = SyncService(client);
  }

  /// 执行同步
  Future<SyncResult> sync({
    SyncDirection direction = SyncDirection.both,
  }) async {
    if (_syncService == null) {
      return SyncResult.failure(
        '同步服务未配置',
        SyncFailureType.unknown,
      );
    }

    // 更新状态为同步中
    state = state.copyWith(isSyncing: true, error: null);

    try {
      final result = await _syncService!.sync(direction);

      // 更新状态
      state = state.copyWith(
        isSyncing: false,
        error: result.isSuccess ? null : result.message,
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
      );
      return SyncResult.failure(
        '同步异常: $e',
        SyncFailureType.unknown,
      );
    }
  }

  /// 测试连接
  Future<bool> testConnection() async {
    if (_syncService == null) return false;

    try {
      state = state.copyWith(isSyncing: true);
      // 实际实现中应该调用 ping
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(isSyncing: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: '连接失败: $e',
      );
      return false;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 同步状态 Provider
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier();
});

/// 是否正在同步
final isSyncingProvider = Provider<bool>((ref) {
  return ref.watch(syncProvider).isSyncing;
});

/// 同步错误信息
final syncErrorProvider = Provider<String?>((ref) {
  return ref.watch(syncProvider).error;
});
