import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

import '../domain/note.dart';
import '../domain/category.dart';
import '../sync/models/sync_item_vocabulary.dart';
import 'sync_item_dao.dart';
import '../utils/memo_data_paths.dart';
import '../utils/uuid_generator.dart';


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
      version: 9, // v9: sync_items（Joplin 式 item 状态，供后续 Synchronizer）
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
        await _createSyncItemsTable(db);
        await _backfillSyncItems(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 从 v1 升级到 v2：添加 deltaContent 列
        if (oldVersion < 2) {
          // 检查并添加 deltaContent 列（幂等）
          final columns = await db.rawQuery('PRAGMA table_info(notes)');
          final hasDeltaColumn = columns.any((row) => row['name'] == 'deltaContent');

          if (!hasDeltaColumn) {
            await db.execute('ALTER TABLE notes ADD COLUMN deltaContent TEXT');
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
          }
        }
        if (oldVersion < 4) {
          // 检查并添加 archived 列（幂等）
          final columns = await db.rawQuery('PRAGMA table_info(notes)');
          final hasArchivedColumn = columns.any((row) => row['name'] == 'archived');

          if (!hasArchivedColumn) {
            await db.execute('ALTER TABLE notes ADD COLUMN archived INTEGER DEFAULT 0');
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

          // 2. 检查并添加 categoryId 列到 notes 表
          final columns = await db.rawQuery('PRAGMA table_info(notes)');
          final hasCategoryIdColumn = columns.any((row) => row['name'] == 'categoryId');

          if (!hasCategoryIdColumn) {
            await db.execute('ALTER TABLE notes ADD COLUMN categoryId INTEGER');
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
          }
          if (!hasDeletedAtColumn) {
            await db.execute('ALTER TABLE notes ADD COLUMN deletedAt INTEGER');
          }
        }
        if (oldVersion < 8) {
          // v8: 分类 uuid / updatedAt / isDeleted；笔记 categoryUuid
          var catCols = await db.rawQuery('PRAGMA table_info(categories)');
          if (!catCols.any((row) => row['name'] == 'uuid')) {
            await db.execute('ALTER TABLE categories ADD COLUMN uuid TEXT');
          }
          catCols = await db.rawQuery('PRAGMA table_info(categories)');
          if (!catCols.any((row) => row['name'] == 'updatedAt')) {
            await db.execute('ALTER TABLE categories ADD COLUMN updatedAt INTEGER');
            await db.execute('UPDATE categories SET updatedAt = createdAt WHERE updatedAt IS NULL');
          }
          catCols = await db.rawQuery('PRAGMA table_info(categories)');
          if (!catCols.any((row) => row['name'] == 'isDeleted')) {
            await db.execute('ALTER TABLE categories ADD COLUMN isDeleted INTEGER DEFAULT 0');
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
          }
          await db.rawUpdate('''
            UPDATE notes
            SET categoryUuid = (
              SELECT c.uuid FROM categories AS c WHERE c.id = notes.categoryId
            )
            WHERE categoryId IS NOT NULL
          ''');
        }
        if (oldVersion < 9) {
          await _createSyncItemsTable(db);
          await _backfillSyncItems(db);
        }
      },
    );
  }

  static Future<void> _createSyncItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_items(
        item_type TEXT NOT NULL,
        item_id TEXT NOT NULL,
        sync_target_id INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL,
        last_synced_at INTEGER,
        remote_mtime INTEGER,
        remote_etag TEXT,
        content_hash TEXT,
        last_error TEXT,
        error_count INTEGER NOT NULL DEFAULT 0,
        local_updated_at INTEGER,
        PRIMARY KEY (item_type, item_id, sync_target_id)
      )
    ''');
  }

  /// 从 [notes] + [sync_meta] 回填 [sync_items]；并写入 [category_index] 占位行（见 [SyncItemIds]）
  static Future<void> _backfillSyncItems(Database db) async {
    final notes = await db.query('notes');
    for (final row in notes) {
      final uuid = row['uuid']! as String;
      final noteSync = row['syncStatus'] as String? ?? 'pending_upload';
      final itemStatus = noteSync == 'synced'
          ? SyncItemStatus.clean
          : SyncItemStatus.dirtyLocal;

      final meta = await db.query(
        'sync_meta',
        where: 'note_uuid = ?',
        whereArgs: [uuid],
      );
      String? hash;
      int? lastSync;
      if (meta.isNotEmpty) {
        hash = meta.first['content_hash'] as String?;
        lastSync = meta.first['last_sync_at'] as int?;
      }

      await db.insert(
        'sync_items',
        {
          'item_type': SyncItemType.note,
          'item_id': uuid,
          'sync_target_id': 0,
          'sync_status': itemStatus,
          'last_synced_at': lastSync,
          'content_hash': hash,
          'error_count': 0,
          'local_updated_at': row['updatedAt'] as int?,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await db.insert(
      'sync_items',
      {
        'item_type': SyncItemType.categoryIndex,
        'item_id': SyncItemIds.categoryIndexId,
        'sync_target_id': 0,
        'sync_status': SyncItemStatus.dirtyLocal,
        'error_count': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 升级到 UUID 主键
  Future<void> _upgradeToUuid(Database db) async {
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
    final n = await db.insert('notes', note.toDbMap());
    await db.insert(
      'sync_items',
      {
        'item_type': SyncItemType.note,
        'item_id': note.uuid,
        'sync_target_id': 0,
        'sync_status': SyncItemStatus.dirtyLocal,
        'error_count': 0,
        'local_updated_at': note.updatedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return n;
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
    final now = DateTime.now().millisecondsSinceEpoch;
    return instance.update(
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
    final n = await db.update('notes', row, where: where, whereArgs: whereArgs);
    if (n > 0 && where == 'uuid = ?' && whereArgs != null && whereArgs.isNotEmpty) {
      final uuid = whereArgs.first as String;
      final st = row['syncStatus'] as String?;
      if (st == 'synced') {
        // 与远端对齐后的状态；sync_items 由 [markNoteInSync] 等写出
      } else if (st != null) {
        await SyncItemDao.instance.markNoteDirty(
          uuid,
          localUpdatedAt: row['updatedAt'] as int?,
        );
      } else if (row.containsKey('deltaContent') ||
          row.containsKey('content') ||
          row.containsKey('title') ||
          row.containsKey('archived') ||
          row.containsKey('isDeleted') ||
          row.containsKey('categoryId') ||
          row.containsKey('categoryUuid')) {
        await SyncItemDao.instance.markNoteDirty(
          uuid,
          localUpdatedAt: row['updatedAt'] as int?,
        );
        await db.update(
          'notes',
          {'syncStatus': 'pending_upload'},
          where: 'uuid = ?',
          whereArgs: [uuid],
        );
      }
    }
    return n;
  }

  /// 逻辑删除笔记（标记删除，不是物理删除）
  Future<int> delete(String uuid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return instance.update(
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
    await db.delete(
      'sync_items',
      where: 'item_type = ? AND item_id = ? AND sync_target_id = ?',
      whereArgs: [SyncItemType.note, uuid, 0],
    );
    return await db.delete('notes', where: 'uuid = ?', whereArgs: [uuid]);
  }

  /// 恢复已删除的笔记
  Future<int> restoreNote(String uuid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return instance.update(
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

  // 更新笔记同步状态（会走 [update] 的 sync_items 维护逻辑）
  Future<int> updateSyncStatus(String uuid, String status) async {
    return instance.update(
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

  /// 以 [sync_items] 为准：非 `clean` 需同步；无 `sync_items` 行时退回 [Note.syncStatus]
  Future<List<Note>> getNotesToSync() async {
    final db = await instance.db;
    final raw = await db.rawQuery('''
      SELECT n.* FROM notes n
      WHERE (n.isDeleted = 0 OR n.isDeleted IS NULL)
        AND (
          EXISTS (
            SELECT 1 FROM sync_items s
            WHERE s.item_type = ?
              AND s.item_id = n.uuid
              AND s.sync_target_id = 0
              AND s.sync_status != ?
          )
          OR (
            NOT EXISTS (
              SELECT 1 FROM sync_items s
              WHERE s.item_type = ? AND s.item_id = n.uuid AND s.sync_target_id = 0
            ) AND n.syncStatus != 'synced'
          )
        )
      ORDER BY n.createdAt DESC
    ''', [
      SyncItemType.note,
      SyncItemStatus.clean,
      SyncItemType.note,
    ]);
    return raw.map(Note.fromMap).toList();
  }

  // ==================== 分类相关操作 ====================

  Future<int> insertCategory(Category category) async {
    final db = await instance.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final uuid = (category.uuid != null && category.uuid!.isNotEmpty)
        ? category.uuid
        : UuidGenerator.generate();
    final id = await db.insert('categories', {
      'uuid': uuid,
      'name': category.name,
      'colorValue': category.colorValue,
      'createdAt': category.createdAt,
      'updatedAt': category.updatedAt > 0 ? category.updatedAt : now,
      'isDeleted': category.isDeleted ? 1 : 0,
    });
    await SyncItemDao.instance.markCategoryIndexDirty();
    return id;
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
    final n = await db.update(
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
    if (n > 0) {
      await SyncItemDao.instance.markCategoryIndexDirty();
    }
    return n;
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
    final affected = await db.query(
      'notes',
      columns: ['uuid'],
      where: 'categoryId = ?',
      whereArgs: [id],
    );
    for (final row in affected) {
      final u = row['uuid']! as String;
      await instance.update(
        {
          'categoryId': null,
          'categoryUuid': null,
          'syncStatus': 'pending_upload',
          'updatedAt': now,
        },
        where: 'uuid = ?',
        whereArgs: [u],
      );
    }
    final c = await db.update(
      'categories',
      {'isDeleted': 1, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (c > 0) {
      await SyncItemDao.instance.markCategoryIndexDirty();
    }
    return c;
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
    }
  }

  /// 重新打开数据库
  /// 用于同步完成后恢复连接
  Future<void> reopen() async {
    if (_db == null) {
      _db = await _open();
    }
  }
}
