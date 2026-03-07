import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/note.dart';
import '../domain/category.dart';
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
      version: 5, // 👈 升级版本号到 5，添加分类功能
      onCreate: (db, version) async {
        // 创建笔记表
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            deltaContent TEXT,
            createdAt INTEGER,
            updatedAt INTEGER,
            archived INTEGER DEFAULT 0,
            categoryId INTEGER
          )
        ''');
        // 创建分类表
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            colorValue INTEGER NOT NULL,
            createdAt INTEGER NOT NULL
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
        if (oldVersion < 3) {
          // 检查并添加 updatedAt 列（幂等）
          final columns = await db.rawQuery('PRAGMA table_info(notes)');
          final hasUpdatedAtColumn = columns.any((row) => row['name'] == 'updatedAt');

          if (!hasUpdatedAtColumn) {
            await db.execute('ALTER TABLE notes ADD COLUMN updatedAt INTEGER');
            print('✅ Added updatedAt column');
          }
        }
        if (oldVersion < 4) {
          // 检查并添加 archived 列（幂等）
          final columns = await db.rawQuery('PRAGMA table_info(notes)');
          final hasArchivedColumn = columns.any((row) => row['name'] == 'archived');

          if (!hasArchivedColumn) {
            await db.execute('ALTER TABLE notes ADD COLUMN archived INTEGER DEFAULT 0');
            print('✅ Added archived column');
          }
        }
        if (oldVersion < 5) {
          // v5: 添加分类功能
          // 1. 创建分类表
          await db.execute('''
            CREATE TABLE IF NOT EXISTS categories(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              colorValue INTEGER NOT NULL,
              createdAt INTEGER NOT NULL
            )
          ''');
          print('✅ Created categories table');

          // 2. 检查并添加 categoryId 列到 notes 表
          final columns = await db.rawQuery('PRAGMA table_info(notes)');
          final hasCategoryIdColumn = columns.any((row) => row['name'] == 'categoryId');

          if (!hasCategoryIdColumn) {
            await db.execute('ALTER TABLE notes ADD COLUMN categoryId INTEGER');
            print('✅ Added categoryId column to notes');
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

  // ==================== 笔记相关操作 ====================

  Future<int> insert(Note note) async {
    final db = await instance.db;
    return db.insert('notes', note.toDbMap());
  }

  Future<List<Note>> queryAll() async {
    final db = await instance.db;
    final maps = await db.query('notes', orderBy: 'createdAt DESC');
    return maps.map((e) => Note.fromMap(e)).toList();
  }

  Future<List<Note>> queryActive() async {
    final db = await instance.db;
    final maps = await db.query(
      'notes',
      where: 'archived = ? OR archived IS NULL',
      whereArgs: [0],
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => Note.fromMap(e)).toList();
  }

  Future<List<Note>> queryArchived() async {
    final db = await instance.db;
    final maps = await db.query(
      'notes',
      where: 'archived = ?',
      whereArgs: [1],
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => Note.fromMap(e)).toList();
  }

  Future<List<Note>> queryByCategory(int? categoryId) async {
    final db = await instance.db;
    if (categoryId == null) {
      // 查询未分类的笔记
      final maps = await db.query(
        'notes',
        where: '(archived = ? OR archived IS NULL) AND (categoryId IS NULL)',
        whereArgs: [0],
        orderBy: 'createdAt DESC',
      );
      return maps.map((e) => Note.fromMap(e)).toList();
    } else {
      final maps = await db.query(
        'notes',
        where: '(archived = ? OR archived IS NULL) AND categoryId = ?',
        whereArgs: [0, categoryId],
        orderBy: 'createdAt DESC',
      );
      return maps.map((e) => Note.fromMap(e)).toList();
    }
  }

  Future<int> archiveNote(int id, bool archived) async {
    final db = await instance.db;
    return db.update(
      'notes',
      {'archived': archived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
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

  // ==================== 分类相关操作 ====================

  Future<int> insertCategory(Category category) async {
    final db = await instance.db;
    return db.insert('categories', category.toMap());
  }

  Future<List<Category>> queryAllCategories() async {
    final db = await instance.db;
    final maps = await db.query('categories', orderBy: 'createdAt ASC');
    return maps.map((e) => Category.fromMap(e)).toList();
  }

  Future<Category?> queryCategoryById(int id) async {
    final db = await instance.db;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Category.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateCategory(Category category) async {
    final db = await instance.db;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.db;
    // 删除分类时，将该分类下的笔记设为未分类
    await db.update(
      'notes',
      {'categoryId': null},
      where: 'categoryId = ?',
      whereArgs: [id],
    );
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getNoteCountByCategory(int categoryId) async {
    final db = await instance.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notes WHERE categoryId = ? AND (archived = 0 OR archived IS NULL)',
      [categoryId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getUncategorizedNoteCount() async {
    final db = await instance.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notes WHERE (categoryId IS NULL OR categoryId = -1) AND (archived = 0 OR archived IS NULL)',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getTotalActiveNoteCount() async {
    final db = await instance.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notes WHERE archived = 0 OR archived IS NULL',
    );
    return (result.first['count'] as int?) ?? 0;
  }
}
