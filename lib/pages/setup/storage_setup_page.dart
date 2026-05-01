import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/storage_location_prefs.dart';
import '../../widgets/custom_snackbar.dart';

class StorageSetupPage extends StatefulWidget {
  const StorageSetupPage({
    super.key,
    required this.onConfigured,
  });

  final VoidCallback onConfigured;

  @override
  State<StorageSetupPage> createState() => _StorageSetupPageState();
}

class _StorageSetupPageState extends State<StorageSetupPage> {
  String? _selectedParentPath;
  bool _saving = false;

  Future<void> _pickDirectory() async {
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择笔记数据保存目录',
    );
    if (!mounted || picked == null || picked.trim().isEmpty) return;
    setState(() {
      _selectedParentPath = picked.trim();
    });
  }

  Future<void> _useDefaultDirectory() async {
    final doc = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    setState(() {
      _selectedParentPath = doc.path;
    });
  }

  Future<void> _saveAndContinue() async {
    final parent = _selectedParentPath;
    if (parent == null || parent.isEmpty) return;

    setState(() {
      _saving = true;
    });

    try {
      final bennyRoot = StorageLocationPrefs.resolveBennyRoot(parent);
      final rootDir = Directory(bennyRoot);
      await rootDir.create(recursive: true);
      final configDir = Directory('$bennyRoot/config');
      final dataDir = Directory('$bennyRoot/data');
      final dbDir = Directory('$bennyRoot/data/db');
      final imageDir = Directory('$bennyRoot/data/images');
      await configDir.create(recursive: true);
      await dataDir.create(recursive: true);
      await dbDir.create(recursive: true);
      await imageDir.create(recursive: true);

      // 校验可写权限（写后删）
      final probe = File('$bennyRoot/.memo_write_probe');
      await probe.writeAsString('ok', flush: true);
      if (await probe.exists()) {
        await probe.delete();
      }

      await StorageLocationPrefs.setStorageRootPath(bennyRoot);

      if (!mounted) return;
      widget.onConfigured();
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showWarning(
        context,
        message: '目录不可写，请重新选择：$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetPath = _selectedParentPath == null
        ? null
        : StorageLocationPrefs.resolveBennyRoot(_selectedParentPath!);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0A84FF)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '先设置数据保存位置',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '首次启动必须选择目录。你选择的是父目录，应用会自动新建 '
                        '`benny/config/app_config.json`，并在 `benny/data` 下创建 `db` 与 `images`。',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _pathCard(
                        title: '已选父目录',
                        value: _selectedParentPath ?? '尚未选择父目录',
                        icon: Icons.folder_open,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _pathCard(
                        title: '将创建目录',
                        value: targetPath ?? '<父目录>/benny',
                        icon: Icons.auto_awesome,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _pickDirectory,
                            icon: const Icon(Icons.folder_open_rounded),
                            label: const Text('选择父目录'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                              ),
                              foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: _saving ? null : _useDefaultDirectory,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            child: const Text('使用默认目录'),
                          ),
                          FilledButton.icon(
                            onPressed: (_saving || _selectedParentPath == null) ? null : _saveAndContinue,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(_saving ? '正在保存...' : '保存并进入'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0A84FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pathCard({
    required String title,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0A84FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
