/// 远程侧一条笔记 JSON 的清单项（与 [RemoteIndexBuilder] 列举结果一致）
class RemoteNoteInfo {
  const RemoteNoteInfo({
    required this.uuid,
    required this.path,
    required this.mTime,
  });

  final String uuid;
  final String path;
  final int mTime;
}
