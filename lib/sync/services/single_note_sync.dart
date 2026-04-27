import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../../domain/note.dart';
import '../../dao/db.dart';
import '../../dao/sync_item_dao.dart';
import '../models/sync_item_vocabulary.dart';
import '../../utils/quill_image_paths.dart';
import '../../utils/uuid_generator.dart';
import '../../utils/image_path_resolver.dart';
import '../models/sync_state.dart';
import '../utils/conflict_resolver.dart';
import '../utils/note_sync_hash.dart';
import '../utils/note_wire_resolve.dart';
import 'sync_client_base.dart';

/// 单笔记同步服务
class SingleNoteSync {
  final SyncClientBase _client;
  final ConflictResolver _conflictResolver;
  BuildContext? _context;

  SingleNoteSync(this._client) : _conflictResolver = ConflictResolver(_client);

  /// 设置上下文（用于显示冲突解决对话框）
  void setContext(BuildContext context) {
    _context = context;
  }

  /// [preloadedRemote] 若已下载可避免重复 GET；[forceSync] 为 true 时跳过「已同步且远程存在则跳过」逻辑（供增量同步在内容指纹不一致时调用）
  Future<SyncResult> syncNote(
    String noteUuid, {
    Note? preloadedRemote,
    bool forceSync = false,
  }) async {
    try {
      print('Sync: 开始同步笔记 $noteUuid');

      final note = await DB.instance.queryNoteByUuid(noteUuid);
      if (note == null) {
        return SyncResult.failure('笔记不存在', SyncFailureType.unknown);
      }

      if (!forceSync && !await _needsSync(note)) {
        return SyncResult.success('笔记无需同步');
      }

      final conflict = await _detectConflict(note, preloadedRemote: preloadedRemote);
      if (conflict.exists) {
        await _handleConflict(conflict.localNote!, conflict.remoteNote!);
        final fresh = await DB.instance.queryNoteByUuid(noteUuid);
        if (fresh != null) {
          await _updateSyncStatus(noteUuid, 'synced', noteForHash: fresh);
        }
        return SyncResult.success('冲突已解决');
      }

      final syncResult = await _syncNote(note, preloadedRemote: preloadedRemote);
      if (!syncResult.isSuccess) {
        return syncResult;
      }

      final after = await DB.instance.queryNoteByUuid(noteUuid);
      if (after != null) {
        await syncNoteImages(after);
        await _updateSyncStatus(noteUuid, 'synced', noteForHash: after);
      }

      print('Sync: 笔记同步完成');
      return SyncResult.success('笔记同步成功');
    } catch (e) {
      print('Sync: 笔记同步失败: $e');
      return SyncResult.failure('同步失败: $e', SyncFailureType.unknown);
    }
  }

  /// 以 [sync_items] 为主；[Note.syncStatus] 与「远端无文件」为辅助
  Future<bool> _needsSync(Note note) async {
    final row = await SyncItemDao.instance.get(SyncItemType.note, note.uuid);
    if (row == null) {
      return _legacyNeedsSync(note);
    }
    if (row.syncStatus == SyncItemStatus.dirtyLocal ||
        row.syncStatus == SyncItemStatus.conflict ||
        row.syncStatus == SyncItemStatus.pendingRemote) {
      return true;
    }
    if (row.syncStatus == SyncItemStatus.clean) {
      if (note.syncStatus != 'synced') {
        return true;
      }
      return _remotePropsMissingForUpload(note.uuid);
    }
    return _legacyNeedsSync(note);
  }

  Future<bool> _legacyNeedsSync(Note note) async {
    if (note.syncStatus != 'synced') {
      return true;
    }
    return _remotePropsMissingForUpload(note.uuid);
  }

  /// 有 [sync_items] 且为 clean 时：仍需确认远端存在（避免只有本地以为已同步）
  Future<bool> _remotePropsMissingForUpload(String uuid) async {
    final remotePath = _getNoteRemotePath(uuid);
    final remoteFile = await _client.readProps(remotePath);
    if (remoteFile == null) {
      // ignore: avoid_print
      print('Sync: 远程文件不存在，需要重新上传 $uuid');
      return true;
    }
    return false;
  }

  Future<SyncConflict> _detectConflict(Note note, {Note? preloadedRemote}) async {
    final remotePath = _getNoteRemotePath(note.uuid);
    final remoteFile = await _client.readProps(remotePath);
    if (remoteFile == null) {
      return SyncConflict(false, null, null);
    }

    final remoteNote = preloadedRemote ??
        Note.fromMap(jsonDecode(await _client.downloadString(remotePath)));

    final hasConflict =
        noteSyncContentHash(note) != noteSyncContentHash(remoteNote);
    return SyncConflict(hasConflict, note, remoteNote);
  }

  Future<void> _handleConflict(Note local, Note remote) async {
    final details = ConflictDetails(
      localNote: local,
      remoteNote: remote,
      localModTime: local.updatedAt,
      remoteModTime: remote.updatedAt,
    );

    ConflictResolution resolution;
    if (_context != null && _context!.mounted) {
      final userChoice = await _conflictResolver.showConflictDialog(_context!, details);
      if (userChoice == null) {
        throw Exception('用户取消冲突解决');
      }
      resolution = userChoice;
    } else {
      resolution = ConflictResolution.useLocal;
    }

    final resolvedNote = await _conflictResolver.resolveConflict(details, resolution);

    if (resolution == ConflictResolution.useLocal || resolution == ConflictResolution.merge) {
      await _uploadNote(resolvedNote);
    } else if (resolution == ConflictResolution.useRemote) {
      await _downloadNote(resolvedNote);
    }
  }

