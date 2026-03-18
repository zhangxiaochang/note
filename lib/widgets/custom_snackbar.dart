import 'package:flutter/material.dart';
import '../services/theme_provider.dart';

/// 自定义 SnackBar，带有现代设计风格
class CustomSnackBar {
  /// 显示成功提示
  static void showSuccess(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      backgroundColor: const Color(0xFF10B981), // Emerald 500
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 显示信息提示
  static void showInfo(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.info_outline,
      backgroundColor: const Color(0xFF3B82F6), // Blue 500
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 显示警告提示
  static void showWarning(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.warning_amber_outlined,
      backgroundColor: const Color(0xFFF59E0B), // Amber 500
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 显示删除提示
  static void showDeleted(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.delete_outline,
      backgroundColor: const Color(0xFFEF4444), // Red 500
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 显示归档提示
  static void showArchived(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.archive_outlined,
      backgroundColor: const Color(0xFFF59E0B), // Amber 500
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 显示恢复提示
  static void showRestored(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.unarchive_outlined,
      backgroundColor: const Color(0xFF10B981), // Emerald 500
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 内部方法：显示 SnackBar
  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    String? actionLabel,
    VoidCallback? onAction,
    required Duration duration,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        elevation: 8,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: () {
                  onAction?.call();
                },
              )
            : null,
      ),
    );
  }
}
