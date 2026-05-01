import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../services/webdav_config_service.dart';
import '../../utils/permission_manager.dart';
import '../../widgets/custom_snackbar.dart';

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
    // Android 平台先申请权限
    if (Platform.isAndroid) {
      final hasPermission = await PermissionManager.requestStoragePermission(context);
      if (!hasPermission) {
        setState(() => _testResult = '需要存储权限才能同步');
        return;
      }
    }

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

  /// 保存配置
  Future<void> _saveConfig() async {
    final config = WebDAVConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!config.isValid) {
      CustomSnackBar.showWarning(
        context,
        message: '请填写完整的配置信息',
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
        width: 400,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.cloud_sync_outlined,
                      color: Color(0xFF4F46E5),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WebDAV 配置',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        '用于多端数据同步',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
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
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),

                    // 用户名
                    _buildTextField(
                      controller: _usernameController,
                      label: '用户名',
                      hint: '请输入用户名',
                      icon: Icons.person_outline,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),

                    // 密码
                    _buildTextField(
                      controller: _passwordController,
                      label: '密码',
                      hint: '请输入密码',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      isDark: isDark,
                    ),

                    // 测试结果提示
                    if (_testResult != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: _testResult == '连接成功'
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _testResult == '连接成功'
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFFECACA),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _testResult == '连接成功'
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _testResult == '连接成功'
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _testResult!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _testResult == '连接成功'
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB91C1C),
                                  ),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 按钮区域
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  // 测试连接按钮
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isTesting ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6),
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFF2F2F7),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Color(0xFF4F46E5)),
                              ),
                            )
                          : const Text('测试连接'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 保存按钮
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A84FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    required bool isDark,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : const Color(0xFF8E8E93),
            ),
            prefixIcon: Icon(
              icon,
              size: 18,
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
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
