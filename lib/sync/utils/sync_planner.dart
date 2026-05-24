import '../../domain/note.dart';
import '../models/remote_note_info.dart';

/// 估算一轮增量同步的「可计数操作数」（用于进度条，与 Synchronizer 中循环一致）
int plannedSyncOperationCount(
  List<Note> localNotes,
  Map<String, RemoteNoteInfo> remoteNotes,
) {
  final localUuids = localNotes.map((n) => n.uuid).toSet();
  int n = 0;

  for (final note in localNotes) {
    // 含已删除：远端无文件时也要上传 tombstone，计入进度
    if (!remoteNotes.containsKey(note.uuid)) {
      n++;
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

  return n < 1 ? 1 : n;
}
