import 'package:flutter/material.dart';

enum ConfirmActionType {
  delete,
  archive,
  unarchive,
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final ConfirmActionType actionType;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actionType,
    this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String content,
    required ConfirmActionType actionType,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) => ConfirmDialog(
        title: title,
        content: content,
        actionType: actionType,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
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

  Color _getActionColor(BuildContext context) {
    switch (actionType) {
      case ConfirmActionType.delete:
        return Colors.red;
      case ConfirmActionType.archive:
      case ConfirmActionType.unarchive:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.orangeAccent
            : Colors.orange;
    }
  }

  IconData _getActionIcon() {
    switch (actionType) {
      case ConfirmActionType.delete:
        return Icons.delete_outline;
      case ConfirmActionType.archive:
        return Icons.archive_outlined;
      case ConfirmActionType.unarchive:
        return Icons.unarchive_outlined;
    }
  }

  String _getConfirmText() {
    switch (actionType) {
      case ConfirmActionType.delete:
        return '删除';
      case ConfirmActionType.archive:
        return '归档';
      case ConfirmActionType.unarchive:
        return '取消归档';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionColor = _getActionColor(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 320,
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
            // 图标
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getActionIcon(),
                size: 32,
                color: actionColor,
              ),
            ),
            const SizedBox(height: 20),
            // 标题
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            // 内容
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 28),
            // 按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      context: context,
                      text: '取消',
                      isPrimary: false,
                      onTap: onCancel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildButton(
                      context: context,
                      text: _getConfirmText(),
                      isPrimary: true,
                      color: actionColor,
                      onTap: onConfirm,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String text,
    required bool isPrimary,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isPrimary
              ? color
              : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isPrimary
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}