  Future<SyncResult> _syncNote(Note note, {Note? preloadedRemote}) async {
    final remotePath = _getNoteRemotePath(note.uuid);
    final remoteFile = await _client.readProps(remotePath);

    if (remoteFile == null) {
      return await _uploadNote(note);
    }

    final remoteNote = preloadedRemote ??
        Note.fromMap(jsonDecode(await _client.downloadString(remotePath)));

    if (note.updatedAt > remoteNote.updatedAt) {
      return await _uploadNote(note);
    }
    if (note.updatedAt < remoteNote.updatedAt) {
      return await _downloadNote(remoteNote);
    }
    // 时间戳相同：以内容指纹为准
    if (noteSyncContentHash(note) != noteSyncContentHash(remoteNote)) {
      return await _uploadNote(note);
    }
    return SyncResult.success('笔记已一致');
  }

  Future<SyncResult> _uploadNote(Note note) async {
    try {
      final remotePath = _getNoteRemotePath(note.uuid);
      await _ensureRemoteDir(note.uuid);
      final toSend = await ensureNoteHasCategoryUuidForUpload(note);
      final jsonContent = jsonEncode(toSend.toSyncWireJsonMap());
      await _client.uploadString(jsonContent, remotePath);
      print('Sync: 笔记上传成功 ${note.uuid}');
      return SyncResult.success('笔记上传成功');
    } catch (e) {
      print('Sync: 笔记上传失败: $e');
      return SyncResult.failure('上传失败: $e', SyncFailureType.networkError);
    }
  }

  Future<SyncResult> _downloadNote(Note remoteNote) async {
    try {
      final resolved = await resolveWireNoteForDb(remoteNote);
      await _downloadNoteImages(resolved);
      await DB.instance.update(
        resolved.toDbMap(),
        where: 'uuid = ?',
        whereArgs: [resolved.uuid],
      );
      print('Sync: 笔记下载成功 ${resolved.uuid}');
      return SyncResult.success('笔记下载成功');
    } catch (e) {
      print('Sync: 笔记下载失败: $e');
      return SyncResult.failure('下载失败: $e', SyncFailureType.unknown);
    }
  }

  Future<void> _downloadNoteImages(Note note) async {
    final images = extractImagePathsFromQuillDelta(note.deltaContent);
    for (final imagePath in images) {
      await _downloadImage(imagePath);
    }
  }

  Future<void> _downloadImage(String relativePath) async {
    final trimmed = relativePath.trim();
    if (trimmed.isEmpty) return;
    if (ImagePathResolver.isWebUrl(trimmed)) {
      return;
    }
    try {
      final absolutePath = await ImagePathResolver.toAbsolutePath(trimmed);
      if (ImagePathResolver.isWebUrl(absolutePath)) {
        return;
      }
      final localFile = File(absolutePath);
      if (await localFile.exists()) {
        final len = await localFile.length();
        if (len > 0) {
          print('Sync: 图片已存在，跳过下载 $trimmed');
          return;
        }
        await localFile.delete();
      }

      final localDir = path.dirname(absolutePath);
      await Directory(localDir).create(recursive: true);

      final fileName = path.basename(trimmed);
      final remotePath = 'benny/images/$fileName';

      print('Sync: 下载图片 $remotePath -> $absolutePath');
      await _client.downloadFile(remotePath, absolutePath);
      print('Sync: 图片下载成功 $trimmed');
    } catch (e) {
      print('Sync: 图片下载失败 $trimmed: $e');
    }
  }

  Future<void> syncNoteImages(Note note) async {
    final images = extractImagePathsFromQuillDelta(note.deltaContent);
    for (final imagePath in images) {
      await _syncImage(imagePath);
    }
  }

  Future<void> _syncImage(String relativePath) async {
    final trimmed = relativePath.trim();
    if (trimmed.isEmpty) return;
    if (ImagePathResolver.isWebUrl(trimmed)) {
      return;
    }
    try {
      final absolutePath = await ImagePathResolver.toAbsolutePath(trimmed);
      if (ImagePathResolver.isWebUrl(absolutePath)) {
        return;
      }
      final imageFile = File(absolutePath);
      if (!await imageFile.exists()) {
        print('Sync: 图片不存在 $trimmed');
        return;
      }

      final fileName = path.basename(trimmed);
      final remotePath = 'benny/images/$fileName';
      await _client.mkdirAll('benny/images');
      await _client.uploadFile(absolutePath, remotePath);
      print('Sync: 图片上传成功 $trimmed');
    } catch (e) {
      print('Sync: 图片同步失败 $trimmed: $e');
    }
  }

  String _getNoteRemotePath(String uuid) {
    final shard = UuidGenerator.getDirectoryShard(uuid);
    return 'benny/notes/$shard/$uuid.json';
  }

  Future<void> _ensureRemoteDir(String uuid) async {
    final shard = UuidGenerator.getDirectoryShard(uuid);
    await _client.mkdirAll('benny/notes/$shard');
  }

  Future<void> _updateSyncStatus(
    String noteUuid,
    String status, {
    required Note noteForHash,
  }) async {
    await DB.instance.updateSyncStatus(noteUuid, status);
    await DB.instance.updateSyncMeta(noteUuid, {
      'sync_status': status,
      'last_sync_at': DateTime.now().millisecondsSinceEpoch,
      'content_hash': noteSyncContentHash(noteForHash),
    });
    await SyncItemDao.instance.markNoteInSync(noteForHash);
  }
}

class SyncConflict {
  final bool exists;
  final Note? localNote;
  final Note? remoteNote;

  SyncConflict(this.exists, this.localNote, this.remoteNote);
}
