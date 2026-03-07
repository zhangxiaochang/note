import 'package:shared_preferences/shared_preferences.dart';
import '../sync/services/webdav_client.dart';

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

  /// 保存 WebDAV 配置到本地
  static Future<void> saveConfig(WebDAVConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWebDAVConfig, '${config.url}|${config.username}|${config.password}');
  }

  /// 从本地加载 WebDAV 配置
  static Future<WebDAVConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configString = prefs.getString(_keyWebDAVConfig);

    if (configString == null || configString.isEmpty) {
      return WebDAVConfig.empty();
    }

    // 解析存储的配置字符串
    final parts = configString.split('|');
    if (parts.length >= 3) {
      return WebDAVConfig(
        url: parts[0],
        username: parts[1],
        password: parts[2],
      );
    }

    return WebDAVConfig.empty();
  }

  /// 清除 WebDAV 配置
  static Future<void> clearConfig() async {
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
