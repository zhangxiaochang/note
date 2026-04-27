import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 多实例本地调试（例如两台 Windows 同时连同一 WebDAV）：
/// `flutter run -d windows --dart-define=MEMO_INSTANCE=a`
///
/// - 未设置 [MEMO_INSTANCE]：与旧版一致——库在 `Documents/memo/momo.db`，图片等在 `Documents/` 下。
/// - 已设置：库与图片均在 `Documents/memo_<实例>/` 下，互不干扰。
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

  /// 存放 SQLite 的目录（`.../memo` 或 `.../memo_a`）。
  static Future<String> databaseDirectoryPath() async {
    final doc = await getApplicationDocumentsDirectory();
    final folder = p.join(doc.path, _memoDirName());
    await Directory(folder).create(recursive: true);
    return folder;
  }

  /// 图片等附件的根目录；无 [MEMO_INSTANCE] 时仍为 Documents（兼容已有图片路径）。
  static Future<Directory> contentRootDirectory() async {
    final doc = await getApplicationDocumentsDirectory();
    if (_raw.trim().isEmpty) {
      return doc;
    }
    final dir = Directory(p.join(doc.path, _memoDirName()));
    await dir.create(recursive: true);
    return dir;
  }
}
