import 'dart:io';
import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../models/remote_file.dart';
import 'sync_client_base.dart';

/// WebDAV 客户端实现
/// 基于 webdav_client 包封装
class WebdavClient extends SyncClientBase {
  late final String _url;
  late final String _username;
  late final String _password;
  webdav.Client? _client;

  WebdavClient({
    required String url,
    required String username,
    required String password,
  }) {
    _url = url;
    _username = username;
    _password = password;
    _initClient();
  }

  /// 初始化 WebDAV 客户端
  void _initClient() {
    if (_url.isNotEmpty && _username.isNotEmpty && _password.isNotEmpty) {
      _client = webdav.newClient(
        _url,
        user: _username,
        password: _password,
        debug: false,
      );

      // 配置 Dio 拦截器以设置默认 Content-Type
      // webdav_client 包的 Client 类有一个 `c` 属性暴露 Dio 实例
      try {
        final dio = (_client as dynamic).c as Dio;
        dio.interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) {
            // 如果没有设置 Content-Type，默认设置为 application/octet-stream
            if (options.contentType == null && options.data is List<int>) {
              options.contentType = 'application/octet-stream';
            }
            handler.next(options);
          },
        ));
      } catch (e) {
        // 如果无法访问 Dio 实例，忽略错误
      }
    }
  }

  /// 获取客户端实例，如果未初始化则抛出异常
  webdav.Client get _requireClient {
    if (_client == null) {
      throw Exception('WebDAV client not initialized. Please check your configuration.');
    }
    return _client!;
  }

  /// 规范化路径，确保格式正确
  String _normalizePath(String path, {bool isDir = false}) {
    // 确保路径以 / 开头
    String normalized = path.startsWith('/') ? path : '/$path';
    // 移除多余的双斜杠
    normalized = normalized.replaceAll(RegExp(r'/+'), '/');
    // 如果是目录，确保以 / 结尾
    if (isDir && !normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    // 对路径进行 URL 编码，处理中文字符等特殊字符
    // 使用 encodeFull 而不是 encodeComponent，保留 / 作为分隔符
    return Uri.encodeFull(normalized);
  }

  @override
  String get protocolName => 'WebDAV';

  @override
  Map<String, dynamic> get config => {
        'url': _url,
        'username': _username,
        'password': _password,
      };

  @override
  bool get isConfigured =>
      _url.isNotEmpty && _username.isNotEmpty && _password.isNotEmpty;

  @override
  void updateConfig(Map<String, dynamic> newConfig) {
    throw UnimplementedError('WebDAV config update not implemented. Please create a new client instance.');
  }

  @override
  Future<void> ping() async {
    // 尝试读取根目录来测试连接
    await _requireClient.ping();
  }

  @override
  Future<void> testFullCapabilities() async {
    const testDir = 'sync_demo/.test';
    const testFile = '$testDir/test.txt';

    try {
      // 1. 创建测试目录
      await mkdirAll(testDir);

      // 2. 创建本地测试文件
      final tempDir = Directory.systemTemp;
      final localTestFile =
          File('${tempDir.path}/webdav_test_${DateTime.now().millisecondsSinceEpoch}.txt');
      await localTestFile.writeAsString('WebDAV Test Content');

      // 3. 上传测试文件
      await uploadFile(localTestFile.path, testFile);

      // 4. 下载并验证
      final downloadedFile =
          File('${tempDir.path}/webdav_download_test_${DateTime.now().millisecondsSinceEpoch}.txt');
      await downloadFile(testFile, downloadedFile.path);

      final content = await downloadedFile.readAsString();
      if (content != 'WebDAV Test Content') {
        throw Exception('Content mismatch');
      }

      // 5. 清理
      // await remove(testFile);
      // await remove(testDir);
      // await localTestFile.delete();
      // await downloadedFile.delete();
    } catch (e) {
      throw Exception('WebDAV capability test failed: $e');
    }
  }

  @override
  Future<void> mkdirAll(String path) async {
    final normalizedPath = _normalizePath(path, isDir: true);
    await _requireClient.mkdirAll(normalizedPath);
  }

  @override
  Future<List<RemoteFile>> readDir(String path) async {
    final normalizedPath = _normalizePath(path, isDir: true);
    final files = await _requireClient.readDir(normalizedPath);

    return files.map((file) => RemoteFile(
      path: file.path,
      isDir: file.isDir,
      name: file.name,
      mimeType: file.mimeType,
      size: file.size,
      eTag: file.eTag,
      cTime: file.cTime,
      mTime: file.mTime,
    )).toList();
  }

  @override
  Future<RemoteFile?> readProps(String path) async {
    final normalizedPath = _normalizePath(path);
    try {
      final file = await _requireClient.readProps(normalizedPath);

      return RemoteFile(
        path: file.path,
        isDir: file.isDir,
        name: file.name,
        mimeType: file.mimeType,
        size: file.size,
        eTag: file.eTag,
        cTime: file.cTime,
        mTime: file.mTime,
      );
    } catch (e) {
      // 文件不存在或其他错误时返回 null
      return null;
    }
  }

  @override
  Future<void> remove(String path) async {
    final normalizedPath = _normalizePath(path);
    await _requireClient.remove(normalizedPath);
  }

  @override
  Future<bool> isExist(String path) async {
    final props = await readProps(path);
    return props != null;
  }

  @override
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    bool replace = true,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Local file not found: $localPath');
    }

    final normalizedRemotePath = _normalizePath(remotePath);
    
    final bytes = await file.readAsBytes();
    final total = bytes.length;
    
    // 如果提供了进度回调，包装一个进度监听器
    if (onProgress != null) {
      onProgress(0, total);
    }
    
    // 使用 write 方法上传字节数据
    await _requireClient.write(normalizedRemotePath, bytes);
    
    if (onProgress != null) {
      onProgress(total, total);
    }
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final normalizedRemotePath = _normalizePath(remotePath);

    if (onProgress != null) {
      onProgress(0, 0);
    }

    // 读取远程文件内容
    final bytes = await _requireClient.read(normalizedRemotePath);

    // 创建本地文件
    final file = File(localPath);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);

    if (onProgress != null) {
      onProgress(bytes.length, bytes.length);
    }
  }

  @override
  Future<List<RemoteFile>> safeReadDir(String path) async {
    if (!await isExist(path)) {
      await mkdirAll(path);
    }
    return readDir(path);
  }
}
