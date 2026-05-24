import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/note.dart';
import 'note_download_merge.dart' show mergeArchivedWhenLocalUploadWins, mergeDeletedAtFields;
import 'note_sync_hash.dart';
import '../../dao/db.dart';
import '../services/sync_client_base.dart';

/// 冲突解决策略
enum ConflictResolution {
  useLocal,      // 使用本地版本
  useRemote,     // 使用远程版本
  merge,         // 合并版本
  createCopy,    // 创建冲突副本
}

/// 冲突详情
class ConflictDetails {
  final Note localNote;
  final Note remoteNote;
  final int localModTime;
  final int remoteModTime;

  ConflictDetails({
    required this.localNote,
    required this.remoteNote,
    required this.localModTime,
    required this.remoteModTime,
  });
}

/// 冲突处理器
class ConflictResolver {
  final SyncClientBase _client;

  ConflictResolver(this._client);

  /// 检测冲突
  Future<ConflictDetails?> detectConflict(String noteUuid) async {
    // 获取本地笔记
    final localNote = await DB.instance.queryNoteByUuid(noteUuid);
    if (localNote == null) return null;

    final remotePath = _getNoteRemotePath(noteUuid);
    final remoteContent = await _client.tryDownloadStringOrNull(remotePath);
    if (remoteContent == null) return null;

    final remoteNote = Note.fromMap(jsonDecode(remoteContent));

    if (noteSyncContentHash(localNote) == noteSyncContentHash(remoteNote)) {
      return null;
    }

    return ConflictDetails(
      localNote: localNote,
      remoteNote: remoteNote,
      localModTime: localNote.updatedAt,
      remoteModTime: remoteNote.updatedAt,
    );
  }

  /// 解决冲突
  Future<Note> resolveConflict(
    ConflictDetails details,
    ConflictResolution resolution,
  ) async {
    switch (resolution) {
      case ConflictResolution.useLocal:
        return mergeArchivedWhenLocalUploadWins(
          details.localNote,
          details.remoteNote,
        );
      case ConflictResolution.useRemote:
        return details.remoteNote;
      case ConflictResolution.merge:
        return await _mergeNotes(details.localNote, details.remoteNote);
      case ConflictResolution.createCopy:
        await _createConflictCopy(details);
        return details.localNote; // 保留本地版本，创建远程副本
    }
  }

  /// 自动解决冲突
  Future<Note> autoResolveConflict(ConflictDetails details) async {
    // 时间戳优先策略
    if (details.localModTime > details.remoteModTime) {
      return details.localNote;
    } else {
      return details.remoteNote;
    }
  }

  /// 合并笔记
  Future<Note> _mergeNotes(Note local, Note remote) async {
    // 简单的合并策略：保留较新的内容，合并标题
    final mergedContent = local.updatedAt > remote.updatedAt
        ? local.deltaContent
        : remote.deltaContent;

    final mergedTitle = local.title.isNotEmpty ? local.title : remote.title;
    final mergedIsDeleted = local.isDeleted || remote.isDeleted;
    final mergedDeletedAt =
        mergedIsDeleted ? mergeDeletedAtFields(local, remote) : null;

    return Note(
      uuid: local.uuid,
      title: mergedTitle,
      content: local.content.isNotEmpty ? local.content : remote.content,
      deltaContent: mergedContent,
      createdAt: local.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      archived: local.archived || remote.archived,
      categoryId: local.categoryId ?? remote.categoryId,
      categoryUuid: local.categoryUuid ?? remote.categoryUuid,
      syncStatus: 'pending_upload',
      isDeleted: mergedIsDeleted,
      deletedAt: mergedDeletedAt,
    );
  }

  /// 创建冲突副本
  Future<void> _createConflictCopy(ConflictDetails details) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final conflictDir = 'benny/data/conflicts/${details.localNote.uuid}';

    // 确保冲突目录存在
    await _client.mkdirAll(conflictDir);

    // 保存本地版本
    final localPath = '$conflictDir/${timestamp}_local.json';
    await _client.uploadString(
      jsonEncode(details.localNote.toJsonMap()),
      localPath,
    );

    // 保存远程版本
    final remotePath = '$conflictDir/${timestamp}_remote.json';
    await _client.uploadString(
      jsonEncode(details.remoteNote.toJsonMap()),
      remotePath,
    );
  }

  /// 显示冲突解决对话框
  Future<ConflictResolution?> showConflictDialog(
    BuildContext context,
    ConflictDetails details,
  ) async {
    return showDialog<ConflictResolution>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('同步冲突'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('笔记 "${details.localNote.title}" 存在冲突'),
            const SizedBox(height: 16),
            Text('本地修改时间: ${_formatTime(details.localModTime)}'),
            Text('远程修改时间: ${_formatTime(details.remoteModTime)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ConflictResolution.useLocal),
            child: const Text('使用本地版本'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ConflictResolution.useRemote),
            child: const Text('使用远程版本'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ConflictResolution.merge),
            child: const Text('合并版本'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ConflictResolution.createCopy),
            child: const Text('创建副本'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 格式化时间
  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 获取笔记的远程路径
  String _getNoteRemotePath(String uuid) {
    final shard = uuid.substring(0, 2).toLowerCase();
    return 'benny/data/notes/$shard/$uuid.json';
  }
}
