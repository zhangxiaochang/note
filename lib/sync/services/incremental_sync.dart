import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../domain/note.dart';
import '../../dao/db.dart';
import '../../utils/uuid_generator.dart';
import '../../utils/image_path_resolver.dart';
import '../models/sync_state.dart';
import 'sync_client_base.dart';
import 'single_note_sync.dart';

/// 增量同步服务
class IncrementalSync {
  final SyncClientBase _client;
  final SingleNoteSync _singleNoteSync;

  IncrementalSync(this._client) : _singleNoteSync = SingleNoteSync(_client);

  /// 执行增量同步
  Future<SyncResult> sync() async {
    try {
      print('Sync: 开始增量同步');

      // 1. 获取需要同步的本地笔记
      final localNotes = await _getLocalNotesToSync();
      print('Sync: 本地笔记数量: ${localNotes.length}');

      // 2. 获取远程笔记列表
      final remoteNotes = await _getRemoteNotes();
      print('Sync: 远程笔记数量: ${remoteNotes.length}');

      // 3. 检测新增和修改的笔记
      final syncErrors = await _syncChangedNotes(localNotes, remoteNotes);

      // 4. 检测删除的笔记
      await _syncDeletedNotes(localNotes, remoteNotes);

      // 5. 更新全局同步状态
      await _updateGlobalSyncState();

      print('Sync: 增量同步完成');
      
      if (syncErrors.isNotEmpty) {
        return SyncResult.failure(
          '部分笔记同步失败: ${syncErrors.join(', ')}',
          SyncFailureType.unknown,
        );
      }
      
      return SyncResult.success('增量同步成功完成');
    } catch (e) {
      print('Sync: 增量同步失败: $e');
      return SyncResult.failure('同步失败: $e', SyncFailureType.unknown);
    }
  }

  /// 获取本地需要同步的笔记
  Future<List<Note>> _getLocalNotesToSync() async {
    // 获取所有笔记（包括已同步的，用于检测远程被删除的情况）
    final allNotes = await DB.instance.queryAll();
    
    // 返回所有笔记，让 _syncChangedNotes 决定哪些需要同步
    return allNotes;
  }

