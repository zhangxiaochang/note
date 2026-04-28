/// 同步 item 与状态约定（阶段 0–2：与 [sync_items] 表、后续 Synchronizer 共用）；
/// 远端路径遵循 `benny/data/notes/...`、`benny/data/images/...`、`benny/data/categories/categories.json`。
///
/// `sync_items.item_type` / [SyncItemType]
abstract final class SyncItemType {
  SyncItemType._();

  static const String note = 'note';
  static const String image = 'image';
  static const String categoryIndex = 'category_index';
}

/// `sync_items.item_id` 约定：笔记为 [Note.uuid]；图片为远程 `benny/data/images/` 下文件名；分类索引为 [SyncItemIds.categoryIndexId]。
abstract final class SyncItemIds {
  SyncItemIds._();

  /// 与 [CategorySyncService.remotePath] 中文件名一致，便于对照远端对象。
  static const String categoryIndexId = 'categories.json';
}

/// `sync_items.sync_status`（字符串存库，便于迁移与调试）
abstract final class SyncItemStatus {
  SyncItemStatus._();

  static const String clean = 'clean';
  static const String dirtyLocal = 'dirty_local';
  static const String pendingRemote = 'pending_remote';
  static const String conflict = 'conflict';
  static const String deletePending = 'delete_pending';
}
