import 'dart:io';
import '../models/remote_file.dart';
import 'sync_client_base.dart';

/// WebDAV 客户端实现
/// 基于 webdav_client 包封装
class WebdavClient extends SyncClientBase {
  late final String _url;
  late final String _username;
  late final String _password;

  WebdavClient({
    required String url,
    required String username,
    required String password,
  }) {
    _url = url;
    _username = username;
    _password = password;
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
    // 实际实现中需要重新初始化客户端
    throw UnimplementedError('WebDAV config update not implemented in demo');
  }

  @override
  Future<void> ping() async {
    // 实际实现中调用 webdav_client 的 ping 方法
    // 这里模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 模拟随机失败（10% 概率）
    if (DateTime.now().millisecond % 10 == 0) {
      throw Exception('Connection timeout');
    }
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
      await remove(testFile);
      await localTestFile.delete();
      await downloadedFile.delete();
    } catch (e) {
      throw Exception('WebDAV capability test failed: $e');
    }
  }

  @override
  Future<void> mkdirAll(String path) async {
    // 实际实现中调用 webdav_client 的 mkdirAll

    await Future.delayed(const Duration(milliseconds: 100));
    print('WebDAV: mkdirAll $path');
  }

  @override
  Future<List<RemoteFile>> readDir(String path) async {
    // 实际实现中调用 webdav_client 的 readDir
    await Future.delayed(const Duration(milliseconds: 200));
    print('WebDAV: readDir $path');
    return []; // 模拟空目录
  }

  @override
  Future<RemoteFile?> readProps(String path) async {
    // 实际实现中调用 webdav_client 的 readProps
    await Future.delayed(const Duration(milliseconds: 100));
    print('WebDAV: readProps $path');
    return null; // 模拟文件不存在
  }

  @override
  Future<void> remove(String path) async {
    // 实际实现中调用 webdav_client 的 remove
    await Future.delayed(const Duration(milliseconds: 100));
    print('WebDAV: remove $path');
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

    final total = await file.length();

    // 模拟上传进度
    for (var sent = 0; sent <= total; sent += total ~/ 10) {
      await Future.delayed(const Duration(milliseconds: 50));
      onProgress?.call(sent, total);
    }

    print('WebDAV: uploadFile $localPath -> $remotePath');
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    // 模拟下载进度
    const total = 1024 * 1024; // 1MB
    for (var received = 0; received <= total; received += total ~/ 10) {
      await Future.delayed(const Duration(milliseconds: 50));
      onProgress?.call(received, total);
    }

    // 创建模拟文件
    final file = File(localPath);
    await file.create(recursive: true);
    await file.writeAsString('Downloaded content from $remotePath');

    print('WebDAV: downloadFile $remotePath -> $localPath');
  }

  @override
  Future<List<RemoteFile>> safeReadDir(String path) async {
    if (!await isExist(path)) {
      await mkdirAll(path);
    }
    return readDir(path);
  }
}
