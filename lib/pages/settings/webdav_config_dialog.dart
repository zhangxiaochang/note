import 'package:flutter/material.dart';
import '../../services/webdav_config_service.dart';

/// WebDAV 配置弹窗
class WebDAVConfigDialog extends StatefulWidget {
  const WebDAVConfigDialog({super.key});

  @override
  State<WebDAVConfigDialog> createState() => _WebDAVConfigDialogState();
}

class _WebDAVConfigDialogState extends State<WebDAVConfigDialog> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 加载已保存的配置
  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await WebDAVConfigService.loadConfig();
      if (config.isValid) {
        _urlController.text = config.url;
        _usernameController.text = config.username;
        _passwordController.text = config.password;
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 测试连接
  Future<void> _testConnection() async {
    final config = WebDAVConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!config.isValid) {
      setState(() => _testResult = '请填写完整的配置信息');
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final success = await WebDAVConfigService.testConnection(config);
      setState(() => _testResult = success ? '连接成功' : '连接失败');
    } catch (e) {
      setState(() => _testResult = '连接失败: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  /// 测试写入
  Future<void> _testWrite() async {
    final config = WebDAVConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!config.isValid) {
      setState(() => _testResult = '请填写完整的配置信息');
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final result = await WebDAVConfigService.testWrite(config);
      setState(() => _testResult = result['message'] as String);
    } catch (e) {
      setState(() => _testResult = '写入测试失败: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    final config = WebDAVConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!config.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整的配置信息')),
      );
      return;
    }

    await WebDAVConfigService.saveConfig(config);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_sync_outlined,
                    color: Colors.blue,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'WebDAV 配置',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // 表单内容
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // WebDAV 地址
                    _buildTextField(
                      controller: _urlController,
                      label: 'WebDAV 地址',
                      hint: 'https://example.com/webdav',
                      icon: Icons.link,
                    ),
                    const SizedBox(height: 16),

                    // 用户名
                    _buildTextField(
                      controller: _usernameController,
                      label: '用户名',
                      hint: '请输入用户名',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),

                    // 密码
                    _buildTextField(
                      controller: _passwordController,
                      label: '密码',
                      hint: '请输入密码',
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),

                    // 测试结果提示
                    if (_testResult != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Icon(
                              _testResult == '连接成功'
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _testResult == '连接成功'
                                  ? Colors.green
                                  : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _testResult!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _testResult == '连接成功'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // 按钮区域
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  // 第一行按钮：测试连接、测试写入
                  Row(
                    children: [
                      // 测试连接按钮
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isTesting ? null : _testConnection,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.blue),
                                  ),
                                )
                              : const Text('测试连接'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 测试写入按钮
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isTesting ? null : _testWrite,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.orange),
                                  ),
                                )
                              : const Text('测试写入'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 第二行按钮：保存
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// 显示 WebDAV 配置弹窗
Future<bool?> showWebDAVConfigDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const WebDAVConfigDialog(),
  );
}
