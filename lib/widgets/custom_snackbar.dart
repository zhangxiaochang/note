import 'package:flutter/material.dart';

import 'apple_toast_card.dart';

/// 应用内轻提示：统一苹果风卡片 + Overlay 淡入淡出（无 SnackBar 滑入、无悬停抖动）。
class CustomSnackBar {
  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    AppleToastMessenger.show(
      context,
      displayDuration: duration,
      child: AppleToastCard(
        message: message,
        icon: icon,
        iconColor: iconColor,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }

  /// 成功
  static void showSuccess(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: AppleToastColors.success,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 信息
  static void showInfo(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      icon: Icons.info_outline,
      iconColor: AppleToastColors.info,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 错误（通用）
  static void showError(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      icon: Icons.error_outline,
      iconColor: AppleToastColors.destructive,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 警告
  static void showWarning(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: AppleToastColors.warning,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 删除
  static void showDeleted(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      icon: Icons.delete_outline,
      iconColor: AppleToastColors.destructive,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 归档
  static void showArchived(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      icon: Icons.archive_outlined,
      iconColor: AppleToastColors.archive,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 恢复
  static void showRestored(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      icon: Icons.unarchive_outlined,
      iconColor: AppleToastColors.success,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }
}
