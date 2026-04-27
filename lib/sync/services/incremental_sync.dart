import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../dao/db.dart';
import '../../domain/note.dart';
import '../models/sync_progress.dart';
import '../models/sync_state.dart';
import '../utils/note_sync_hash.dart';
import '../utils/note_wire_resolve.dart';
import 'category_sync_service.dart';
import 'single_note_sync.dart';
import 'sync_client_base.dart';

/// 用户取消同步
class SyncUserCancelled implements Exception {
  SyncUserCancelled();
}

/// 增量同步（唯一支持的同步方式：每条笔记 JSON + 图片）
class IncrementalSync {
  IncrementalSync(
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

  /// 执行增量同步
  Future<SyncResult> sync() async {
    try {
      print('Sync: 开始增量同步');

      _progress?.setPhase(SyncPhase.preparing, message: '正在连接服务器…');
      await _client.ping();
      _ensureNotCancelled();

      _progress?.setPhase(SyncPhase.preparing, message: '正在同步分类…');
      await CategorySyncService.sync(_client);
      _ensureNotCancelled();

      final localNotes = await _getLocalNotesToSync();
      print('Sync: 本地笔记数量: ${localNotes.length}');

      final remoteNotes = await _getRemoteNotes();
      print('Sync: 远程笔记数量: ${remoteNotes.length}');

      _ensureNotCancelled();

      final planned = _plannedOperationCount(localNotes, remoteNotes);
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

      print('Sync: 增量同步完成');

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
      print('Sync: 增量同步失败: $e');
      return SyncResult.failure('同步失败: $e', SyncFailureType.unknown);
    }
  }

  /// 获取本地需要同步的笔记
  Future<List<Note>> _getLocalNotesToSync() async {
    return DB.instance.queryAll();
  }

  /// 获取远程笔记列表（分片目录 `benny/notes/{shard}/*.json`）
  Future<Map<String, RemoteNoteInfo>> _getRemoteNotes() async {
    final remoteNotes = <String, RemoteNoteInfo>{};

    try {
      final shardDirs = await _client.safeReadDir('benny/notes');

      for (final dir in shardDirs) {
        if (dir.isDir == true) {
          final shardPath = 'benny/notes/${dir.name}';
          final noteFiles = await _client.safeReadDir(shardPath);

          for (final file in noteFiles) {
            if (file.isDir != true && file.name?.endsWith('.json') == true) {
              final fileName = file.name!;
              final noteUuid = fileName.replaceAll('.json', '');
              remoteNotes[noteUuid] = RemoteNoteInfo(
                uuid: noteUuid,
                path: '$shardPath/$fileName',
                mTime: file.mTime?.millisecondsSinceEpoch ?? 0,
              );
            }
          }
        }
      }
    } catch (e) {
      print('Sync: 获取远程笔记列表失败: $e');
    }

    return remoteNotes;
  }

  int _plannedOperationCount(
    List<Note> localNotes,
    Map<String, RemoteNoteInfo> remoteNotes,
  ) {
    final localUuids = localNotes.map((n) => n.uuid).toSet();
    int n = 0;

    for (final note in localNotes) {
      if (!remoteNotes.containsKey(note.uuid)) {
        if (!note.isDeleted) n++;
      }
    }
    for (final note in localNotes) {
      if (remoteNotes.containsKey(note.uuid)) {
        n++;
      }
    }
    for (final uuid in remoteNotes.keys) {
      if (!localUuids.contains(uuid)) {
        n++;
      }
    }
    for (final note in localNotes) {
      if (!remoteNotes.containsKey(note.uuid) && note.isDeleted) {
        n++;
      }
    }

    return n < 1 ? 1 : n;
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
          print('Sync: 本地笔记已删除，跳过上传 ${localNote.uuid}');
          continue;
        }
        print('Sync: 新增笔记 ${localNote.uuid}');
        final result = await _singleNoteSync.syncNote(localNote.uuid);
        _bump(noteTitle: localNote.title);
        if (!result.isSuccess) {
          print('Sync: 笔记同步失败 ${localNote.uuid}: ${result.message}');
          errors.add('${localNote.uuid}: ${result.message}');
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
            print('Sync: 本地版本较新，恢复笔记 ${localNote.uuid}');
            final result = await _singleNoteSync.syncNote(localNote.uuid, forceSync: true);
            if (!result.isSuccess) {
              errors.add('${localNote.uuid}: ${result.message}');
            }
            break;
          case ConflictResolution.useRemote:
            print('Sync: 远程已删除，删除本地笔记 ${localNote.uuid}');
            await _deleteLocalNote(localNote.uuid);
            break;
          case ConflictResolution.noConflict:
            if (await _needsSync(localNote, remoteNote)) {
              print('Sync: 修改笔记 ${localNote.uuid}');
              final result = await _singleNoteSync.syncNote(
                localNote.uuid,
                preloadedRemote: remoteNote,
                forceSync: true,
              );
              if (!result.isSuccess) {
                errors.add('${localNote.uuid}: ${result.message}');
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
          print('Sync: 远程笔记已删除，跳过下载 $noteUuid');
          _bump(noteTitle: remoteNote.title);
          continue;
        }
        print('Sync: 下载新笔记 $noteUuid');
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
          print('Sync: 清理本地已删除笔记 ${localNote.uuid}');
          await DB.instance.deletePermanently(localNote.uuid);
          _bump(noteTitle: localNote.title);
        }
      }
    }
  }

  Future<bool> _needsSync(Note localNote, Note remoteNote) async {
    if (localNote.syncStatus != 'synced') {
      return true;
    }
    return noteSyncContentHash(localNote) != noteSyncContentHash(remoteNote);
  }

  Future<void> _downloadNewNote(RemoteNoteInfo remoteInfo) async {
    try {
      final content = await _client.downloadString(remoteInfo.path);
      final noteMap = jsonDecode(content) as Map<String, dynamic>;

      final raw = Note.fromMap(noteMap);
      final note = await resolveWireNoteForDb(raw);

      await DB.instance.insert(note);

      await _singleNoteSync.syncNoteImages(note);

      await DB.instance.updateSyncStatus(note.uuid, 'synced');
      await DB.instance.updateSyncMeta(note.uuid, {
        'content_hash': noteSyncContentHash(note),
        'last_sync_at': DateTime.now().millisecondsSinceEpoch,
      });

      print('Sync: 下载新笔记成功 ${note.uuid}');
    } catch (e) {
      print('Sync: 下载新笔记失败 ${remoteInfo.uuid}: $e');
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
      print('Sync: 下载远程笔记失败 $remotePath: $e');
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
      print('Sync: 本地在远程删除后更新过，恢复笔记 ${localNote.uuid}');
      return ConflictResolution.useLocal;
    } else {
      print('Sync: 远程删除较新，应用删除 ${localNote.uuid}');
      return ConflictResolution.useRemote;
    }
  }

  Future<void> _deleteLocalNote(String uuid) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await DB.instance.update(
        {
          'isDeleted': 1,
          'deletedAt': now,
          'updatedAt': now,
          'syncStatus': 'synced',
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      print('Sync: 本地笔记已标记删除 $uuid');
    } catch (e) {
      print('Sync: 删除本地笔记失败 $uuid: $e');
    }
  }
}

/// 远程笔记信息
class RemoteNoteInfo {
  final String uuid;
  final String path;
  final int mTime;

  RemoteNoteInfo({
    required this.uuid,
    required this.path,
    required this.mTime,
  });
}

/// 冲突解决结果
enum ConflictResolution {
  useLocal,
  useRemote,
  noConflict,
}
