import '../models/remote_file.dart';

/// 同步客户端抽象基类
/// 定义了所有同步客户端必须实现的接口
abstract class SyncClientBase {
  /// 测试服务器连接
  Future<void> ping();

  /// 测试完整功能（创建、上传、下载、删除）
  Future<void> testFullCapabilities();

  /// 创建目录（递归创建所有父目录）
  Future<void> mkdirAll(String path);

  /// 列出目录内容
  Future<List<RemoteFile>> readDir(String path);

  /// 删除文件或目录
  Future<void> remove(String path);

  /// 检查文件或目录是否存在
  Future<bool> isExist(String path);

  /// 上传文件
  /// [localPath] 本地文件路径
  /// [remotePath] 远程文件路径
  /// [replace] 是否替换已存在的文件
  /// [onProgress] 进度回调 (已发送字节, 总字节)
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    bool replace = true,
    void Function(int sent, int total)? onProgress,
  });

  /// 下载文件
  /// [remotePath] 远程文件路径
  /// [localPath] 本地文件路径
  /// [onProgress] 进度回调 (已接收字节, 总字节)
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int received, int total)? onProgress,
  });

  /// 安全读取目录（如果不存在则创建）
  Future<List<RemoteFile>> safeReadDir(String path);

  /// 读取文件属性
  Future<RemoteFile?> readProps(String path);

  /// 协议名称
  String get protocolName;

  /// 当前配置
  Map<String, dynamic> get config;

  /// 更新配置
  void updateConfig(Map<String, dynamic> newConfig);

  /// 是否已配置
  bool get isConfigured;
}
