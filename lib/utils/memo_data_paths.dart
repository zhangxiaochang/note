import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'storage_location_prefs.dart';

/// 数据目录优先级：
/// 1) 用户在启动引导或设置页选择的自定义目录（SharedPreferences）
/// 2) 开发态 `MEMO_INSTANCE` 分实例目录
/// 3) 旧版默认目录（兼容）
///
/// 多实例本地调试（例如两台 Windows 同时连同一 WebDAV）：
/// `flutter run -d windows --dart-define=MEMO_INSTANCE=a`
///
/// 注意：SharedPreferences 等仍按应用包名共用，两台实例会共享 WebDAV 等配置（测同步时通常可接受）。
class MemoDataPaths {
  MemoDataPaths._();

  static const String _raw =
      String.fromEnvironment('MEMO_INSTANCE', defaultValue: '');

  static String _memoDirName() {
    final t = _raw.trim();
    if (t.isEmpty) return 'memo';
    final safe = t.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return safe.isEmpty ? 'memo_test' : 'memo_$safe';
  }

  static Future<void> _ensureCustomStructure(String root) async {
    final configDir = Directory(p.join(root, 'config'));
    final dataDir = Directory(p.join(root, 'data'));
    final dbDir = Directory(p.join(root, 'data', 'db'));
    final imagesDir = Directory(p.join(root, 'data', 'images'));
    await configDir.create(recursive: true);
    await dataDir.create(recursive: true);
    await dbDir.create(recursive: true);
    await imagesDir.create(recursive: true);

    // 兼容旧结构：benny/data/momo.db -> benny/data/db/momo.db
    final legacyDb = File(p.join(root, 'data', 'momo.db'));
    final currentDb = File(p.join(root, 'data', 'db', 'momo.db'));
    if (await legacyDb.exists() && !await currentDb.exists()) {
      await legacyDb.copy(currentDb.path);
    }

    // 兼容旧结构：benny/data/notes/momo.db -> benny/data/db/momo.db
    final legacyNotesDb = File(p.join(root, 'data', 'notes', 'momo.db'));
    if (await legacyNotesDb.exists() && !await currentDb.exists()) {
      await legacyNotesDb.copy(currentDb.path);
    }

    // 兼容旧结构：benny/images -> benny/data/images
    final legacyImages = Directory(p.join(root, 'images'));
    if (await legacyImages.exists()) {
      final legacyFiles = await legacyImages.list().toList();
      for (final entry in legacyFiles) {
        if (entry is File) {
          final target = File(p.join(imagesDir.path, p.basename(entry.path)));
          if (!await target.exists()) {
            await entry.copy(target.path);
          }
        }
      }
    }
  }

  /// 存放 SQLite 的目录（`.../memo` 或 `.../memo_a`）。
  static Future<String> databaseDirectoryPath() async {
    final customRoot = await StorageLocationPrefs.getStorageRootPath();
    if (customRoot != null) {
      await _ensureCustomStructure(customRoot);
      final dbDir = p.join(customRoot, 'data', 'db');
      await Directory(dbDir).create(recursive: true);
      return dbDir;
    }
    final doc = await getApplicationDocumentsDirectory();
    final folder = p.join(doc.path, _memoDirName());
    await Directory(folder).create(recursive: true);
    return folder;
  }

  /// 图片等附件的根目录；无 [MEMO_INSTANCE] 时仍为 Documents（兼容已有图片路径）。
  static Future<Directory> contentRootDirectory() async {
    final customRoot = await StorageLocationPrefs.getStorageRootPath();
    if (customRoot != null) {
      await _ensureCustomStructure(customRoot);
      final dir = Directory(p.join(customRoot, 'data'));
      await dir.create(recursive: true);
      return dir;
    }
    final doc = await getApplicationDocumentsDirectory();
    if (_raw.trim().isEmpty) {
      return doc;
    }
    final dir = Directory(p.join(doc.path, _memoDirName()));
    await dir.create(recursive: true);
    return dir;
  }
}
