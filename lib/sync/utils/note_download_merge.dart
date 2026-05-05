import '../../domain/note.dart';

/// 将远端拉取的笔记与本地合并，避免 **仅因时间戳较新** 覆盖掉本机已归档/已删除状态。
///
/// 规则：
/// - `remote.updatedAt > local.updatedAt`：以远端为准（允许远端「取消归档」等）。
/// - 时间戳相同：正文等仍以远端为准，**归档 / 删除** 取「任一侧为真则保留」，
///   `deletedAt` 取较晚的一条。
/// - `local.updatedAt > remote.updatedAt`：不应进入典型下载路径；返回 [local] 以免丢数据。
Note mergeRemoteDownloadWithLocal(Note? local, Note remote) {
  if (local == null) return remote;

  if (remote.updatedAt > local.updatedAt) {
    return remote;
  }
  if (local.updatedAt > remote.updatedAt) {
    return local;
  }

  // updatedAt 相同：合并归档与删除语义，避免同一毫秒内的竞态丢状态
  final mergedArchived = local.archived || remote.archived;
  final mergedIsDeleted = local.isDeleted || remote.isDeleted;
  final mergedDeletedAt = mergedIsDeleted
      ? _mergeDeletedAt(local, remote)
      : null;
  return Note(
    uuid: remote.uuid,
    title: remote.title,
    content: remote.content,
    deltaContent: remote.deltaContent,
    createdAt: remote.createdAt,
    updatedAt: remote.updatedAt,
    archived: mergedArchived,
    categoryId: remote.categoryId,
    categoryUuid: remote.categoryUuid,
    syncStatus: remote.syncStatus,
    isDeleted: mergedIsDeleted,
    deletedAt: mergedDeletedAt,
  );
}

int? _mergeDeletedAt(Note a, Note b) {
  if (!a.isDeleted && !b.isDeleted) return null;
  if (a.isDeleted && !b.isDeleted) return a.deletedAt;
  if (!a.isDeleted && b.isDeleted) return b.deletedAt;
  final da = a.deletedAt ?? 0;
  final db = b.deletedAt ?? 0;
  if (da >= db) {
    return a.deletedAt;
  }
  return b.deletedAt;
}
