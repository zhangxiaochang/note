import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class StorageLocationPrefs {
  StorageLocationPrefs._();

  static const String _keyStorageRootPath = 'storage_root_path_v1';

  static Future<String?> getStorageRootPath() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyStorageRootPath)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<void> setStorageRootPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStorageRootPath, path.trim());
  }

  /// 用户选择父目录后，应用会在其中创建并使用 `benny/` 目录。
  static String resolveBennyRoot(String parentDir) {
    final normalized = parentDir.trim();
    if (normalized.isEmpty) return normalized;
    final baseName = p.basename(normalized).toLowerCase();
    if (baseName == 'benny') return normalized;
    return p.join(normalized, 'benny');
  }
}
