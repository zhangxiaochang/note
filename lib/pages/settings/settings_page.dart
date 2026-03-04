import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/BackupActions.dart';
import '../../services/theme_provider.dart';
import '../../utils/storage_analyzer_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, '外观'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildThemeCard(
                    context,
                    title: '浅色',
                    icon: Icons.light_mode,
                    isSelected: themeProvider.themeMode == ThemeModeOption.light,
                    onTap: () =>
                        themeProvider.setThemeMode(ThemeModeOption.light),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThemeCard(
                    context,
                    title: '深色',
                    icon: Icons.dark_mode,
                    isSelected: themeProvider.themeMode == ThemeModeOption.dark,
                    onTap: () => themeProvider.setThemeMode(ThemeModeOption.dark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThemeCard(
                    context,
                    title: '跟随系统',
                    icon: Icons.settings_suggest,
                    isSelected: themeProvider.themeMode == ThemeModeOption.system,
                    onTap: () =>
                        themeProvider.setThemeMode(ThemeModeOption.system),
                  ),
                ),
              ],
            ),
            _buildSectionTitle(context, '备份'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildBackupCard(
                    context,
                    title: '导出笔记',
                    icon: Icons.download_outlined,
                    onTap: () => BackupActions.exportNotesWithDialog(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBackupCard(
                    context,
                    title: '导入笔记',
                    icon: Icons.upload_outlined,
                    onTap: () => BackupActions.importNotesWithDialog(context),
                  ),
                ),
              ],
            ),
            _buildSectionTitle(context, '存储'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildBackupCard(
                    context,
                    title: '存储分析',
                    icon: Icons.storage,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StorageAnalyzerPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.greenAccent : Colors.green,
        ),
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.green.withOpacity(0.2) : Colors.green.withOpacity(0.1))
              : (isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.greenAccent : Colors.green)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? (isDark ? Colors.greenAccent : Colors.green)
                  : (isDark ? Colors.white70 : Colors.black54),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isDark ? Colors.white70 : Colors.black54,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
