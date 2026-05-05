import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../dao/db.dart';
import '../../dao/sync_item_dao.dart';
import '../../domain/note.dart';
import '../models/sync_item_vocabulary.dart';
import '../models/remote_note_info.dart';
import '../models/sync_progress.dart';
import '../models/sync_state.dart';
import '../utils/note_sync_hash.dart';
import '../utils/note_wire_resolve.dart';
import '../utils/sync_planner.dart';
import 'category_sync_service.dart';
import 'remote_index_builder.dart';
import 'single_note_sync.dart';
import 'sync_client_base.dart';

/// 用户取消同步
class SyncUserCancelled implements Exception {
  SyncUserCancelled();
}

/// 统一同步入口：分类 → 列索引 → 按条笔记与删除清理 → 全局 [sync_meta]；并回写 [sync_items]。
class Synchronizer {
  Synchronizer(
    this._client, {
    SyncProgressController? progress,
    bool Function()? isCancelled,
  })  : _progress = progress,
        _isCancelled = isCancelled,
        _singleNoteSync = SingleNoteSync(_client);

  final SyncClientBase _client;
  final SingleNoteSync _singleNoteSync;
  final SyncProgressController? _progress;
  final bool Function()? _isCancelled;

  int _processedOps = 0;

  void setContext(BuildContext context) {
    _singleNoteSync.setContext(context);
  }

  void _ensureNotCancelled() {
    if (_isCancelled?.call() == true) {
      throw SyncUserCancelled();
    }
  }

  void _bump({String? noteTitle}) {
    _ensureNotCancelled();
    _processedOps++;
    final total = _progress?.currentProgress.totalNotes ?? 1;
    final title = noteTitle?.isNotEmpty == true ? noteTitle : null;
    _progress?.updateProcessedNotes(
      math.min(_processedOps, math.max(total, 1)),
      currentNoteTitle: title,
    );
  }

  Future<SyncResult> run() async {
    try {
      _progress?.setPhase(SyncPhase.preparing, message: '正在连接服务器…');
      await _client.ping();
      _ensureNotCancelled();

      _progress?.setPhase(SyncPhase.preparing, message: '正在检查远端目录…');
      await _singleNoteSync.ensureRemoteRoots();
      _ensureNotCancelled();

      _progress?.setPhase(SyncPhase.preparing, message: '正在同步分类…');
      try {
        await CategorySyncService.sync(_client);
        await SyncItemDao.instance.markCategoryIndexSynced();
      } catch (e) {
        await SyncItemDao.instance.markCategoryIndexFailure(e.toString());
        // 分类索引失败不阻断笔记/图片主流程，避免目录权限差异导致整轮同步不可用。
      }
      _ensureNotCancelled();

      final localNotes = await _getLocalNotesToSync();

      final remoteNotes = await _getRemoteNotes();

      _ensureNotCancelled();

      final planned = plannedSyncOperationCount(localNotes, remoteNotes);
      _processedOps = 0;
      _progress?.setCounts(
        localNotesCount: localNotes.length,
        remoteNotesCount: remoteNotes.length,
        totalNotes: planned,
      );
      _progress?.setPhase(SyncPhase.syncingNotes, message: '正在同步笔记与图片…');

      final syncErrors = await _syncChangedNotes(localNotes, remoteNotes);
      _ensureNotCancelled();

      await _syncDeletedNotes(localNotes, remoteNotes);
      _ensureNotCancelled();

      _progress?.setPhase(SyncPhase.finalizing, message: '正在保存同步状态…');
      await _updateGlobalSyncState();

      if (syncErrors.isNotEmpty) {
        return SyncResult.failure(
          '部分笔记同步失败: ${syncErrors.join(', ')}',
          SyncFailureType.unknown,
        );
      }

      return SyncResult.success('增量同步成功完成');
    } on SyncUserCancelled {
      return SyncResult.failure('同步已取消', SyncFailureType.unknown);
    } catch (e) {
      final message = '$e';
      if (message.contains('Unauthorized') || message.contains('401')) {
        return SyncResult.failure(
          '同步失败：服务器拒绝认证（401 Unauthorized）。请检查 WebDAV 地址/账号/密码，或确认该路径有读写权限。',
          SyncFailureType.networkError,
        );
      }
      return SyncResult.failure('同步失败: $e', SyncFailureType.unknown);
    }
  }

