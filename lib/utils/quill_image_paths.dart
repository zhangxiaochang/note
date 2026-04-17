import '../domain/note.dart';
import 'image_path_resolver.dart';

/// 从 Quill Delta 中取出 `insert.image` 的路径（含网络 URL 与本地相对路径）
List<String> extractImagePathsFromQuillDelta(List<dynamic>? delta) {
  final images = <String>[];
  if (delta == null) return images;
  for (final op in delta) {
    if (op is Map && op.containsKey('insert')) {
      final insert = op['insert'];
      if (insert is Map && insert.containsKey('image')) {
        final imagePath = insert['image'];
        if (imagePath is String && imagePath.trim().isNotEmpty) {
          images.add(imagePath.trim());
        }
      }
    }
  }
  return images;
}

/// 活跃笔记正文中引用的、**非网络 URL** 的图片路径去重数量（用于本机图片统计）
int countDistinctLocalImageRefs(List<Note> notes) {
  final paths = <String>{};
  for (final n in notes) {
    for (final p in extractImagePathsFromQuillDelta(n.deltaContent)) {
      if (!ImagePathResolver.isWebUrl(p)) {
        paths.add(p);
      }
    }
  }
  return paths.length;
}
