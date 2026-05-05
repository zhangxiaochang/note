import 'package:shared_preferences/shared_preferences.dart';

/// 同步会话持久化标记：用于在 **进程被系统杀死** 后，下次启动能写出「未完成」日志。
///
/// 说明：真正意义上的「后台长时间同步」需 Android 前台服务 / iOS BGProcessing 等；
/// 此处仅保证 **可检测的异常终止** 并在 [SyncLogWriter] 留痕。
class SyncSessionMarker {
  SyncSessionMarker._();

  static const _batchStartedMs = 'sync_sess_batch_started_ms';
  static const _singleStartedMs = 'sync_sess_single_started_ms';
  static const _singleUuid = 'sync_sess_single_uuid';

  static Future<void> markBatchPending(int startedAtMs) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_batchStartedMs, startedAtMs);
  }

  static Future<void> clearBatchPending() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_batchStartedMs);
  }

  static Future<void> markSinglePending({
    required String noteUuid,
    required int startedAtMs,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_singleStartedMs, startedAtMs);
    await p.setString(_singleUuid, noteUuid);
  }

  static Future<void> clearSinglePending() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_singleStartedMs);
    await p.remove(_singleUuid);
  }

  /// 读取未清理的全量会话开始时间；无则 null。
  static Future<int?> peekBatchPendingStartedAt() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_batchStartedMs);
  }

  static Future<({int startedAt, String noteUuid})?> peekSinglePending() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getInt(_singleStartedMs);
    final u = p.getString(_singleUuid);
    if (t == null || u == null || u.isEmpty) return null;
    return (startedAt: t, noteUuid: u);
  }
}
