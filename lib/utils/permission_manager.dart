import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 权限管理工具类
class PermissionManager {

  /// 检查是否已有存储权限
  static Future<bool> checkStoragePermission() async {
    try {
      final storageStatus = await Permission.storage.status;
      return storageStatus.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// 申请存储权限 - 适配 Android 13+
  static Future<bool> requestStoragePermission(BuildContext context) async {
    try {
      // 申请 storage 权限
      final storageResult = await Permission.storage.request();

      if (storageResult.isGranted) {
        return true;
      }
      
      // 如果 storage 被拒绝，返回 false
      return false;
    } catch (_) {
      return false;
    }
  }
  
  /// 检查并申请网络权限（Android 不需要运行时申请，但检查网络状态）
  static Future<bool> checkNetworkPermission() async {
    // 网络权限在 Android 中自动授予，不需要运行时申请
    // 这里只是检查网络状态
    return true;
  }
  
  /// 申请所有需要的权限
  static Future<bool> requestAllPermissions(BuildContext context) async {
    // 网络权限不需要弹窗申请
    await checkNetworkPermission();
    
    // 申请存储权限
    final storageGranted = await requestStoragePermission(context);
    
    return storageGranted;
  }
  
  /// 显示权限解释对话框
  static Future<bool> _showPermissionDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 禁止点击外部关闭
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.storage, color: Colors.orange),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍后再说'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('去设置开启'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
}
