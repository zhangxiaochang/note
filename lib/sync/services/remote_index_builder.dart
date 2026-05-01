import '../models/remote_file.dart';
import '../models/remote_index.dart';
import '../models/remote_note_info.dart';
import 'category_sync_service.dart';
import 'sync_client_base.dart';

/// 从 WebDAV（或任意 [SyncClientBase]）列举 `benny/data/` 下笔记、图片、分类索引文件，构建 [RemoteIndex]。
///
/// 与 [Synchronizer] / 原 [IncrementalSync] 中笔记列举逻辑一致，并补充 `benny/data/images/` 与 [CategorySyncService.remotePath] 元数据。
class RemoteIndexBuilder {
  RemoteIndexBuilder._();

  static const String _notesRoot = 'benny/data/notes';
  static const String _imagesDir = 'benny/data/images';

  static Future<RemoteIndex> build(SyncClientBase client) async {
    final notes = await _listNotes(client);
    final images = await _listImages(client);
    final category = await _categoryProps(client);
    return RemoteIndex(
      notesByUuid: notes,
      imagesByFileName: images,
      categoryIndex: category,
    );
  }

  static Future<Map<String, RemoteNoteInfo>> _listNotes(
    SyncClientBase client,
  ) async {
    final out = <String, RemoteNoteInfo>{};
    try {
      final shardDirs = await client.safeReadDir(_notesRoot);
      for (final dir in shardDirs) {
        if (dir.isDir == true) {
          final shardPath = '$_notesRoot/${dir.name}';
          final noteFiles = await client.safeReadDir(shardPath);
          for (final file in noteFiles) {
            if (file.isDir != true && file.name?.endsWith('.json') == true) {
              final fileName = file.name!;
              final noteUuid = fileName.replaceAll('.json', '');
              out[noteUuid] = RemoteNoteInfo(
                uuid: noteUuid,
                path: '$shardPath/$fileName',
                mTime: file.mTime?.millisecondsSinceEpoch ?? 0,
              );
            }
          }
        }
      }
    } catch (e) {
      // 列举失败时返回已收集项，由上层同步逻辑感知。
    }
    return out;
  }

  static Future<Map<String, RemoteImageInfo>> _listImages(
    SyncClientBase client,
  ) async {
    final out = <String, RemoteImageInfo>{};
    try {
      final files = await client.safeReadDir(_imagesDir);
      for (final file in files) {
        if (file.isDir == true) continue;
        final name = file.name;
        if (name == null || name.isEmpty) continue;
        out[name] = RemoteImageInfo(
          fileName: name,
          path: '$_imagesDir/$name',
          mTime: file.mTime?.millisecondsSinceEpoch ?? 0,
          size: file.size,
        );
      }
    } catch (e) {
      // ignore
    }
    return out;
  }

  static Future<RemoteFile?> _categoryProps(SyncClientBase client) async {
    try {
      return client.readProps(CategorySyncService.remotePath);
    } catch (e) {
      return null;
    }
  }
}
