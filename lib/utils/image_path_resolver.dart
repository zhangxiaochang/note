import 'dart:io';

import 'package:path/path.dart' as path;
import 'memo_data_paths.dart';

class ImagePathResolver {
  static final RegExp _windowsDrivePath = RegExp(r'^[a-zA-Z]:[\\/]');

  static Future<Directory> getAppDir() async {
    return MemoDataPaths.contentRootDirectory();
  }

  static bool isWebUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static bool isFileUri(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri?.scheme == 'file';
  }

  static bool isLocalAbsolutePath(String value) {
    final input = value.trim();
    if (input.isEmpty) return false;
    if (_windowsDrivePath.hasMatch(input)) return true;
    if (input.startsWith('\\\\')) return true;
    return input.startsWith('/');
  }

  static bool isAbsolutePath(String value) {
    return isWebUrl(value) || isFileUri(value) || isLocalAbsolutePath(value);
  }

  static bool isRelativePath(String value) {
    return !isAbsolutePath(value);
  }

  static String _normalizeStoredPath(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) return normalized;
    normalized = normalized.replaceAll('\\', '/');
    normalized = normalized.replaceAll(RegExp(r'^\./+'), '');
    normalized = normalized.replaceAll(RegExp(r'/+'), '/');
    return normalized;
  }

  static String _decodeIfNeeded(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }

  static Future<String> toAbsolutePath(String relativePath) async {
    final source = relativePath.trim();
    if (source.isEmpty) return source;

    if (isWebUrl(source)) {
      return source;
    }
    if (isFileUri(source)) {
      try {
        final result = Uri.parse(source).toFilePath(windows: Platform.isWindows);
        return result;
      } catch (_) {
        return source;
      }
    }
    if (isLocalAbsolutePath(source)) {
      return _decodeIfNeeded(source);
    }

    final appDir = await getAppDir();
    final normalized = _normalizeStoredPath(source);
    final result = path.normalize(path.join(appDir.path, normalized));
    return result;
  }

  static Future<String> toRelativePath(String absolutePath) async {
    final source = absolutePath.trim();
    if (source.isEmpty) return source;
    if (isWebUrl(source)) return source;

    final localPath = isFileUri(source)
        ? (() {
            try {
              return Uri.parse(source).toFilePath(windows: Platform.isWindows);
            } catch (_) {
              return source;
            }
          })()
        : source;
    if (!isLocalAbsolutePath(localPath)) return _normalizeStoredPath(localPath);

    final appDir = await getAppDir();
    final relative = path.relative(localPath, from: appDir.path);
    return _normalizeStoredPath(relative);
  }

  static Future<void> ensureImageDir() async {
    final appDir = await getAppDir();
    final imageDir = Directory(path.join(appDir.path, 'images'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
  }

  static Future<String> getImageDir() async {
    await ensureImageDir();
    final appDir = await getAppDir();
    return path.join(appDir.path, 'images');
  }

  static String generateImageFileName(String uuid, String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(originalName).toLowerCase();
    return '${uuid}_$timestamp$extension';
  }

  static Future<String> resolveImagePath(String imagePath) async {
    final source = imagePath.trim();
    if (source.isEmpty) return source;

    if (isWebUrl(source)) {
      return source;
    }
    if (isFileUri(source)) {
      try {
        final result = Uri.parse(source).toFilePath(windows: Platform.isWindows);
        return result;
      } catch (_) {
        return source;
      }
    }
    if (isLocalAbsolutePath(source)) {
      return _decodeIfNeeded(source);
    }

    final result = await toAbsolutePath(source);
    return result;
  }
}
