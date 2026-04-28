import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../sync/services/webdav_client.dart';
import '../utils/storage_location_prefs.dart';

/// WebDAV 配置数据模型
class WebDAVConfig {
  final String url;
  final String username;
  final String password;

  WebDAVConfig({
    required this.url,
    required this.username,
    required this.password,
  });

  /// 从 JSON 创建配置
  factory WebDAVConfig.fromJson(Map<String, dynamic> json) {
    return WebDAVConfig(
      url: json['url'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'username': username,
      'password': password,
    };
  }

  /// 检查配置是否有效
  bool get isValid => url.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  /// 创建空配置
  factory WebDAVConfig.empty() {
    return WebDAVConfig(url: '', username: '', password: '');
  }
}

/// WebDAV 配置服务
class WebDAVConfigService {
  static const String _keyWebDAVConfig = 'webdav_config';
  static const String _keyWebDavNode = 'webdav';

  static Future<File?> _customConfigFile() async {
    final root = await StorageLocationPrefs.getStorageRootPath();
    if (root == null || root.isEmpty) return null;
    final configDir = Directory(p.join(root, 'config'));
    await configDir.create(recursive: true);
    return File(p.join(configDir.path, 'app_config.json'));
  }

  static Future<Map<String, dynamic>> _readCustomConfig() async {
    final file = await _customConfigFile();
    if (file == null || !await file.exists()) return <String, dynamic>{};
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return <String, dynamic>{};
      final json = jsonDecode(content);
      if (json is Map<String, dynamic>) return json;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _writeCustomConfig(Map<String, dynamic> data) async {
    final file = await _customConfigFile();
    if (file == null) return;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }

  /// 保存 WebDAV 配置到本地
  static Future<void> saveConfig(WebDAVConfig config) async {
    final custom = await _readCustomConfig();
    custom[_keyWebDavNode] = config.toJson();
    await _writeCustomConfig(custom);

    // 迁移完成后清理旧 SharedPreferences 位置
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyWebDAVConfig);
  }

  /// 从本地加载 WebDAV 配置
  static Future<WebDAVConfig> loadConfig() async {
    final custom = await _readCustomConfig();
    final node = custom[_keyWebDavNode];
    if (node is Map<String, dynamic>) {
      final cfg = WebDAVConfig.fromJson(node);
      if (cfg.isValid) return cfg;
    }

    // 兼容旧版 SharedPreferences，并在读取后自动迁移
    final prefs = await SharedPreferences.getInstance();
    final configString = prefs.getString(_keyWebDAVConfig);
    if (configString == null || configString.isEmpty) {
      return WebDAVConfig.empty();
    }

    // 解析存储的配置字符串
    final parts = configString.split('|');
    if (parts.length >= 3) {
      final cfg = WebDAVConfig(
        url: parts[0],
        username: parts[1],
        password: parts[2],
      );
      if (cfg.isValid) {
        await saveConfig(cfg);
      }
      return cfg;
    }

    return WebDAVConfig.empty();
  }

  /// 清除 WebDAV 配置
  static Future<void> clearConfig() async {
    final custom = await _readCustomConfig();
    custom.remove(_keyWebDavNode);
    await _writeCustomConfig(custom);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyWebDAVConfig);
  }

  /// 测试 WebDAV 连接
  static Future<bool> testConnection(WebDAVConfig config) async {
    if (!config.isValid) {
      return false;
    }

    try {
      // 使用现有的 WebdavClient 进行连接测试
      final client = WebdavClient(
        url: config.url,
        username: config.username,
        password: config.password,
      );

      // 调用 ping 方法测试连接
      await client.ping();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 测试 WebDAV 写入功能
  static Future<Map<String, dynamic>> testWrite(WebDAVConfig config) async {
    if (!config.isValid) {
      return {'success': false, 'message': '配置信息不完整'};
    }

    try {
      final client = WebdavClient(
        url: config.url,
        username: config.username,
        password: config.password,
      );

      // 执行完整的读写测试
      await client.testFullCapabilities();
      return {'success': true, 'message': '写入测试成功'};
    } catch (e) {
      return {'success': false, 'message': '写入测试失败: $e'};
    }
  }

  /// 创建 WebDAV 客户端实例
  static Future<WebdavClient?> createClient() async {
    final config = await loadConfig();
    if (!config.isValid) {
      return null;
    }

    return WebdavClient(
      url: config.url,
      username: config.username,
      password: config.password,
    );
  }
}
