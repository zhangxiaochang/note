import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../domain/note.dart';
import '../../dao/db.dart';
import '../../utils/uuid_generator.dart';
import '../../utils/image_path_resolver.dart';
import '../models/sync_state.dart';
import '../utils/conflict_resolver.dart';
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

  /// 同步单条笔记
  Future<SyncResult> syncNote(String noteUuid) async {
    try {
      print('Sync: 开始同步笔记 $noteUuid');

      // 1. 获取本地笔记
      final note = await DB.instance.queryNoteByUuid(noteUuid);
      if (note == null) {
        return SyncResult.failure('笔记不存在', SyncFailureType.unknown);
      }

      // 2. 检查是否需要同步
      if (!await _needsSync(note)) {
        return SyncResult.success('笔记无需同步');
      }

      // 3. 检测冲突
      final conflict = await _detectConflict(note);
      if (conflict.exists) {
        // 处理冲突
        await _handleConflict(conflict.localNote!, conflict.remoteNote!);
        return SyncResult.success('冲突已解决');
      }

      // 4. 执行同步
      final syncResult = await _syncNote(note);
      if (!syncResult.isSuccess) {
        return syncResult;
      }

      // 5. 同步笔记中的图片
      await syncNoteImages(note);

      // 6. 更新同步状态
      await _updateSyncStatus(noteUuid, 'synced');

      print('Sync: 笔记同步完成');
      return SyncResult.success('笔记同步成功');
    } catch (e) {
      print('Sync: 笔记同步失败: $e');
      return SyncResult.failure('同步失败: $e', SyncFailureType.unknown);
    }
  }

  /// 检查笔记是否需要同步
  Future<bool> _needsSync(Note note) async {
    // 如果本地标记为未同步，肯定需要同步
    if (note.syncStatus != 'synced') {
      return true;
    }
    
    // 即使本地标记为已同步，也要检查远程文件是否存在
    // 处理远程被删除但本地仍显示已同步的情况
    final remotePath = _getNoteRemotePath(note.uuid);
    final remoteFile = await _client.readProps(remotePath);
    if (remoteFile == null) {
      // 远程文件不存在，需要重新上传
      print('Sync: 远程文件不存在，需要重新上传 ${note.uuid}');
      return true;
    }
    
    return false;
  }

  /// 检测冲突
  Future<SyncConflict> _detectConflict(Note note) async {
    final remotePath = _getNoteRemotePath(note.uuid);
    
    // 检查远程文件是否存在
    final remoteFile = await _client.readProps(remotePath);
    if (remoteFile == null) {
      return SyncConflict(false, null, null);
    }

    // 获取远程笔记
    final remoteContent = await _client.downloadString(remotePath);
    final remoteNote = Note.fromMap(jsonDecode(remoteContent));

    // 检查时间戳
    final hasConflict = note.updatedAt != remoteNote.updatedAt;
    return SyncConflict(hasConflict, note, remoteNote);
  }

  /// 处理冲突
  Future<void> _handleConflict(Note local, Note remote) async {
    final details = ConflictDetails(
      localNote: local,
      remoteNote: remote,
      localModTime: local.updatedAt,
      remoteModTime: remote.updatedAt,
    );

    ConflictResolution resolution;
    if (_context != null && _context!.mounted) {
      // 显示冲突解决对话框
      final userChoice = await _conflictResolver.showConflictDialog(_context!, details);
      if (userChoice == null) {
        throw Exception('用户取消冲突解决');
      }
      resolution = userChoice;
    } else {
      // 无上下文，自动解决
      resolution = ConflictResolution.useLocal;
    }

    // 解决冲突
    final resolvedNote = await _conflictResolver.resolveConflict(details, resolution);

    // 根据解决结果执行操作
    if (resolution == ConflictResolution.useLocal || resolution == ConflictResolution.merge) {
      // 上传解决后的笔记
      await _uploadNote(resolvedNote);
    } else if (resolution == ConflictResolution.useRemote) {
      // 下载远程笔记
      await _downloadNote(resolvedNote);
    }
  }

  /// 同步笔记
  Future<SyncResult> _syncNote(Note note) async {
    // 检查远程文件是否存在
    final remotePath = _getNoteRemotePath(note.uuid);
    final remoteFile = await _client.readProps(remotePath);

    if (remoteFile == null) {
      // 远程不存在，上传
      return await _uploadNote(note);
    } else {
      // 远程存在，检查时间戳
      final remoteContent = await _client.downloadString(remotePath);
      final remoteNote = Note.fromMap(jsonDecode(remoteContent));

      if (note.updatedAt > remoteNote.updatedAt) {
        // 本地较新，上传
        return await _uploadNote(note);
      } else {
        // 远程较新，下载
        return await _downloadNote(remoteNote);
      }
    }
  }

  /// 上传笔记
  Future<SyncResult> _uploadNote(Note note) async {
    try {
      final remotePath = _getNoteRemotePath(note.uuid);
      
      // 确保远程目录存在
      await _ensureRemoteDir(note.uuid);
      
      // 上传笔记
      final jsonContent = jsonEncode(note.toJsonMap());
      await _client.uploadString(jsonContent, remotePath);
      
      print('Sync: 笔记上传成功 ${note.uuid}');
      return SyncResult.success('笔记上传成功');
    } catch (e) {
      print('Sync: 笔记上传失败: $e');
      return SyncResult.failure('上传失败: $e', SyncFailureType.networkError);
    }
  }

  /// 下载笔记
  Future<SyncResult> _downloadNote(Note remoteNote) async {
    try {
      // 保存到本地数据库
      await DB.instance.update(remoteNote.toDbMap(), where: 'uuid = ?', whereArgs: [remoteNote.uuid]);
      
      // 更新同步状态
      await _updateSyncStatus(remoteNote.uuid, 'synced');
      
      print('Sync: 笔记下载成功 ${remoteNote.uuid}');
      return SyncResult.success('笔记下载成功');
    } catch (e) {
      print('Sync: 笔记下载失败: $e');
      return SyncResult.failure('下载失败: $e', SyncFailureType.unknown);
    }
  }

  /// 同步笔记中的图片
  Future<void> syncNoteImages(Note note) async {
    // 提取笔记中的图片路径
    final images = _extractImagesFromDelta(note.deltaContent);
    
    for (final imagePath in images) {
      await _syncImage(imagePath);
    }
  }

  /// 同步单张图片
  Future<void> _syncImage(String relativePath) async {
    try {
      // 获取绝对路径
      final absolutePath = await ImagePathResolver.toAbsolutePath(relativePath);
      print('Sync: 图片绝对路径 $absolutePath');
      
      final imageFile = File(absolutePath);
      
      if (!await imageFile.exists()) {
        print('Sync: 图片不存在 $relativePath (绝对路径: $absolutePath)');
        return;
      }
      
      // 检查文件是否可以读取
      try {
        final length = await imageFile.length();
        print('Sync: 图片大小 $length bytes');
      } catch (e) {
        print('Sync: 无法读取图片文件 $relativePath: $e');
        return;
      }
      
      // 构建远程路径
      final remotePath = 'benny/notes/images/$relativePath';
      
      // 确保远程目录存在
      final dirPath = path.dirname(remotePath);
      await _client.mkdirAll(dirPath);
      
      // 上传图片
      await _client.uploadFile(absolutePath, remotePath);
      print('Sync: 图片上传成功 $relativePath');
    } catch (e) {
      print('Sync: 图片同步失败 $relativePath: $e');
    }
  }

  /// 提取笔记中的图片路径
  List<String> _extractImagesFromDelta(List<dynamic>? delta) {
    final images = <String>[];
    if (delta == null) return images;
    
    for (final op in delta) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        if (insert is Map && insert.containsKey('image')) {
          final imagePath = insert['image'];
          if (imagePath is String) {
            images.add(imagePath);
          }
        }
      }
    }
    return images;
  }

  /// 获取笔记的远程路径
  String _getNoteRemotePath(String uuid) {
    final shard = UuidGenerator.getDirectoryShard(uuid);
    return 'benny/notes/$shard/$uuid.json';
  }

  /// 确保远程目录存在
  Future<void> _ensureRemoteDir(String uuid) async {
    final shard = UuidGenerator.getDirectoryShard(uuid);
    await _client.mkdirAll('benny/notes/$shard');
  }

  /// 更新同步状态
  Future<void> _updateSyncStatus(String noteUuid, String status) async {
    await DB.instance.updateSyncStatus(noteUuid, status);
    await DB.instance.updateSyncMeta(noteUuid, {
      'sync_status': status,
      'last_sync_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}

/// 同步冲突
class SyncConflict {
  final bool exists;
  final Note? localNote;
  final Note? remoteNote;

  SyncConflict(this.exists, this.localNote, this.remoteNote);
}
