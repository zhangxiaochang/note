import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 权限管理工具类
class PermissionManager {
  
  /// 申请存储权限 - 适配 Android 13+
  static Future<bool> requestStoragePermission(BuildContext context) async {
    // Android 13+ (API 33+) 使用新的媒体权限
    final photos = await Permission.photos.request();
    
    print('媒体权限状态: $photos');
    
    // 如果已经授权，直接返回
    if (photos.isGranted) {
      return true;
    }
    
    // 如果是首次拒绝或限制，弹出对话框引导用户
    if (photos.isDenied) {
      final shouldRequest = await _showPermissionDialog(
        context,
        title: '需要存储权限',
        content: '应用需要访问媒体文件的权限来同步笔记中的图片和附件。请点击"允许"开启权限。',
      );
      
      if (shouldRequest) {
        // 再次申请权限，这次会弹出系统权限对话框
        final result = await Permission.photos.request();
        return result.isGranted;
      }
      return false;
    }
    
    // 如果被永久拒绝
    if (photos.isPermanentlyDenied) {
      final shouldShow = await _showPermissionDialog(
        context,
        title: '权限被永久拒绝',
        content: '存储权限被永久拒绝。请在系统设置中找到本应用，手动开启"文件和媒体"权限。',
      );
      
      if (shouldShow) {
        await openAppSettings();
      }
      return false;
    }
    
    return false;
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
