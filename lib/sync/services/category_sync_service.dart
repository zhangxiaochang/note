import 'dart:convert';

import '../../dao/db.dart';
import '../../domain/category.dart';
import 'sync_client_base.dart';

/// 远程 `benny/data/categories/categories.json` 与本地分类合并（按 uuid，取 updatedAt 较新）
class CategorySyncService {
  static const String remoteDir = 'benny/data/categories';
  static const String remotePath = '$remoteDir/categories.json';

  static String _stripBom(String raw) {
    var s = raw.trimLeft();
    if (s.startsWith('\uFEFF')) {
      s = s.substring(1);
    }
    return s.trim();
  }

  /// 支持根为数组，或 `{"categories":[...]}` / 首个 List 值
  static List<dynamic>? _asJsonList(dynamic decoded) {
    if (decoded is List<dynamic>) return decoded;
    if (decoded is Map) {
      for (final key in const ['categories', 'items', 'data', 'list']) {
        final v = decoded[key];
        if (v is List<dynamic>) return v;
      }
      for (final v in decoded.values) {
        if (v is List<dynamic>) return v;
      }
    }
    return null;
  }

  static List<Category> _parseRemoteList(List<dynamic> list) {
    final out = <Category>[];
    for (final e in list) {
      if (e is! Map) continue;
      try {
        final c = Category.fromSyncJson(Map<String, dynamic>.from(e));
        if (c.uuid != null && c.uuid!.isNotEmpty) {
          out.add(c);
        }
      } catch (_) {
        // skip corrupt entry
      }
    }
    return out;
  }

  static Future<void> sync(SyncClientBase client) async {
    await client.mkdirAll(remoteDir);
    final local = await DB.instance.queryAllCategoriesForSync();
    var remote = <Category>[];
    var remoteReadFailed = false;

    try {
      final raw = await client.downloadString(remotePath);
      final content = _stripBom(raw);
      if (content.isEmpty) {
        remote = [];
      } else {
        final decoded = jsonDecode(content);
        final list = _asJsonList(decoded);
        if (list == null) {
          throw FormatException('categories.json 无法解析为数组或含数组的对象');
        }
        remote = _parseRemoteList(list);
      }
    } catch (e) {
      // 部分 WebDAV 对文件的 PROPFIND 不可靠，不能仅靠 isExist；下载失败时再区分「无文件」与「读失败」
      try {
        final exists = await client.isExist(remotePath);
        if (exists) {
          throw StateError('无法读取远程分类文件 $remotePath: $e');
        }
      } catch (e2) {
        if (e2 is StateError) rethrow;
        // isExist 也异常时，保守视为未读到远程数据
      }
      remoteReadFailed = true;
    }

    final merged = _mergeByLatest(local, remote);
    for (final c in merged) {
      await DB.instance.upsertCategoryFromSync(c);
    }
    await DB.instance.relinkNoteCategoryIdsFromUuids();

    final out = jsonEncode(merged.map((c) => c.toSyncJson()).toList());
    // 远程读取失败且本地也无分类时，不上传 []，避免误覆盖服务器
    if (merged.isEmpty && remoteReadFailed) {
      return;
    }
    await client.uploadString(out, remotePath);
  }

  /// 笔记先行落地时插入的占位分类（`note_wire_resolve` 中「未命名分类」）
  static bool _isWirePlaceholder(Category c) => c.name == '未命名分类';

  static List<Category> _mergeByLatest(List<Category> a, List<Category> b) {
    final map = <String, Category>{};
    void put(Category c) {
      if (c.uuid == null || c.uuid!.isEmpty) return;
      final u = c.uuid!;
      final existing = map[u];
      if (existing == null) {
        map[u] = c;
        return;
      }
      if (c.updatedAt > existing.updatedAt) {
        map[u] = c;
        return;
      }
      // 旧版占位用了笔记时间戳，会压过远程真实分类；用非占位覆盖占位
      if (_isWirePlaceholder(existing) && !_isWirePlaceholder(c)) {
        map[u] = c;
        return;
      }
      if (c.updatedAt == existing.updatedAt) {
        map[u] = c;
      }
    }
    for (final c in a) {
      put(c);
    }
    for (final c in b) {
      put(c);
    }
    return map.values.toList();
  }
}
