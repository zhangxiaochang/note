import 'dart:io';
import 'package:flutter/material.dart';
import '../models/remote_file.dart';
import '../utils/sync_conflict_resolver.dart';

/// 冲突解决对话框
/// 当本地和远程数据冲突时显示，让用户选择保留哪个版本
class ConflictResolutionDialog extends StatelessWidget {
  final ConflictDetails conflictDetails;
  final String fileName;

  const ConflictResolutionDialog({
    super.key,
    required this.conflictDetails,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '同步冲突',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 说明文字
              Text(
                '本地和远程的 "$fileName" 文件存在冲突，请选择要保留的版本：',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // 本地版本卡片
              _buildVersionCard(
                context,
                title: '本地版本',
                icon: Icons.phone_android,
                color: Colors.blue,
                modTime: conflictDetails.localModTime,
                size: conflictDetails.localSize,
                onTap: () => Navigator.of(context).pop(ConflictResolution.useLocal),
              ),
              const SizedBox(height: 12),

              // 远程版本卡片
              _buildVersionCard(
                context,
                title: '远程版本',
                icon: Icons.cloud,
                color: Colors.green,
                modTime: conflictDetails.remoteModTime,
                size: conflictDetails.remoteSize,
                onTap: () => Navigator.of(context).pop(ConflictResolution.useRemote),
              ),
              const SizedBox(height: 24),

              // 操作按钮
              Row(
                children: [
                  // 保留两者（合并）
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(ConflictResolution.needsMerge),
                      icon: const Icon(Icons.merge_type, size: 18),
                      label: const Text('尝试合并'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        side: const BorderSide(color: Colors.purple),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 取消
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('取消同步'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required DateTime? modTime,
    required int size,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '修改时间: ${_formatDateTime(modTime)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Text(
                      '大小: ${_formatBytes(size)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '未知';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 显示冲突解决对话框
Future<ConflictResolution?> showConflictResolutionDialog(
  BuildContext context, {
  required ConflictDetails conflictDetails,
  required String fileName,
}) async {
  return showDialog<ConflictResolution>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConflictResolutionDialog(
      conflictDetails: conflictDetails,
      fileName: fileName,
    ),
  );
}