  // 删除同步依赖 tombstone（isDeleted=1）上传，因此这里必须包含已删除笔记。
  Future<List<Note>> _getLocalNotesToSync() => DB.instance.queryAllIncludingDeleted();

  Future<Map<String, RemoteNoteInfo>> _getRemoteNotes() async {
    final index = await RemoteIndexBuilder.build(_client);
    return index.notesByUuid;
  }

  Future<void> _recordNoteFailure(String noteUuid, String message) async {
    await SyncItemDao.instance.recordNoteSyncFailure(noteUuid, message);
  }

  Future<List<String>> _syncChangedNotes(
    List<Note> localNotes,
    Map<String, RemoteNoteInfo> remoteNotes,
  ) async {
    final errors = <String>[];

    for (final localNote in localNotes) {
      _ensureNotCancelled();
      if (!remoteNotes.containsKey(localNote.uuid)) {
        if (localNote.isDeleted) {
          continue;
        }
        final result = await _singleNoteSync.syncNote(localNote.uuid);
        _bump(noteTitle: localNote.title);
        if (!result.isSuccess) {
          errors.add('${localNote.uuid}: ${result.message}');
          await _recordNoteFailure(localNote.uuid, result.message);
        }
      }
    }

    for (final localNote in localNotes) {
      _ensureNotCancelled();
      if (remoteNotes.containsKey(localNote.uuid)) {
        final remoteInfo = remoteNotes[localNote.uuid]!;

        final remoteNote = await _downloadRemoteNote(remoteInfo.path);
        if (remoteNote == null) {
          _bump(noteTitle: localNote.title);
          continue;
        }

        final resolution = _resolveDeleteConflict(localNote, remoteNote);

        switch (resolution) {
          case ConflictResolution.useLocal:
            final result = await _singleNoteSync.syncNote(localNote.uuid, forceSync: true);
            if (!result.isSuccess) {
              errors.add('${localNote.uuid}: ${result.message}');
              await _recordNoteFailure(localNote.uuid, result.message);
            }
            break;
          case ConflictResolution.useRemote:
            await _applyRemoteTombstone(remoteNote);
            break;
          case ConflictResolution.noConflict:
            if (await _needsPairwiseSync(localNote, remoteNote)) {
              final result = await _singleNoteSync.syncNote(
                localNote.uuid,
                preloadedRemote: remoteNote,
                forceSync: true,
              );
              if (!result.isSuccess) {
                errors.add('${localNote.uuid}: ${result.message}');
                await _recordNoteFailure(localNote.uuid, result.message);
              }
            }
            break;
        }
        _bump(noteTitle: localNote.title);
      }
    }

    for (final entry in remoteNotes.entries) {
      _ensureNotCancelled();
      final noteUuid = entry.key;
      final remoteInfo = entry.value;

      final localNote = await DB.instance.queryNoteByUuid(noteUuid);
      if (localNote == null) {
        final remoteNote = await _downloadRemoteNote(remoteInfo.path);
        if (remoteNote != null && remoteNote.isDeleted) {
          _bump(noteTitle: remoteNote.title);
          continue;
        }
        await _downloadNewNote(remoteInfo);
        _bump(noteTitle: remoteNote?.title ?? noteUuid);
      }
    }

    return errors;
  }

