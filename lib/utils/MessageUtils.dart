// lib/utils/message_utils.dart
import 'package:flutter/material.dart';

import '../widgets/custom_snackbar.dart';

class MessageUtils {
  /// 通用提示（信息色）
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;
    CustomSnackBar.showInfo(
      context,
      message: message,
      duration: duration,
    );
  }

  /// 成功提示
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    CustomSnackBar.showSuccess(context, message: message);
  }

  /// 错误提示
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    CustomSnackBar.showError(context, message: message);
  }
}
