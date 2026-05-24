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

class _SettingsPageState extends State<SettingsPage> {
  String _storagePath = '未设置';

  @override
  void initState() {
    super.initState();
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
        message: '已保存目录并创建 benny/config、benny/data/db、benny/data/images：$path；建议重启应用后继续使用。',
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
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? ThemeProvider.darkBackgroundColor
          : ThemeProvider.lightBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark
            ? ThemeProvider.darkBackgroundColor
            : ThemeProvider.lightBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          // ══════ 外观 ══════
          _SectionHeader(title: '外观'),
          _GroupCard(
            children: [
              _SettingsRow(
                icon: _themeIcon(themeProvider.themeMode),
                iconBg: const Color(0xFF007AFF),
                title: '主题',
                value: _themeText(themeProvider.themeMode),
                onTap: () {
                  final next = _nextTheme(themeProvider.themeMode);
                  themeProvider.setThemeMode(next);
                },
              ),
              _SettingsRow(
                icon: themeProvider.isCardView
                    ? Icons.grid_view_outlined
                    : Icons.format_list_bulleted,
                iconBg: const Color(0xFF34C759),
                title: '视图模式',
                value: themeProvider.isCardView ? '卡片' : '列表',
                onTap: () {
                  themeProvider.setViewMode(
                    themeProvider.isCardView ? ViewModeOption.list : ViewModeOption.card,
                  );
                },
                isLast: true,
              ),
            ],
          ),

          // ══════ 数据管理 ══════
          _SectionHeader(title: '数据管理'),
          _GroupCard(
            children: [
              _SettingsRow(
                icon: Icons.folder_outlined,
                iconBg: const Color(0xFFAF52DE),
                title: '数据存储位置',
                subtitle: _storageSubtitle(),
                onTap: _pickStoragePath,
              ),
              _SettingsRow(
                icon: Icons.download_outlined,
                iconBg: const Color(0xFF007AFF),
                title: '导出笔记',
                subtitle: '备份数据到本地文件',
                onTap: () => BackupActions.exportNotesWithDialog(context),
              ),
              _SettingsRow(
                icon: Icons.upload_outlined,
                iconBg: const Color(0xFF34C759),
                title: '导入笔记',
                subtitle: '从本地文件恢复数据',
                onTap: () => BackupActions.importNotesWithDialog(context),
              ),
              _SettingsRow(
                icon: Icons.pie_chart_outline,
                iconBg: const Color(0xFFFF9500),
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

          // ══════ 云同步 ══════
          _SectionHeader(title: '云同步'),
          _GroupCard(
            children: [
              _SettingsRow(
                icon: Icons.settings_outlined,
                iconBg: const Color(0xFF007AFF),
                title: 'WebDAV 配置',
                subtitle: '配置云端同步服务器',
                onTap: () => showWebDAVConfigDialog(context),
              ),
              _SettingsRow(
                icon: Icons.sync,
                iconBg: const Color(0xFF34C759),
                title: '云端同步',
                subtitle: '查看状态与上次结果',
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

          // ══════ 关于 ══════
          _SectionHeader(title: '关于'),
          _GroupCard(
            children: [
              _SettingsRow(
                icon: Icons.info_outline,
                iconBg: const Color(0xFF8E8E93),
                title: '版本',
                value: '1.0.0',
                isLast: true,
                showChevron: false,
              ),
            ],
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'Benny · 数据在你手中',
              style: TextStyle(
                fontSize: 13,
                color: ThemeProvider.lightSecondaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  IconData _themeIcon(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.light:
        return Icons.light_mode_outlined;
      case ThemeModeOption.dark:
        return Icons.dark_mode_outlined;
      case ThemeModeOption.system:
        return Icons.brightness_auto_outlined;
    }
  }

  String _themeText(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.light:
        return '浅色';
      case ThemeModeOption.dark:
        return '深色';
      case ThemeModeOption.system:
        return '跟随系统';
    }
  }

  ThemeModeOption _nextTheme(ThemeModeOption current) {
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

// ═══════════════════════════════════════════
// iOS-style widgets
// ═══════════════════════════════════════════

/// Section header — iOS small uppercase label
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFF8E8E93),
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

/// iOS inset grouped card — white/dark rounded container
class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? ThemeProvider.darkCardColor
              : ThemeProvider.lightCardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

/// iOS settings row — icon square + title + subtitle + value/chevron
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool isLast;
  final bool showChevron;

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.isLast = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final separatorColor = isDark
        ? ThemeProvider.darkBorderColor.withValues(alpha: 0.5)
        : ThemeProvider.lightBorderColor;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Icon square (iOS glyph style)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconBg.withValues(alpha: isDark ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, color: iconBg, size: 18),
                  ),
                  const SizedBox(width: 12),
                  // Title + subtitle
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
                            color: isDark
                                ? ThemeProvider.darkTextColor
                                : ThemeProvider.lightTextColor,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: ThemeProvider.lightSecondaryTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Value text
                  if (value != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        value!,
                        style: TextStyle(
                          fontSize: 17,
                          color: ThemeProvider.lightSecondaryTextColor,
                        ),
                      ),
                    ),
                  // Chevron
                  if (showChevron)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: isDark
                          ? const Color(0xFF545458)
                          : const Color(0xFFC7C7CC),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 0,
            thickness: 0.5,
            indent: 58,
            color: separatorColor,
          ),
      ],
    );
  }
}
