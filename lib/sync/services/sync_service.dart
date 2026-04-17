import 'package:flutter/material.dart';

import '../models/sync_state.dart';
import 'incremental_sync.dart';
import 'sync_client_base.dart';

/// 同步服务：仅支持按笔记 JSON + 图片的增量同步（整库上传/下载已移除）
class SyncService {
  final SyncClientBase _client;
  BuildContext? _context;

  SyncService(this._client, {BuildContext? context}) : _context = context;

  void setContext(BuildContext context) {
    _context = context;
  }

  Future<bool> shouldSync() async {
    if (!_client.isConfigured) {
      return false;
    }
    return true;
  }

  /// [direction] 已废弃，保留参数仅为兼容旧调用；实际始终执行增量合并同步。
  Future<SyncResult> sync([SyncDirection direction = SyncDirection.both]) async {
    try {
      if (!await shouldSync()) {
        return SyncResult.failure('未配置同步或无需同步', SyncFailureType.unknown);
      }

      await _client.ping();

      final incremental = IncrementalSync(_client);
      if (_context != null && _context!.mounted) {
        incremental.setContext(_context!);
      }

      return incremental.sync();
    } catch (e) {
      return SyncResult.failure(
        '同步失败: $e',
        SyncFailureType.networkError,
      );
    }
  }

  Stream<SyncState> get syncStateStream async* {
    yield const SyncState(isSyncing: false);
  }
}
