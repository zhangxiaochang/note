import '../../dao/db.dart';
import '../../domain/category.dart';
import '../../domain/note.dart';

/// 上传前补全 [Note.categoryUuid]（便于 [Note.toSyncWireJsonMap]）
Future<Note> ensureNoteHasCategoryUuidForUpload(Note note) async {
  if (note.categoryUuid != null && note.categoryUuid!.isNotEmpty) {
    return note;
  }
  if (note.categoryId == null) return note;
  final cat = await DB.instance.queryCategoryById(note.categoryId!);
  if (cat?.uuid == null || cat!.uuid!.isEmpty) return note;
  return note.copyWith(categoryUuid: cat.uuid);
}

/// 将 WebDAV 拉取的笔记（含 categoryUuid）解析为本地 [categoryId] 后写入库
Future<Note> resolveWireNoteForDb(Note wire) async {
  final base = wire.copyWith(syncStatus: 'synced');
  final uid = base.categoryUuid;
  if (uid == null || uid.isEmpty) {
    return base.withCategoryFields(categoryId: null, categoryUuid: null);
  }
  final cat = await DB.instance.queryCategoryByUuid(uid);
  if (cat != null && cat.id != null) {
    if (cat.isDeleted) {
      return base.withCategoryFields(categoryId: null, categoryUuid: null);
    }
    return base.withCategoryFields(categoryId: cat.id, categoryUuid: uid);
  }
  // 占位时间戳须足够小，否则合并时「未命名」会压过远程 categories.json 里的真实分类
  const placeholderTime = 1;
  final newId = await DB.instance.insertCategory(
    Category(
      uuid: uid,
      name: '未命名分类',
      colorValue: 0xFFFFA7A7,
      createdAt: placeholderTime,
      updatedAt: placeholderTime,
    ),
  );
  return base.withCategoryFields(categoryId: newId, categoryUuid: uid);
}
