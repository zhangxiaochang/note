import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../dao/db.dart';
import '../domain/note.dart';

class NoteBackupService {
  final DB _db = DB.instance;

  Future<String> exportToJson() async {
    final notes = await _db.queryAll();
    final jsonList = notes.map((note) => note.toJsonMap()).toList();
    return jsonEncode(jsonList);
  }

  Future<int> importFromJsonFile(String filePath) async {
    if (!await File(filePath).exists()) {
      throw Exception('文件不存在: $filePath');
    }
    final jsonString = await File(filePath).readAsString();
    return importFromJsonString(jsonString);
  }

  Future<int> importFromJsonString(String jsonString) async {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return _importNotesFromJsonList(jsonList);
  }

  Future<int> _importNotesFromJsonList(List<dynamic> jsonList) async {
    final db = await _db.db;
    int importedCount = 0;

    for (final item in jsonList) {
      if (item is! Map<String, dynamic>) continue;

      try {
        final note = Note(
          title: item['title'] as String? ?? '',
          content: item['content'] as String? ?? '',
          deltaContent: item['deltaContent'] is List
              ? List.from(item['deltaContent'])
              : Note.emptyDelta,
          createdAt:
              (item['createdAt'] as int?) ??
              DateTime.now().millisecondsSinceEpoch,
          updatedAt:
              (item['updatedAt'] as int?) ??
              DateTime.now().millisecondsSinceEpoch,
        );

        await db.insert(
          'notes',
          note.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        importedCount++;
      } catch (e) {
        print('跳过无效笔记条目: $item, 错误: $e');
      }
    }
    return importedCount;
  }

  String generateBackupFileName() {
    final timestamp = DateTime.now().microsecondsSinceEpoch ~/ 1000;
    return 'momo_notes_backup_$timestamp.json';
  }
}
