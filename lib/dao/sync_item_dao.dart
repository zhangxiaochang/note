import 'package:sqflite/sqflite.dart';

import '../domain/note.dart';
import '../sync/models/sync_item_vocabulary.dart';
import '../sync/utils/note_sync_hash.dart';
import 'db.dart';

/// `sync_items` 表行（阶段 1–2：供后续 Synchronizer 读写；当前主同步逻辑仍用 notes/sync_meta）
class SyncItemRecord {
  const SyncItemRecord({
    required this.itemType,
    required this.itemId,
    this.syncTargetId = 0,
    required this.syncStatus,
    this.lastSyncedAt,
    this.remoteMtime,
    this.remoteEtag,
    this.contentHash,
    this.lastError,
    this.errorCount = 0,
    this.localUpdatedAt,
  });

  final String itemType;
  final String itemId;
  final int syncTargetId;
  final String syncStatus;
  final int? lastSyncedAt;
  final int? remoteMtime;
  final String? remoteEtag;
  final String? contentHash;
  final String? lastError;
  final int errorCount;
  final int? localUpdatedAt;

  Map<String, Object?> toMap() => {
        'item_type': itemType,
        'item_id': itemId,
        'sync_target_id': syncTargetId,
        'sync_status': syncStatus,
        'last_synced_at': lastSyncedAt,
        'remote_mtime': remoteMtime,
        'remote_etag': remoteEtag,
        'content_hash': contentHash,
        'last_error': lastError,
        'error_count': errorCount,
        'local_updated_at': localUpdatedAt,
      };

  static SyncItemRecord? fromMap(Map<String, Object?>? m) {
    if (m == null) return null;
    return SyncItemRecord(
      itemType: m['item_type']! as String,
      itemId: m['item_id']! as String,
      syncTargetId: (m['sync_target_id'] as int?) ?? 0,
      syncStatus: m['sync_status']! as String,
      lastSyncedAt: m['last_synced_at'] as int?,
      remoteMtime: m['remote_mtime'] as int?,
      remoteEtag: m['remote_etag'] as String?,
      contentHash: m['content_hash'] as String?,
      lastError: m['last_error'] as String?,
      errorCount: (m['error_count'] as int?) ?? 0,
      localUpdatedAt: m['local_updated_at'] as int?,
    );
  }
}

class SyncItemDao {
  SyncItemDao._();
  static final SyncItemDao instance = SyncItemDao._();

  Future<Database> get _db => DB.instance.db;

  Future<void> upsert(SyncItemRecord r) async {
    final db = await _db;
    await db.insert(
      'sync_items',
      r.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SyncItemRecord?> get(
    String itemType,
    String itemId, {
    int syncTargetId = 0,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'sync_items',
      where: 'item_type = ? AND item_id = ? AND sync_target_id = ?',
      whereArgs: [itemType, itemId, syncTargetId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SyncItemRecord.fromMap(rows.first);
  }

  /// 按状态筛行（小库可用；后续可加索引）
  Future<List<SyncItemRecord>> listByStatus(
    String syncStatus, {
    int syncTargetId = 0,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'sync_items',
      where: 'sync_status = ? AND sync_target_id = ?',
      whereArgs: [syncStatus, syncTargetId],
    );
    return rows.map((e) => SyncItemRecord.fromMap(e)!).toList();
  }

  Future<List<SyncItemRecord>> allForTarget({int syncTargetId = 0}) async {
    final db = await _db;
    final rows = await db.query(
      'sync_items',
      where: 'sync_target_id = ?',
      whereArgs: [syncTargetId],
    );
    return rows.map((e) => SyncItemRecord.fromMap(e)!).toList();
  }

  /// 与服务器对齐后的笔记（含 content_hash、clean）
  Future<void> markNoteInSync(Note n) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await upsert(
      SyncItemRecord(
        itemType: SyncItemType.note,
        itemId: n.uuid,
        syncStatus: SyncItemStatus.clean,
        lastSyncedAt: now,
        contentHash: noteSyncContentHash(n),
        lastError: null,
        errorCount: 0,
        localUpdatedAt: n.updatedAt,
      ),
    );
  }

  Future<void> recordNoteSyncFailure(String noteUuid, String message) async {
    final prev = await get(SyncItemType.note, noteUuid);
    final count = (prev?.errorCount ?? 0) + 1;
    await upsert(
      SyncItemRecord(
        itemType: SyncItemType.note,
        itemId: noteUuid,
        syncStatus: SyncItemStatus.dirtyLocal,
        lastError: message,
        errorCount: count,
        contentHash: prev?.contentHash,
        lastSyncedAt: prev?.lastSyncedAt,
        localUpdatedAt: prev?.localUpdatedAt,
        remoteMtime: prev?.remoteMtime,
        remoteEtag: prev?.remoteEtag,
      ),
    );
  }

  Future<void> markCategoryIndexSynced() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await upsert(
      SyncItemRecord(
        itemType: SyncItemType.categoryIndex,
        itemId: SyncItemIds.categoryIndexId,
        syncStatus: SyncItemStatus.clean,
        lastSyncedAt: now,
        lastError: null,
        errorCount: 0,
      ),
    );
  }

  /// 本地分类有改动，需上传 [CategorySyncService.remotePath]
  Future<void> markCategoryIndexDirty() async {
    final prev = await get(
      SyncItemType.categoryIndex,
      SyncItemIds.categoryIndexId,
    );
    await upsert(
      SyncItemRecord(
        itemType: SyncItemType.categoryIndex,
        itemId: SyncItemIds.categoryIndexId,
        syncStatus: SyncItemStatus.dirtyLocal,
        lastSyncedAt: prev?.lastSyncedAt,
        lastError: null,
        errorCount: 0,
      ),
    );
  }

  /// 用户编辑、归档等：笔记需再次与远端对齐
  Future<void> markNoteDirty(
    String noteUuid, {
    int? localUpdatedAt,
  }) async {
    final prev = await get(SyncItemType.note, noteUuid);
    await upsert(
      SyncItemRecord(
        itemType: SyncItemType.note,
        itemId: noteUuid,
        syncStatus: SyncItemStatus.dirtyLocal,
        localUpdatedAt: localUpdatedAt ?? prev?.localUpdatedAt,
        contentHash: prev?.contentHash,
        lastSyncedAt: prev?.lastSyncedAt,
        remoteMtime: prev?.remoteMtime,
        remoteEtag: prev?.remoteEtag,
        lastError: null,
        errorCount: 0,
      ),
    );
  }

  Future<void> markCategoryIndexFailure(String message) async {
    final prev = await get(
      SyncItemType.categoryIndex,
      SyncItemIds.categoryIndexId,
    );
    final count = (prev?.errorCount ?? 0) + 1;
    await upsert(
      SyncItemRecord(
        itemType: SyncItemType.categoryIndex,
        itemId: SyncItemIds.categoryIndexId,
        syncStatus: SyncItemStatus.dirtyLocal,
        lastError: message,
        errorCount: count,
        lastSyncedAt: prev?.lastSyncedAt,
      ),
    );
  }
}
