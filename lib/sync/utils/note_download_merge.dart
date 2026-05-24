import '../../domain/note.dart';

/// 合并两条笔记的删除时间戳（任一侧已删除时选用较合理的 [deletedAt]）。
int? mergeDeletedAtFields(Note a, Note b) {
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

/// 本机胜出上传时合并归档：避免正文较新的一次保存把 **他端已归档** 误覆盖成未归档。
Note mergeArchivedWhenLocalUploadWins(Note local, Note remote) {
  return local.copyWith(archived: local.archived || remote.archived);
}

/// 将远端拉取的笔记与本地合并。
///
/// 规则：
/// - `remote.updatedAt > local.updatedAt`：整笔记以远端为准（含 `archived`），保证
///   他端「归档 / 取消归档」能随较新的 [updatedAt] 下发。
/// - `updatedAt` 相同：归档与删除取「任一侧为真」，[deletedAt] 取较晚一条。
/// - `local.updatedAt > remote.updatedAt`：返回 [local]（典型路径不应下载）。
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
  final mergedDeletedAt =
      mergedIsDeleted ? mergeDeletedAtFields(local, remote) : null;
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
