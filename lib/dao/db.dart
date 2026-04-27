import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/note.dart';
import '../domain/category.dart';
import '../utils/memo_data_paths.dart';
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
    final dbFolder = await MemoDataPaths.databaseDirectoryPath();
    final dbPath = join(dbFolder, 'momo.db');

    // 3. 打开数据库（支持升级）
    return openDatabase(
      dbPath,
      version: 8, // v8: 分类 uuid / 同步字段，笔记 categoryUuid
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
            categoryUuid TEXT,
            syncStatus TEXT DEFAULT 'pending_upload',
            isDeleted INTEGER DEFAULT 0,
            deletedAt INTEGER
          )
        ''');
        // 创建分类表
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT UNIQUE,
            name TEXT NOT NULL,
            colorValue INTEGER NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            isDeleted INTEGER DEFAULT 0
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
        if (oldVersion < 8) {
          // v8: 分类 uuid / updatedAt / isDeleted；笔记 categoryUuid
          var catCols = await db.rawQuery('PRAGMA table_info(categories)');
          if (!catCols.any((row) => row['name'] == 'uuid')) {
            await db.execute('ALTER TABLE categories ADD COLUMN uuid TEXT');
            print('✅ Added categories.uuid');
          }
          catCols = await db.rawQuery('PRAGMA table_info(categories)');
          if (!catCols.any((row) => row['name'] == 'updatedAt')) {
            await db.execute('ALTER TABLE categories ADD COLUMN updatedAt INTEGER');
            print('✅ Added categories.updatedAt');
            await db.execute('UPDATE categories SET updatedAt = createdAt WHERE updatedAt IS NULL');
          }
          catCols = await db.rawQuery('PRAGMA table_info(categories)');
          if (!catCols.any((row) => row['name'] == 'isDeleted')) {
            await db.execute('ALTER TABLE categories ADD COLUMN isDeleted INTEGER DEFAULT 0');
            print('✅ Added categories.isDeleted');
          }
          final cats = await db.query('categories');
          for (final row in cats) {
            final u = row['uuid'] as String?;
            if (u == null || u.isEmpty) {
              await db.update(
                'categories',
                {
                  'uuid': UuidGenerator.generate(),
                  'updatedAt': row['updatedAt'] ?? row['createdAt'],
                },
                where: 'id = ?',
                whereArgs: [row['id']],
              );
            }
          }
          var noteCols = await db.rawQuery('PRAGMA table_info(notes)');
          if (!noteCols.any((row) => row['name'] == 'categoryUuid')) {
            await db.execute('ALTER TABLE notes ADD COLUMN categoryUuid TEXT');
            print('✅ Added notes.categoryUuid');
          }
          await db.rawUpdate('''
            UPDATE notes
            SET categoryUuid = (
              SELECT c.uuid FROM categories AS c WHERE c.id = notes.categoryId
            )
            WHERE categoryId IS NOT NULL
          ''');
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
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.update(
      'notes',
      {
        'archived': archived ? 1 : 0,
        'updatedAt': now,
        'syncStatus': 'pending_upload',
      },
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

  Future<String?> querySyncContentHash(String noteUuid) async {
    final db = await instance.db;
    final rows = await db.query(
      'sync_meta',
      columns: ['content_hash'],
      where: 'note_uuid = ?',
      whereArgs: [noteUuid],
    );
    if (rows.isEmpty) return null;
    return rows.first['content_hash'] as String?;
  }

  /// 合并远程与本地分类（按 uuid，取 updatedAt 较新者）后写入
  Future<void> upsertCategoryFromSync(Category c) async {
    if (c.uuid == null || c.uuid!.isEmpty) return;
    final existing = await queryCategoryByUuid(c.uuid!);
    if (existing == null) {
      await insertCategory(
        Category(
          uuid: c.uuid,
          name: c.name,
          colorValue: c.colorValue,
          createdAt: c.createdAt,
          updatedAt: c.updatedAt,
          isDeleted: c.isDeleted,
        ),
      );
      return;
    }
    // 仅用「严格更旧」跳过，避免与远程同版本时漏更新；占位分类时间戳为 1，会被远程覆盖
    if (existing.updatedAt > c.updatedAt) return;
    final db = await instance.db;
    await db.update(
      'categories',
      {
        'name': c.name,
        'colorValue': c.colorValue,
        'updatedAt': c.updatedAt,
        'isDeleted': c.isDeleted ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [existing.id],
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
    final now = DateTime.now().millisecondsSinceEpoch;
    final uuid = (category.uuid != null && category.uuid!.isNotEmpty)
        ? category.uuid
        : UuidGenerator.generate();
    return db.insert('categories', {
      'uuid': uuid,
      'name': category.name,
      'colorValue': category.colorValue,
      'createdAt': category.createdAt,
      'updatedAt': category.updatedAt > 0 ? category.updatedAt : now,
      'isDeleted': category.isDeleted ? 1 : 0,
    });
  }

  Future<List<Category>> queryAllCategories() async {
    final db = await instance.db;
    final maps = await db.query(
      'categories',
      where: 'isDeleted = 0 OR isDeleted IS NULL',
      orderBy: 'createdAt ASC',
    );
    return maps.map((e) => Category.fromMap(e)).toList();
  }

  /// 含已软删分类（同步合并用）
  Future<List<Category>> queryAllCategoriesForSync() async {
    final db = await instance.db;
    final maps = await db.query('categories', orderBy: 'createdAt ASC');
    return maps.map((e) => Category.fromMap(e)).toList();
  }

  Future<Category?> queryCategoryByUuid(String uuid) async {
    final db = await instance.db;
    final maps = await db.query(
      'categories',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (maps.isNotEmpty) {
      return Category.fromMap(maps.first);
    }
    return null;
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
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.update(
      'categories',
      {
        'uuid': category.uuid,
        'name': category.name,
        'colorValue': category.colorValue,
        'createdAt': category.createdAt,
        'updatedAt': now,
        'isDeleted': category.isDeleted ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// 软删除分类（保留 uuid 供同步）
  /// 分类同步入库后，按 [categoryUuid] 回填 [categoryId]，修复「分类已有但笔记仍显示未分类」
  Future<void> relinkNoteCategoryIdsFromUuids() async {
    final db = await instance.db;
    final rows = await db.query(
      'notes',
      columns: ['uuid', 'categoryId', 'categoryUuid'],
      where: 'categoryUuid IS NOT NULL AND categoryUuid != ?',
      whereArgs: [''],
    );
    for (final row in rows) {
      final uid = (row['categoryUuid'] as String?)?.trim();
      if (uid == null || uid.isEmpty) continue;
      final cat = await queryCategoryByUuid(uid);
      if (cat?.id == null || cat!.isDeleted) continue;
      final nid = row['categoryId'] as int?;
      if (nid == cat.id) continue;
      await db.update(
        'notes',
        {'categoryId': cat.id},
        where: 'uuid = ?',
        whereArgs: [row['uuid']],
      );
    }
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'notes',
      {
        'categoryId': null,
        'categoryUuid': null,
        'syncStatus': 'pending_upload',
      },
      where: 'categoryId = ?',
      whereArgs: [id],
    );
    return db.update(
      'categories',
      {'isDeleted': 1, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );
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
