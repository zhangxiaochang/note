import 'sync_log_writer.dart';
import 'sync_session_marker.dart';

/// 应用 **冷启动** 时调用：若上次同步进行中进程消失，补写一条「未正常结束」日志。
class SyncSessionRecovery {
  SyncSessionRecovery._();

  static Future<void> recoverAfterProcessRestart() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final batchStart = await SyncSessionMarker.peekBatchPendingStartedAt();
    if (batchStart != null) {
      await SyncLogWriter.appendBatchProcessEnded(
        startedAt: batchStart,
        endedAt: now,
      );
      await SyncSessionMarker.clearBatchPending();
    }

    final single = await SyncSessionMarker.peekSinglePending();
    if (single != null) {
      await SyncLogWriter.appendSingleNoteProcessEnded(
        startedAt: single.startedAt,
        endedAt: now,
        noteUuid: single.noteUuid,
      );
      await SyncSessionMarker.clearSinglePending();
    }
  }
}
