import 'package:shared_preferences/shared_preferences.dart';

/// 同步页展示的「上次同步」摘要（仅存轻量数字，不新建数据库表）
class SyncUiLastSession {
  SyncUiLastSession({
    required this.lastSyncAtMs,
    required this.localCount,
    required this.remoteCount,
    required this.success,
    this.message,
  });

  final int lastSyncAtMs;
  final int localCount;
  final int remoteCount;
  final bool success;
  final String? message;
}

class SyncUiPrefs {
  static const _p = 'sync_ui_';
  static const _lastAt = '${_p}last_at';
  static const _local = '${_p}local_count';
  static const _remote = '${_p}remote_count';
  static const _ok = '${_p}last_ok';
  static const _msg = '${_p}last_message';

  static Future<void> saveAfterSession({
    required int localCount,
    required int remoteCount,
    required bool success,
    String? message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastAt, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_local, localCount);
    await prefs.setInt(_remote, remoteCount);
    await prefs.setBool(_ok, success);
    if (message != null && message.isNotEmpty) {
      await prefs.setString(_msg, message);
    } else {
      await prefs.remove(_msg);
    }
  }

  static Future<SyncUiLastSession?> loadLastSession() async {
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getInt(_lastAt);
    if (at == null) return null;
    return SyncUiLastSession(
      lastSyncAtMs: at,
      localCount: prefs.getInt(_local) ?? 0,
      remoteCount: prefs.getInt(_remote) ?? 0,
      success: prefs.getBool(_ok) ?? true,
      message: prefs.getString(_msg),
    );
  }
}
