import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/note.dart';
import '../domain/category.dart';
import '../utils/uuid_generator.dart';
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
      version: 7, // 👈 升级版本号到 7，添加 deleted_at 字段
      onCreate: (db, version) async {
        // 创建笔记表（UUID 主键）
        await db.execute('''
          CREATE TABLE notes(
            uuid TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            deltaContent TEXT,
            createdAt INTEGER,
            updatedAt INTEGER,
            archived INTEGER DEFAULT 0,
            categoryId INTEGER,
            syncStatus TEXT DEFAULT 'pending_upload',
            isDeleted INTEGER DEFAULT 0,
            deletedAt INTEGER
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
        // 创建同步元数据表
        await db.execute('''
          CREATE TABLE sync_meta(
            note_uuid TEXT PRIMARY KEY,
            local_updated_at INTEGER,
            remote_updated_at INTEGER,
            sync_status TEXT DEFAULT 'pending_upload',
            content_hash TEXT,
            last_sync_at INTEGER,
            retry_count INTEGER DEFAULT 0,
            FOREIGN KEY (note_uuid) REFERENCES notes(uuid) ON DELETE CASCADE
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
                ? jsonEncode(Note.emptyDelta)
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
        if (oldVersion < 6) {
          // v6: 改为 UUID 主键
          await _upgradeToUuid(db);
        }
        if (oldVersion < 7) {
          // v7: 添加 isDeleted 和 deletedAt 字段（逻辑删除）
          final columns = await db.rawQuery('PRAGMA table_info(notes)');
          final hasIsDeletedColumn = columns.any((row) => row['name'] == 'isDeleted');
          final hasDeletedAtColumn = columns.any((row) => row['name'] == 'deletedAt');

          if (!hasIsDeletedColumn) {
            await db.execute('ALTER TABLE notes ADD COLUMN isDeleted INTEGER DEFAULT 0');
            print('✅ Added isDeleted column to notes');
          }
          if (!hasDeletedAtColumn) {
            await db.execute('ALTER TABLE notes ADD COLUMN deletedAt INTEGER');
            print('✅ Added deletedAt column to notes');
          }
        }
      },
    );
  }

  // 升级到 UUID 主键
  Future<void> _upgradeToUuid(Database db) async {
    print('🔄 开始升级到 UUID 主键...');
    
    // 1. 创建临时表
    await db.execute('''
      CREATE TABLE notes_new(
        uuid TEXT PRIMARY KEY,
        title TEXT,
        content TEXT,
        deltaContent TEXT,
        createdAt INTEGER,
        updatedAt INTEGER,
        archived INTEGER DEFAULT 0,
        categoryId INTEGER,
        syncStatus TEXT DEFAULT 'pending_upload',
        isDeleted INTEGER DEFAULT 0,
        deletedAt INTEGER
      )
    ''');
    
    // 2. 迁移数据（为每条笔记生成 UUID）
    final oldNotes = await db.query('notes');
    for (final note in oldNotes) {
      final uuid = UuidGenerator.generate();
      await db.insert('notes_new', {
        'uuid': uuid,
        'title': note['title'],
        'content': note['content'],
        'deltaContent': note['deltaContent'],
        'createdAt': note['createdAt'],
        'updatedAt': note['updatedAt'],
        'archived': note['archived'] ?? 0,
        'categoryId': note['categoryId'],
        'syncStatus': 'pending_upload',
      });
    }
    
    // 3. 删除旧表，重命名新表
    await db.execute('DROP TABLE notes');
    await db.execute('ALTER TABLE notes_new RENAME TO notes');
    
    // 4. 创建同步元数据表
    await db.execute('''
      CREATE TABLE sync_meta(
        note_uuid TEXT PRIMARY KEY,
        local_updated_at INTEGER,
        remote_updated_at INTEGER,
        sync_status TEXT DEFAULT 'pending_upload',
        content_hash TEXT,
        last_sync_at INTEGER,
        retry_count INTEGER DEFAULT 0,
        FOREIGN KEY (note_uuid) REFERENCES notes(uuid) ON DELETE CASCADE
      )
    ''');
    
    // 5. 初始化同步元数据
    final newNotes = await db.query('notes');
    for (final note in newNotes) {
      await db.insert('sync_meta', {
        'note_uuid': note['uuid'],
        'local_updated_at': note['updatedAt'],
        'sync_status': 'pending_upload',
      });
    }
    
    print('✅ 升级到 UUID 主键完成');
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
    final maps = await db.query(
      'notes',
      where: 'isDeleted = 0 OR isDeleted IS NULL',
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => Note.fromMap(e)).toList();
  }

  Future<List<Note>> queryAllIncludingDeleted() async {
    final db = await instance.db;
    final maps = await db.query('notes', orderBy: 'createdAt DESC');
    return maps.map((e) => Note.fromMap(e)).toList();
  }

  Future<List<Note>> queryActive() async {
    final db = await instance.db;
    final maps = await db.query(
      'notes',
      where: '(archived = ? OR archived IS NULL) AND (isDeleted = 0 OR isDeleted IS NULL)',
      whereArgs: [0],
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => Note.fromMap(e)).toList();
  }

  Future<List<Note>> queryArchived() async {
    final db = await instance.db;
    final maps = await db.query(
      'notes',
      where: 'archived = ? AND (isDeleted = 0 OR isDeleted IS NULL)',
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
        where: '(archived = ? OR archived IS NULL) AND (categoryId IS NULL) AND (isDeleted = 0 OR isDeleted IS NULL)',
        whereArgs: [0],
        orderBy: 'createdAt DESC',
      );
      return maps.map((e) => Note.fromMap(e)).toList();
    } else {
      final maps = await db.query(
        'notes',
        where: '(archived = ? OR archived IS NULL) AND categoryId = ? AND (isDeleted = 0 OR isDeleted IS NULL)',
        whereArgs: [0, categoryId],
        orderBy: 'createdAt DESC',
      );
      return maps.map((e) => Note.fromMap(e)).toList();
    }
  }

  /// 查询已删除的笔记（回收站）
  Future<List<Note>> queryDeleted() async {
    final db = await instance.db;
    final maps = await db.query(
      'notes',
      where: 'isDeleted = 1',
      orderBy: 'deletedAt DESC',
    );
    return maps.map((e) => Note.fromMap(e)).toList();
  }

  Future<int> archiveNote(String uuid, bool archived) async {
    final db = await instance.db;
    return db.update(
      'notes',
      {'archived': archived ? 1 : 0},
      where: 'uuid = ?',
      whereArgs: [uuid],
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

  /// 逻辑删除笔记（标记删除，不是物理删除）
  Future<int> delete(String uuid) async {
    final db = await instance.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      'notes',
      {
        'isDeleted': 1,
        'deletedAt': now,
        'updatedAt': now,
        'syncStatus': 'pending_upload',
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// 物理删除笔记（仅在回收站中彻底删除时使用）
  Future<int> deletePermanently(String uuid) async {
    final db = await instance.db;
    return await db.delete('notes', where: 'uuid = ?', whereArgs: [uuid]);
  }

  /// 恢复已删除的笔记
  Future<int> restoreNote(String uuid) async {
    final db = await instance.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      'notes',
      {
        'isDeleted': 0,
        'deletedAt': null,
        'updatedAt': now,
        'syncStatus': 'pending_upload',
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // 根据 UUID 查询笔记
  Future<Note?> queryNoteByUuid(String uuid) async {
    final db = await instance.db;
    final maps = await db.query(
      'notes',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (maps.isNotEmpty) {
      return Note.fromMap(maps.first);
    }
    return null;
  }

  // 更新笔记同步状态
  Future<int> updateSyncStatus(String uuid, String status) async {
    final db = await instance.db;
    return db.update(
      'notes',
      {'syncStatus': status},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // 同步元数据操作
  Future<void> updateSyncMeta(String noteUuid, Map<String, dynamic> data) async {
    final db = await instance.db;
    final existing = await db.query(
      'sync_meta',
      where: 'note_uuid = ?',
      whereArgs: [noteUuid],
    );
    
    if (existing.isNotEmpty) {
      await db.update(
        'sync_meta',
        data,
        where: 'note_uuid = ?',
        whereArgs: [noteUuid],
      );
    } else {
      await db.insert(
        'sync_meta',
        {'note_uuid': noteUuid, ...data},
      );
    }
  }

  // 获取需要同步的笔记
  Future<List<Note>> getNotesToSync() async {
    final db = await instance.db;
    final maps = await db.query(
      'notes',
      where: 'syncStatus != ?',
      whereArgs: ['synced'],
    );
    return maps.map((e) => Note.fromMap(e)).toList();
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
      'SELECT COUNT(*) as count FROM notes WHERE categoryId = ? AND (archived = 0 OR archived IS NULL) AND (isDeleted = 0 OR isDeleted IS NULL)',
      [categoryId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getUncategorizedNoteCount() async {
    final db = await instance.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notes WHERE (categoryId IS NULL OR categoryId = -1) AND (archived = 0 OR archived IS NULL) AND (isDeleted = 0 OR isDeleted IS NULL)',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getTotalActiveNoteCount() async {
    final db = await instance.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notes WHERE (archived = 0 OR archived IS NULL) AND (isDeleted = 0 OR isDeleted IS NULL)',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// 关闭数据库连接
  /// 用于同步前释放文件锁
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      print('DB: 数据库连接已关闭');
    }
  }

  /// 重新打开数据库
  /// 用于同步完成后恢复连接
  Future<void> reopen() async {
    if (_db == null) {
      _db = await _open();
      print('DB: 数据库连接已重新打开');
    }
  }
}