  /// 获取远程笔记列表
  Future<Map<String, RemoteNoteInfo>> _getRemoteNotes() async {
    final remoteNotes = <String, RemoteNoteInfo>{};
    
    try {
      // 获取所有分片目录
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

  /// 同步变化的笔记
  Future<List<String>> _syncChangedNotes(
    List<Note> localNotes,
    Map<String, RemoteNoteInfo> remoteNotes,
  ) async {
    final errors = <String>[];
    
    // 1. 同步本地有但远程没有的笔记（新增或已删除）
    for (final localNote in localNotes) {
      if (!remoteNotes.containsKey(localNote.uuid)) {
        // 如果本地笔记已标记删除，不上传
        if (localNote.isDeleted) {
          print('Sync: 本地笔记已删除，跳过上传 ${localNote.uuid}');
          continue;
        }
        print('Sync: 新增笔记 ${localNote.uuid}');
        final result = await _singleNoteSync.syncNote(localNote.uuid);
        if (!result.isSuccess) {
          print('Sync: 笔记同步失败 ${localNote.uuid}: ${result.message}');
          errors.add('${localNote.uuid}: ${result.message}');
        }
      }
    }

    // 2. 同步本地和远程都有的笔记（修改或删除冲突）
    for (final localNote in localNotes) {
      if (remoteNotes.containsKey(localNote.uuid)) {
        final remoteInfo = remoteNotes[localNote.uuid]!;
        
        // 下载远程笔记检查 deletedAt
        final remoteNote = await _downloadRemoteNote(remoteInfo.path);
        if (remoteNote == null) continue;
        
        // 处理删除冲突
        final resolution = _resolveDeleteConflict(localNote, remoteNote);
        
        switch (resolution) {
          case ConflictResolution.useLocal:
            // 本地较新，上传本地版本（会覆盖远程的删除标记）
            print('Sync: 本地版本较新，恢复笔记 ${localNote.uuid}');
            final result = await _singleNoteSync.syncNote(localNote.uuid);
            if (!result.isSuccess) {
              errors.add('${localNote.uuid}: ${result.message}');
            }
            break;
          case ConflictResolution.useRemote:
            // 远程较新，应用删除到本地
            print('Sync: 远程已删除，删除本地笔记 ${localNote.uuid}');
            await _deleteLocalNote(localNote.uuid);
            break;
          case ConflictResolution.noConflict:
            // 正常同步
            if (await _needsSync(localNote, remoteInfo)) {
              print('Sync: 修改笔记 ${localNote.uuid}');
              final result = await _singleNoteSync.syncNote(localNote.uuid);
              if (!result.isSuccess) {
                errors.add('${localNote.uuid}: ${result.message}');
              }
            }
            break;
        }
      }
    }
    
    // 3. 同步远程有但本地没有的笔记（新下载）
    for (final entry in remoteNotes.entries) {
      final noteUuid = entry.key;
      final remoteInfo = entry.value;
      
      final localNote = await DB.instance.queryNoteByUuid(noteUuid);
      if (localNote == null) {
        // 下载前检查远程笔记是否已删除
        final remoteNote = await _downloadRemoteNote(remoteInfo.path);
        if (remoteNote != null && remoteNote.isDeleted) {
          print('Sync: 远程笔记已删除，跳过下载 $noteUuid');
          continue;
        }
        print('Sync: 下载新笔记 $noteUuid');
        await _downloadNewNote(remoteInfo);
      }
    }
    
    return errors;
  }

  /// 同步删除的笔记
  /// 注意：删除冲突处理已移到 _syncChangedNotes 中
  Future<void> _syncDeletedNotes(
    List<Note> localNotes,
    Map<String, RemoteNoteInfo> remoteNotes,
  ) async {
    // 本地有但远程没有的笔记，可能是远程被删除了
    // 这种情况已在 _syncChangedNotes 中处理
    // 这里只处理额外的清理逻辑（如清理本地已删除但远程从未同步过的笔记）
    for (final localNote in localNotes) {
      if (!remoteNotes.containsKey(localNote.uuid)) {
        if (localNote.isDeleted) {
          // 本地已删除且远程从未存在过，可以物理删除
          print('Sync: 清理本地已删除笔记 ${localNote.uuid}');
          await DB.instance.deletePermanently(localNote.uuid);
        }
      }
    }
  }

  /// 检查笔记是否需要同步
  Future<bool> _needsSync(Note localNote, RemoteNoteInfo remoteInfo) async {
    // 检查同步状态
    if (localNote.syncStatus != 'synced') {
      return true;
    }

    // 检查时间戳
    if (localNote.updatedAt > remoteInfo.mTime) {
      return true;
    }

    // 检查内容哈希（可选）
    final localHash = await _calculateNoteHash(localNote);
    final remoteHash = await _calculateRemoteNoteHash(remoteInfo.path);
    
    return localHash != remoteHash;
  }

  /// 下载新笔记
  Future<void> _downloadNewNote(RemoteNoteInfo remoteInfo) async {
    try {
      // 下载笔记内容
      final content = await _client.downloadString(remoteInfo.path);
      final noteMap = jsonDecode(content);
      
      // 创建笔记对象
      final note = Note.fromMap(noteMap);
      
      // 保存到本地
      await DB.instance.insert(note);
      
      // 同步笔记中的图片
      await _singleNoteSync.syncNoteImages(note);
      
      // 更新同步状态
      await DB.instance.updateSyncStatus(note.uuid, 'synced');
      
      print('Sync: 下载新笔记成功 ${note.uuid}');
    } catch (e) {
      print('Sync: 下载新笔记失败 ${remoteInfo.uuid}: $e');
    }
  }

  /// 计算笔记内容哈希
  Future<String> _calculateNoteHash(Note note) async {
    final content = jsonEncode(note.toJsonMap());
    return _calculateHash(content);
  }

  /// 计算远程笔记内容哈希
  Future<String> _calculateRemoteNoteHash(String remotePath) async {
    try {
      final content = await _client.downloadString(remotePath);
      return _calculateHash(content);
    } catch (e) {
      return '';
    }
  }

  /// 计算字符串哈希
  String _calculateHash(String input) {
    // 简单的哈希算法，实际项目中可以使用更复杂的算法
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash) + input.codeUnitAt(i);
      hash = hash & hash; // 转换为32位整数
    }
    return hash.toString();
  }

  /// 更新全局同步状态
  Future<void> _updateGlobalSyncState() async {
    // 保存同步时间
    final syncTime = DateTime.now().millisecondsSinceEpoch;
    
    // 可以将同步状态保存到数据库或文件中
    await DB.instance.updateSyncMeta('global', {
      'last_sync_at': syncTime,
    });
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
  useLocal,    // 使用本地版本
  useRemote,   // 使用远程版本
  noConflict,  // 无冲突
}

/// 扩展方法：处理删除冲突
extension IncrementalSyncExtension on IncrementalSync {
  /// 下载远程笔记
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

  /// 解决删除冲突
  /// 策略：比较本地 updatedAt 和远程 deletedAt
  ConflictResolution _resolveDeleteConflict(Note localNote, Note remoteNote) {
    // 如果远程没有标记删除，正常同步
    if (!remoteNote.isDeleted) {
      // 检查本地是否已删除
      if (localNote.isDeleted) {
        // 本地已删除，远程未删除，需要上传删除标记
        return ConflictResolution.useLocal;
      }
      return ConflictResolution.noConflict;
    }
    
    // 远程已删除，检查本地更新时间
    if (localNote.updatedAt > (remoteNote.deletedAt ?? 0)) {
      // 本地在远程删除后还更新过，恢复笔记
      print('Sync: 本地在远程删除后更新过，恢复笔记 ${localNote.uuid}');
      return ConflictResolution.useLocal;
    } else {
      // 本地在远程删除后没有更新，应用删除
      print('Sync: 远程删除较新，应用删除 ${localNote.uuid}');
      return ConflictResolution.useRemote;
    }
  }

  /// 删除本地笔记（逻辑删除）
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
