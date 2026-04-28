import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/storage_location_prefs.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('目录不可写，请重新选择：$e')),
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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '先设置数据保存位置',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '首次启动必须选择目录。你选择的是父目录，应用会自动新建 `benny/config/app_config.json`，并在 `benny/data` 下创建 `db` 与 `images`。',
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      _selectedParentPath ?? '尚未选择父目录',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: Text(
                      targetPath == null ? '将创建：<父目录>/benny' : '将创建：$targetPath',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickDirectory,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('选择父目录'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _saving ? null : _useDefaultDirectory,
                        child: const Text('使用默认目录'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: (_saving || _selectedParentPath == null)
                            ? null
                            : _saveAndContinue,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('保存并进入'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
