import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/BackupActions.dart';
import '../../services/theme_provider.dart';
import '../../utils/storage_analyzer_page.dart';
import 'webdav_config_dialog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, '外观'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildCycleItem(
                    context,
                    title: '主题',
                    subtitle: _getThemeModeText(themeProvider.themeMode),
                    icon: _getThemeModeIcon(themeProvider.themeMode),
                    onTap: () {
                      final nextMode = _getNextThemeMode(themeProvider.themeMode);
                      themeProvider.setThemeMode(nextMode);
                    },
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                  _buildCycleItem(
                    context,
                    title: '视图',
                    subtitle: themeProvider.isCardView ? '卡片视图' : '列表视图',
                    icon: themeProvider.isCardView ? Icons.view_module_outlined : Icons.view_list_outlined,
                    onTap: () {
                      themeProvider.setViewMode(themeProvider.isCardView ? ViewModeOption.list : ViewModeOption.card);
                    },
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                ],
              ),
            ),
            _buildSectionTitle(context, '数据管理'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    context,
                    title: '导出笔记',
                    subtitle: '备份到本地文件',
                    icon: Icons.download_outlined,
                    onTap: () => BackupActions.exportNotesWithDialog(context),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                  _buildSettingItem(
                    context,
                    title: '导入笔记',
                    subtitle: '从本地文件恢复',
                    icon: Icons.upload_outlined,
                    onTap: () => BackupActions.importNotesWithDialog(context),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                  _buildSettingItem(
                    context,
                    title: '存储分析',
                    subtitle: '查看存储使用情况',
                    icon: Icons.storage_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StorageAnalyzerPage(),
                        ),
                      );
                    },
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  // WebDAV 同步（暂时隐藏）
                  // Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                  // _buildSettingItem(
                  //   context,
                  //   title: 'WebDAV 同步',
                  //   subtitle: '配置云端同步',
                  //   icon: Icons.cloud_sync_outlined,
                  //   onTap: () => showWebDAVConfigDialog(context),
                  //   borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        return Icons.settings_suggest_outlined;
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

  void _showThemeModeDialog(BuildContext context, ThemeProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 280,
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
              const SizedBox(height: 24),
              Text(
                '选择主题',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildThemeOption(context, '浅色模式', Icons.light_mode_outlined, ThemeModeOption.light, provider),
              _buildThemeOption(context, '深色模式', Icons.dark_mode_outlined, ThemeModeOption.dark, provider),
              _buildThemeOption(context, '跟随系统', Icons.settings_suggest_outlined, ThemeModeOption.system, provider),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, IconData icon, ThemeModeOption mode, ThemeProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = provider.themeMode == mode;
    return InkWell(
      onTap: () {
        provider.setThemeMode(mode);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : (isDark ? Colors.white70 : Colors.black54), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }

  void _showViewModeDialog(BuildContext context, ThemeProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 280,
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
              const SizedBox(height: 24),
              Text(
                '选择视图',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildViewOption(context, '卡片视图', Icons.view_module_outlined, ViewModeOption.card, provider),
              _buildViewOption(context, '列表视图', Icons.view_list_outlined, ViewModeOption.list, provider),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildViewOption(BuildContext context, String title, IconData icon, ViewModeOption mode, ThemeProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = provider.viewMode == mode;
    return InkWell(
      onTap: () {
        provider.setViewMode(mode);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : (isDark ? Colors.white70 : Colors.black54), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    BorderRadius? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.blue,
                  size: 20,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
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

  Widget _buildSwitchItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    BorderRadius? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              size: 20,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.blue,
            activeTrackColor: Colors.blue.withValues(alpha: 0.3),
            inactiveThumbColor: isDark ? Colors.grey.shade400 : Colors.white,
            inactiveTrackColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ],
        ),
        ),
      ),
    );
  }

  Widget _buildCycleItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    BorderRadius? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.blue,
                  size: 20,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
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
}
