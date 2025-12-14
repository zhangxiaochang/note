import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/note.dart';
import 'dart:convert';


class DB {
  static final DB instance = DB._init();
  static Database? _db;

  DB._init();

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    // 1. 获取应用文档目录
    final docDir = await getApplicationDocumentsDirectory();
    // 2. 创建子目录并生成完整路径
    final dbFolder = '${docDir.path}/memo';
    await Directory(dbFolder).create(recursive: true);
    final dbPath = join(dbFolder, 'momo.db');

    // 3. 打开数据库（支持升级）
    return openDatabase(
      dbPath,
      version: 2, // 👈 升级版本号
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            deltaContent TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('Upgrading DB from $oldVersion to $newVersion');
        // 从 v1 升级到 v2：添加 deltaContent 列
        if (oldVersion < 2) {
          // 检查并添加 deltaContent 列（幂等）
          final columns = await db.rawQuery('PRAGMA table_info(notes)');
          final hasDeltaColumn = columns.any((row) => row['name'] == 'deltaContent');

          if (!hasDeltaColumn) {
            await db.execute('ALTER TABLE notes ADD COLUMN deltaContent TEXT');
            print('✅ Added deltaContent column');
          }
          // 可选：为已有笔记初始化 deltaContent（用纯文本转 Delta）
          final rows = await db.query('notes');
          for (final row in rows) {
            final plainText = row['content'] as String? ?? '';
            // 构造最简 Delta：{"ops":[{"insert":"your text\n"}]}
            final deltaJson = plainText.isEmpty
                ? Note.emptyDelta
                : _textToDeltaJson(plainText);

            await db.update(
              'notes',
              {'deltaContent': deltaJson},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
      },
    );
  }

  String _textToDeltaJson(String text) {
    if (text.isEmpty) return '[]';
    // 注意：需要转义 JSON 特殊字符（如 "、\、换行等）
    final escaped = jsonEncode(text + '\n'); // jsonEncode 会自动处理转义！
    return '[{"insert":$escaped}]';
  }
  Future<int> insert(Note note) async {
    final db = await instance.db;
    return db.insert('notes', note.toMap());
  }

  Future<List<Note>> queryAll() async {
    final db = await instance.db;
    final maps = await db.query('notes', orderBy: 'createdAt DESC');
    return maps.map((e) => Note.fromMap(e)).toList();
  }

  Future<int> update(
    Map<String, dynamic> row, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await instance.db;
    return db.update('notes', row, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(int id) async {
    final db = await instance.db;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