  Future<void> _syncDeletedNotes(
    List<Note> localNotes,
    Map<String, RemoteNoteInfo> remoteNotes,
  ) async {
    for (final localNote in localNotes) {
      _ensureNotCancelled();
      if (!remoteNotes.containsKey(localNote.uuid)) {
        if (localNote.isDeleted) {
          await DB.instance.deletePermanently(localNote.uuid);
          _bump(noteTitle: localNote.title);
        }
      }
    }
  }

  /// 双端均有 JSON 时：以 [sync_items] + 内容指纹决定是否需要 `syncNote`
  Future<bool> _needsPairwiseSync(Note localNote, Note remoteNote) async {
    final row = await SyncItemDao.instance.get(
      SyncItemType.note,
      localNote.uuid,
    );
    if (row != null) {
      if (row.syncStatus == SyncItemStatus.dirtyLocal ||
          row.syncStatus == SyncItemStatus.conflict ||
          row.syncStatus == SyncItemStatus.pendingRemote) {
        return true;
      }
    } else if (localNote.syncStatus != 'synced') {
      return true;
    }
    return noteSyncContentHash(localNote) != noteSyncContentHash(remoteNote);
  }

  Future<void> _downloadNewNote(RemoteNoteInfo remoteInfo) async {
    try {
      final content = await _client.downloadString(remoteInfo.path);
      final noteMap = jsonDecode(content) as Map<String, dynamic>;

      final raw = Note.fromMap(noteMap);
      final resolved = await resolveWireNoteForDb(raw);
      final note = _singleNoteSync.normalizeNoteImageRefs(resolved);

      await DB.instance.insert(note);

      await _singleNoteSync.downloadNoteImages(note);

      await DB.instance.updateSyncStatus(note.uuid, 'synced');
      await DB.instance.updateSyncMeta(note.uuid, {
        'content_hash': noteSyncContentHash(note),
        'last_sync_at': DateTime.now().millisecondsSinceEpoch,
      });
      final fresh = await DB.instance.queryNoteByUuid(note.uuid);
      if (fresh != null) {
        await SyncItemDao.instance.markNoteInSync(fresh);
      }
    } catch (e) {
      await _recordNoteFailure(remoteInfo.uuid, e.toString());
    }
  }

  Future<void> _updateGlobalSyncState() async {
    final syncTime = DateTime.now().millisecondsSinceEpoch;
    await DB.instance.updateSyncMeta('global', {
      'last_sync_at': syncTime,
    });
  }

  Future<Note?> _downloadRemoteNote(String remotePath) async {
    try {
      final content = await _client.downloadString(remotePath);
      final noteMap = jsonDecode(content);
      return Note.fromMap(noteMap);
    } catch (e) {
      return null;
    }
  }

  ConflictResolution _resolveDeleteConflict(Note localNote, Note remoteNote) {
    if (!remoteNote.isDeleted) {
      if (localNote.isDeleted) {
        return ConflictResolution.useLocal;
      }
      return ConflictResolution.noConflict;
    }

    if (localNote.updatedAt > (remoteNote.deletedAt ?? 0)) {
      return ConflictResolution.useLocal;
    } else {
      return ConflictResolution.useRemote;
    }
  }

  /// 采用远端墓碑：时间与删除时刻与远端 JSON 对齐，避免各端「删除时间」不一致。
  Future<void> _applyRemoteTombstone(Note remoteNote) async {
    try {
      final deletedAt = remoteNote.deletedAt ?? remoteNote.updatedAt;
      await DB.instance.update(
        {
          'isDeleted': 1,
          'deletedAt': deletedAt,
          'updatedAt': remoteNote.updatedAt,
          'syncStatus': 'synced',
        },
        where: 'uuid = ?',
        whereArgs: [remoteNote.uuid],
      );
      final n = await DB.instance.queryNoteByUuid(remoteNote.uuid);
      if (n != null) {
        await SyncItemDao.instance.markNoteInSync(n);
      }
    } catch (_) {}
  }
}

/// 冲突解决结果
enum ConflictResolution {
  useLocal,
  useRemote,
  noConflict,
}
