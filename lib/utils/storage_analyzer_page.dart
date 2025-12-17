import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class StorageAnalyzerPage extends StatefulWidget {
  @override
  _StorageAnalyzerPageState createState() => _StorageAnalyzerPageState();
}

class _StorageAnalyzerPageState extends State<StorageAnalyzerPage> {
  String _report = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() => _loading = true);
    final report = await _analyzeStorage();
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  Future<String> _analyzeStorage() async {
    final sb = StringBuffer();

    // 获取基础目录
    final tempDir = await getTemporaryDirectory();
    final docsDir = await getApplicationDocumentsDirectory();
    final supportDir = await getApplicationSupportDirectory();

    // Android 特有：WebView 缓存目录（关键！）
    Directory? webviewDir;
    if (Platform.isAndroid) {
      // WebView 缓存通常在这里
      webviewDir = Directory('${tempDir.parent.path}/app_webview');
    }

    // iOS 特有：Caches 目录（有时缓存会放这里）
    Directory? iosCachesDir;
    if (Platform.isIOS) {
      iosCachesDir = Directory('${tempDir.parent.path}/Library/Caches');
    }

    final directories = [
      ('📁 Cache (临时缓存)', tempDir),
      ('📂 Documents (用户数据)', docsDir),
      ('🧰 Support (应用支持)', supportDir),
      if (webviewDir != null) ('🌐 WebView 缓存', webviewDir),
      if (iosCachesDir != null) ('📱 iOS Caches', iosCachesDir),
    ];

    // 额外：尝试扫描根私有目录下的所有子目录（谨慎）
    try {
      await for (final entity in tempDir.parent.list()) {
        if (entity is Directory) {
          final dirName = entity.path.split('/').last;
          // 跳过已包含的
          if (['cache', 'files', 'app_flutter'].contains(dirName)) continue;
          // 添加其他可疑目录（如 app_webview 已单独处理，这里兜底）
          if (dirName.startsWith('app_') || dirName.contains('log') || dirName == 'databases') {
            directories.add(('🔍 其他: $dirName', entity));
          }
        }
      }
    } catch (e) {
      // ignore
    }

    for (final (label, dir) in directories) {
      sb.writeln('=== $label ===');
      try {
        if (!(await dir.exists())) {
          sb.writeln('(不存在)\n');
          continue;
        }

        final totalSize = await _getDirSize(dir);
        sb.writeln('路径: ${dir.path}');
        sb.writeln('大小: ${_formatBytes(totalSize)}');

        final largeFiles = await _listLargeFiles(dir, minSizeBytes: 1 * 1024 * 1024);
        if (largeFiles.isNotEmpty) {
          sb.writeln('大文件 (${largeFiles.length} 个):');
          for (final file in largeFiles.take(20)) {
            final name = file.path.split('/').last;
            final size = await file.length();
            sb.writeln('  • $name (${_formatBytes(size)})');
          }
          if (largeFiles.length > 20) {
            sb.writeln('  ... 还有 ${largeFiles.length - 20} 个');
          }
        }
      } catch (e) {
        sb.writeln('错误: $e');
      }
      sb.writeln('');
    }

    return sb.toString();
  }

  // --- 以下 helper 方法保持不变 ---
  Future<int> _getDirSize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (e) {}
    return total;
  }

  Future<List<File>> _listLargeFiles(Directory dir, {required int minSizeBytes}) async {
    final List<File> large = [];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final size = await entity.length();
          if (size >= minSizeBytes) {
            large.add(entity);
          }
        }
      }
    } catch (e) {}
    large.sort((a, b) {
      final sizeA = a.existsSync() ? a.lengthSync() : 0;
      final sizeB = b.existsSync() ? b.lengthSync() : 0;
      return sizeB.compareTo(sizeA);
    });
    return large;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var index = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index++;
    }
    return '${size.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('存储分析器（增强版）'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _generateReport),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: SelectableText(
          _report.isEmpty ? '分析中...' : _report,
          style: TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ),
    );
  }
}