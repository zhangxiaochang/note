import 'package:uuid/uuid.dart';

/// UUID 生成工具类
class UuidGenerator {
  static final _uuid = Uuid();

  /// 生成 UUID v4
  static String generate() {
    return _uuid.v4();
  }

  /// 生成紧凑格式 UUID（去掉连字符）
  static String generateCompact() {
    return _uuid.v4().replaceAll('-', '');
  }

  /// 从 UUID 生成目录分片（前2个字符）
  static String getDirectoryShard(String uuid) {
    if (uuid.isEmpty) return '00';
    final shard = uuid.substring(0, 2);
    return shard.toLowerCase();
  }

  /// 验证 UUID 格式
  static bool isValid(String uuid) {
    try {
      Uuid.parse(uuid);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 生成图片文件名（包含 UUID 和时间戳）
  static String generateImageFileName(String uuid, String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = originalName.split('.').last;
    return '${uuid}_$timestamp.$extension';
  }
}
