import 'package:flutter/material.dart';

import '../services/webdav_config_service.dart';
import '../sync/services/async_sync_service.dart';
import '../widgets/custom_snackbar.dart';

/// 从笔记卡片 / 列表入口触发 **单条笔记** WebDAV 同步。
class NoteSingleSyncRunner {
  NoteSingleSyncRunner._();

  /// 返回是否同步成功（含「无需同步」视为成功）。
  static Future<bool> run(
    BuildContext context,
    String noteUuid, {
    VoidCallback? onComplete,
    bool forceSync = true,
  }) async {
    final client = await WebDAVConfigService.createClient();
    if (client == null) {
      if (context.mounted) {
        CustomSnackBar.showWarning(
          context,
          message: '请先配置 WebDAV 同步设置',
        );
      }
      return false;
    }

    final service = AsyncSyncService(client);
    if (context.mounted) {
      service.setContext(context);
    }

    try {
      final result = await service.syncSingleNote(
        noteUuid,
        forceSync: forceSync,
      );
      onComplete?.call();
      if (!context.mounted) return result.isSuccess;

      if (result.isSuccess) {
        CustomSnackBar.showSuccess(
          context,
          message: result.message.isEmpty ? '同步完成' : result.message,
        );
      } else {
        CustomSnackBar.showWarning(context, message: result.message);
      }
      return result.isSuccess;
    } catch (e) {
      onComplete?.call();
      if (context.mounted) {
        CustomSnackBar.showWarning(context, message: '同步失败: $e');
      }
      return false;
    } finally {
      service.dispose();
    }
  }
}
