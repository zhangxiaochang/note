import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/BackupActions.dart';
import '../../services/theme_provider.dart';
import '../../services/webdav_config_service.dart';
import '../../sync/models/sync_state.dart';
import '../../sync/services/sync_service.dart';
import '../../sync/services/webdav_client.dart';
import '../../utils/storage_analyzer_page.dart';
import 'webdav_config_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  bool _isUploading = false;
  bool _isDownloading = false;
  String? _uploadResult;
  String? _downloadResult;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? ThemeProvider.darkBackgroundColor : ThemeProvider.lightBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // 页面标题
            SliverToBoxAdapter(
              child: _buildHeader(context, isDark),
            ),
            // 内容区域
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 外观设置组
                  _buildSettingsGroup(
                    context: context,
                    isDark: isDark,
                    title: '外观',
                    icon: Icons.palette_outlined,
                    children: [
                      _buildSettingsTile(
                        context: context,
                        isDark: isDark,
                        icon: _getThemeModeIcon(themeProvider.themeMode),
                        iconColor: Colors.orange,
                        title: '主题',
                        subtitle: _getThemeModeText(themeProvider.themeMode),
                        onTap: () {
                          final nextMode = _getNextThemeMode(themeProvider.themeMode);
                          themeProvider.setThemeMode(nextMode);
                        },
                      ),
                      _buildSettingsTile(
                        context: context,
                        isDark: isDark,
                        icon: themeProvider.isCardView ? Icons.grid_view_outlined : Icons.format_list_bulleted,
                        iconColor: Colors.blue,
                        title: '视图模式',
                        subtitle: themeProvider.isCardView ? '卡片视图' : '列表视图',
                        onTap: () {
                          themeProvider.setViewMode(
                            themeProvider.isCardView ? ViewModeOption.list : ViewModeOption.card,
                          );
                        },
                        isLast: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 数据管理组
                  _buildSettingsGroup(
                    context: context,
                    isDark: isDark,
                    title: '数据管理',
                    icon: Icons.folder_outlined,
                    children: [
                      _buildSettingsTile(
                        context: context,
                        isDark: isDark,
                        icon: Icons.download_outlined,
                        iconColor: Colors.green,
                        title: '导出笔记',
                        subtitle: '备份数据到本地文件',
                        onTap: () => BackupActions.exportNotesWithDialog(context),
                      ),
                      _buildSettingsTile(
                        context: context,
                        isDark: isDark,
                        icon: Icons.upload_outlined,
                        iconColor: Colors.purple,
                        title: '导入笔记',
                        subtitle: '从本地文件恢复数据',
                        onTap: () => BackupActions.importNotesWithDialog(context),
                      ),
                      _buildSettingsTile(
                        context: context,
                        isDark: isDark,
                        icon: Icons.pie_chart_outline,
                        iconColor: Colors.teal,
                        title: '存储分析',
                        subtitle: '查看存储空间使用情况',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => StorageAnalyzerPage()),
                          );
                        },
                        isLast: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 云同步组
                  _buildSettingsGroup(
                    context: context,
                    isDark: isDark,
                    title: '云同步',
                    icon: Icons.cloud_outlined,
                    children: [
                      _buildSettingsTile(
                        context: context,
                        isDark: isDark,
                        icon: Icons.settings_outlined,
                        iconColor: Colors.indigo,
                        title: 'WebDAV 配置',
                        subtitle: '配置云端同步服务器',
                        onTap: () => showWebDAVConfigDialog(context),
                      ),
                      _buildSyncActionTile(
                        context: context,
                        isDark: isDark,
                        icon: Icons.cloud_upload_outlined,
                        iconColor: Colors.blue,
                        title: '上传到云端',
                        subtitle: _uploadResult ?? '将本地数据同步到云端',
                        isLoading: _isUploading,
                        statusColor: _getStatusColor(_uploadResult),
                        onTap: _isUploading ? null : _uploadToCloud,
                      ),
                      _buildSyncActionTile(
                        context: context,
                        isDark: isDark,
                        icon: Icons.cloud_download_outlined,
                        iconColor: Colors.orange,
                        title: '从云端下载',
                        subtitle: _downloadResult ?? '从云端同步数据到本地',
                        isLoading: _isDownloading,
                        statusColor: _getStatusColor(_downloadResult),
                        onTap: _isDownloading ? null : _downloadFromCloud,
                        isLast: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建页面头部
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '设置',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? ThemeProvider.darkTextColor : ThemeProvider.lightTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '自定义您的使用体验',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? ThemeProvider.darkSecondaryTextColor : ThemeProvider.lightSecondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  // 构建设置组
  Widget _buildSettingsGroup({
    required BuildContext context,
    required bool isDark,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 组标题
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black54,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        // 卡片容器
        Container(
          decoration: BoxDecoration(
            color: isDark ? ThemeProvider.darkCardColor : ThemeProvider.lightCardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  // 构建设置项
  Widget _buildSettingsTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 图标容器
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withValues(alpha: isDark ? 0.25 : 0.15),
                      iconColor.withValues(alpha: isDark ? 0.15 : 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              // 文字内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white.withValues(alpha: 0.48) : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧内容
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 构建同步操作项
  Widget _buildSyncActionTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isLoading,
    Color? statusColor,
    required VoidCallback? onTap,
    bool isLast = false,
  }) {
    final bool hasStatus = statusColor != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 图标容器
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      hasStatus
                          ? statusColor.withValues(alpha: isDark ? 0.25 : 0.15)
                          : iconColor.withValues(alpha: isDark ? 0.25 : 0.15),
                      hasStatus
                          ? statusColor.withValues(alpha: isDark ? 0.15 : 0.08)
                          : iconColor.withValues(alpha: isDark ? 0.15 : 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            hasStatus ? statusColor : iconColor,
                          ),
                        ),
                      )
                    : Icon(
                        icon,
                        color: hasStatus ? statusColor : iconColor,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 14),
              // 文字内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: hasStatus
                            ? statusColor
                            : (isDark ? Colors.white.withValues(alpha: 0.48) : Colors.black45),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 获取状态颜色
  Color? _getStatusColor(String? result) {
    if (result == null) return null;
    if (result.contains('成功')) return Colors.green;
    if (result.contains('失败') || result.contains('错误')) return Colors.red;
    return null;
  }

  // 主题相关方法
  String _getThemeModeText(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.light:
        return '浅色模式';
      case ThemeModeOption.dark:
        return '深色模式';
      case ThemeModeOption.system:
        return '跟随系统';
    }
  }

  IconData _getThemeModeIcon(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.light:
        return Icons.light_mode_outlined;
      case ThemeModeOption.dark:
        return Icons.dark_mode_outlined;
      case ThemeModeOption.system:
        return Icons.brightness_auto_outlined;
    }
  }

  ThemeModeOption _getNextThemeMode(ThemeModeOption current) {
    switch (current) {
      case ThemeModeOption.light:
        return ThemeModeOption.dark;
      case ThemeModeOption.dark:
        return ThemeModeOption.system;
      case ThemeModeOption.system:
        return ThemeModeOption.light;
    }
  }

  // 上传到云端
  Future<void> _uploadToCloud() async {
    setState(() {
      _isUploading = true;
      _uploadResult = null;
    });

    try {
      final config = await WebDAVConfigService.loadConfig();
      if (!config.isValid) {
        setState(() => _uploadResult = '请先配置 WebDAV');
        return;
      }

      final client = WebdavClient(
        url: config.url,
        username: config.username,
        password: config.password,
      );

      final syncService = SyncService(client, context: context);
      final result = await syncService.sync(SyncDirection.upload);

      if (mounted) {
        setState(() => _uploadResult = result.isSuccess ? '上传成功' : '上传失败: ${result.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadResult = '上传失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // 从云端下载
  Future<void> _downloadFromCloud() async {
    setState(() {
      _isDownloading = true;
      _downloadResult = null;
    });

    try {
      final config = await WebDAVConfigService.loadConfig();
      if (!config.isValid) {
        setState(() => _downloadResult = '请先配置 WebDAV');
        return;
      }

      final client = WebdavClient(
        url: config.url,
        username: config.username,
        password: config.password,
      );

      final syncService = SyncService(client, context: context);
      final result = await syncService.sync(SyncDirection.download);

      if (mounted) {
        setState(() => _downloadResult = result.isSuccess ? '下载成功' : '下载失败: ${result.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadResult = '下载失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }
}
