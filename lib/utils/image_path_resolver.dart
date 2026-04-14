import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 图片路径解析器
class ImagePathResolver {
  /// 获取应用文档目录
  static Future<Directory> getAppDir() async {
    return await getApplicationDocumentsDirectory();
  }

  /// 相对路径转绝对路径
  static Future<String> toAbsolutePath(String relativePath) async {
    if (isAbsolutePath(relativePath)) {
      return relativePath;
    }
    final appDir = await getAppDir();
    return path.join(appDir.path, relativePath);
  }

  /// 绝对路径转相对路径
  static Future<String> toRelativePath(String absolutePath) async {
    if (isRelativePath(absolutePath)) {
      return absolutePath;
    }
    final appDir = await getAppDir();
    final relative = path.relative(absolutePath, from: appDir.path);
    return relative.replaceAll('\\', '/'); // 统一使用正斜杠
  }

  /// 检查是否为绝对路径
  static bool isAbsolutePath(String path) {
    // Windows: C:\... 或 D:/...
    // macOS/Linux: /...
    return path.contains(':/') || 
           path.contains(':\\') || 
           path.startsWith('/') || 
           path.startsWith('\\');
  }

  /// 检查是否为相对路径
  static bool isRelativePath(String path) {
    return !isAbsolutePath(path);
  }

  /// 确保图片目录存在
  static Future<void> ensureImageDir() async {
    final appDir = await getAppDir();
    final imageDir = Directory('${appDir.path}/images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
  }

  /// 获取图片目录
  static Future<String> getImageDir() async {
    await ensureImageDir();
    final appDir = await getAppDir();
    return '${appDir.path}/images';
  }

  /// 生成图片文件名（包含 UUID 和时间戳）
  static String generateImageFileName(String uuid, String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(originalName).toLowerCase();
    return '${uuid}_$timestamp$extension';
  }

  /// 解析图片路径（兼容旧的绝对路径和新的相对路径）
  static Future<String> resolveImagePath(String imagePath) async {
    print('resolveImagePath: 输入路径 $imagePath');
    print('resolveImagePath: isAbsolutePath = ${isAbsolutePath(imagePath)}');
    if (isAbsolutePath(imagePath)) {
      // 旧的绝对路径，直接使用
      print('resolveImagePath: 使用绝对路径 $imagePath');
      return imagePath;
    } else {
      // 新的相对路径，转换为绝对路径
      final absolutePath = await toAbsolutePath(imagePath);
      print('resolveImagePath: 转换为绝对路径 $absolutePath');
      return absolutePath;
    }
  }
}
