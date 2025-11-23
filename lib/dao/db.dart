import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/note.dart';
import 'package:path_provider/path_provider.dart';


class DB {
  static final DB instance = DB._init();
  static Database? _db;
  DB._init();

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    // 1. 拿到应用文档目录
    final docDir = await getApplicationDocumentsDirectory();
    // 2. 自己定子目录+文件名
    final dbFolder = '${docDir.path}/memo';        // 可随便起名
    await Directory(dbFolder).create(recursive: true); // 确保目录存在
    final dbPath = join(dbFolder, 'momo.db');        // 完整文件路径
    // 3. 打开数据库
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) => db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        createdAt INTEGER,
                updatedAt INTEGER

        )
    '''),
    );
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

  Future<int> update(Map<String, dynamic> row, {String? where, List<Object?>? whereArgs}) async {
    final db = await instance.db;
    return db.update('notes', row, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(int id) async {
    final db = await instance.db;
    return await db.delete(
      'notes',
      where: 'id = ?',      // 根据 id 删除
      whereArgs: [id],      // id 参数
    );
  }
}