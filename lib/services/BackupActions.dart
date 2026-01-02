import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/MessageUtils.dart';
import 'note_backup_service.dart';

class BackupActions {
  // 静态方法：导出（带用户保存对话框）
  static Future<void> exportNotesWithDialog(BuildContext context) async {
    try {
      final service = NoteBackupService();
      final jsonString = await service.exportToJson();
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存笔记备份',
        fileName: service.generateBackupFileName(),
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (filePath != null) {
        if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
          await File(filePath).writeAsBytes(bytes);
        }
        MessageUtils.showSuccess(context, '✅ 备份已保存');
      }
    } catch (e) {
      MessageUtils.showError(context, '❌ 导出失败: ${e.toString()}');
    }
  }

  // 静态方法：导入（带用户文件选择）
  static Future<void> importNotesWithDialog(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return;

      final filePath = result.files.single.path!;
      final service = NoteBackupService();
      final count = await service.importFromJsonFile(filePath);

      MessageUtils.showSuccess(context, '✅ 成功导入 $count 条笔记');
    } catch (e) {
      MessageUtils.showError(context, '❌ 导入失败: ${e.toString()}');
    }
  }
}