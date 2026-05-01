import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/BackupActions.dart';
import '../../services/theme_provider.dart';
import '../../utils/storage_location_prefs.dart';
import '../sync/sync_progress_page.dart';
import '../../utils/storage_analyzer_page.dart';
import '../../widgets/custom_snackbar.dart';
import 'webdav_config_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _storagePath = '未设置';

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
    _loadStoragePath();
  }

  Future<void> _loadStoragePath() async {
    final value = await StorageLocationPrefs.getStorageRootPath();
    if (!mounted) return;
    setState(() {
      _storagePath = (value == null || value.isEmpty) ? '未设置' : value;
    });
  }

  String _storageSubtitle() {
    if (_storagePath == '未设置') return _storagePath;
    return '配置：$_storagePath/config/app_config.json\n数据库：$_storagePath/data/db/momo.db\n图片：$_storagePath/data/images';
  }

  Future<void> _pickStoragePath() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择笔记数据目录',
    );
    if (selected == null || selected.trim().isEmpty || !mounted) return;

    final parent = selected.trim();
    final path = StorageLocationPrefs.resolveBennyRoot(parent);
    try {
      final dir = Directory(path);
      await dir.create(recursive: true);
      await Directory('$path/config').create(recursive: true);
      await Directory('$path/data').create(recursive: true);
      await Directory('$path/data/db').create(recursive: true);
      await Directory('$path/data/images').create(recursive: true);
      final probe = File('$path/.memo_write_probe');
      await probe.writeAsString('ok', flush: true);
      if (await probe.exists()) {
        await probe.delete();
      }

      await StorageLocationPrefs.setStorageRootPath(path);
      if (!mounted) return;
      setState(() {
        _storagePath = path;
      });
      CustomSnackBar.showSuccess(
        context,
        message:
            '已保存目录并创建 benny/config、benny/data/db、benny/data/images：$path；建议重启应用后继续使用。',
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showWarning(
        context,
        message: '目录不可写，请重新选择：$e',
      );
    }
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
                        iconColor: ThemeProvider.primaryColor,
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
                        iconColor: ThemeProvider.primaryColor,
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
                        icon: Icons.folder_special_outlined,
                        iconColor: ThemeProvider.primaryColor,
                        title: '数据存储位置',
                        subtitle: _storageSubtitle(),
                        onTap: _pickStoragePath,
                      ),
                      _buildSettingsTile(
                        context: context,
                        isDark: isDark,
                        icon: Icons.download_outlined,
                        iconColor: ThemeProvider.primaryColor,
                        title: '导出笔记',
                        subtitle: '备份数据到本地文件',
                        onTap: () => BackupActions.exportNotesWithDialog(context),
                      ),
                      _buildSettingsTile(
                        context: context,
                        isDark: isDark,
                        icon: Icons.upload_outlined,
                        iconColor: ThemeProvider.primaryColor,
                        title: '导入笔记',
                        subtitle: '从本地文件恢复数据',
                        onTap: () => BackupActions.importNotesWithDialog(context),
                      ),
                      _buildSettingsTile(
                        context: context,
                        isDark: isDark,
                        icon: Icons.pie_chart_outline,
                        iconColor: ThemeProvider.primaryColor,
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
                        iconColor: ThemeProvider.primaryColor,
                        title: 'WebDAV 配置',
                        subtitle: '配置云端同步服务器',
                        onTap: () => showWebDAVConfigDialog(context),
                      ),
                      _buildSettingsTile(
                        context: context,
                        isDark: isDark,
                        icon: Icons.sync_alt,
                        iconColor: ThemeProvider.primaryColor,
                        title: '云端同步',
                        subtitle: '查看状态与上次结果；需要时再在页面内开始同步',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SyncProgressPage(),
                              fullscreenDialog: true,
                            ),
                          );
                        },
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? ThemeProvider.darkBorderColor : ThemeProvider.lightBorderColor,
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
    final dividerColor =
        isDark ? ThemeProvider.darkBorderColor.withValues(alpha: 0.75) : ThemeProvider.lightBorderColor;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: isDark ? 0.22 : 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.2,
                            color: isDark ? ThemeProvider.darkTextColor : ThemeProvider.lightTextColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.25,
                            color: isDark
                                ? ThemeProvider.darkSecondaryTextColor
                                : ThemeProvider.lightSecondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing,
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 0.5, thickness: 0.5, indent: 60, color: dividerColor),
      ],
    );
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

}
