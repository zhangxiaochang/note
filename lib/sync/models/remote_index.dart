import 'remote_file.dart';
import 'remote_note_info.dart';

/// 一次「列远端」得到的索引（阶段 2），供 Synchronizer / 增量同步做 diff。
///
/// [notesByUuid]：`benny/data/notes/{shard}/*.json`
/// [imagesByFileName]：`benny/data/images/*` 文件名 -> 元数据
/// [categoryIndex]：`benny/data/categories/categories.json` 的 [RemoteFile] 元数据
class RemoteIndex {
  const RemoteIndex({
    required this.notesByUuid,
    required this.imagesByFileName,
    this.categoryIndex,
  });

  final Map<String, RemoteNoteInfo> notesByUuid;
  final Map<String, RemoteImageInfo> imagesByFileName;
  final RemoteFile? categoryIndex;

  int get noteCount => notesByUuid.length;
  int get imageFileCount => imagesByFileName.length;
}

/// `benny/data/images/{fileName}` 在远端的一条记录
class RemoteImageInfo {
  const RemoteImageInfo({
    required this.fileName,
    required this.path,
    required this.mTime,
    this.size,
  });

  final String fileName;
  final String path;
  final int mTime;
  final int? size;
}
