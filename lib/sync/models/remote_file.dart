/// 远程文件模型
/// 用于表示服务器上的文件或目录信息
class RemoteFile {
  final String? path;
  final bool? isDir;
  final String? name;
  final String? mimeType;
  final int? size;
  final String? eTag;
  final DateTime? cTime; // 创建时间
  final DateTime? mTime; // 修改时间

  RemoteFile({
    this.path,
    this.isDir,
    this.name,
    this.mimeType,
    this.size,
    this.eTag,
    this.cTime,
    this.mTime,
  });

  @override
  String toString() {
    return 'RemoteFile(name: $name, isDir: $isDir, size: $size, mTime: $mTime)';
  }
}
