import 'dart:convert';

class Note {
  int? id;
  final String title;
  final String content;
  final List<dynamic>? deltaContent; // 👈 富文本 Delta JSON
  final int createdAt;
  final int updatedAt;
  final bool archived;
  final int? categoryId; // 👈 分类ID，可为空表示未分类

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.deltaContent,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
    this.categoryId,
  });

  // ✅ 修复：包含 deltaContent、archived 和 categoryId
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'deltaContent': deltaContent, // 👈 必须添加！
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'archived': archived ? 1 : 0,
    'categoryId': categoryId,
  };

  factory Note.fromMap(Map<String, dynamic> map) {
    // 处理 deltaContent：支持 String（JSON）或 List
    List<dynamic> delta;
    final rawDelta = map['deltaContent'];

    if (rawDelta == null) {
      delta = emptyDelta; // 你定义的默认空 Delta
    } else if (rawDelta is String) {
      // 如果存的是 JSON 字符串（如 SQLite / SharedPreferences）
      try {
        delta = jsonDecode(rawDelta) as List<dynamic>;
      } catch (e) {
        // 解析失败，回退到空内容
        delta = emptyDelta;
      }
    } else if (rawDelta is List) {
      // 如果已经是 List（如 Hive 直接存对象）
      delta = rawDelta;
    } else {
      delta = emptyDelta;
    }

    // 处理 archived 字段
    bool isArchived = false;
    final rawArchived = map['archived'];
    if (rawArchived != null) {
      if (rawArchived is int) {
        isArchived = rawArchived == 1;
      } else if (rawArchived is bool) {
        isArchived = rawArchived;
      }
    }

    // 处理 categoryId 字段
    int? catId;
    final rawCategoryId = map['categoryId'];
    if (rawCategoryId != null) {
      if (rawCategoryId is int) {
        catId = rawCategoryId;
      }
    }

    return Note(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '', // 如果 content 是纯文本摘要，保留
      deltaContent: delta, // ✅ 确保是 List<dynamic>
      createdAt: (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: (map['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      archived: isArchived,
      categoryId: catId,
    );
  }
  static const emptyDelta = [{'insert': '\n'}];


  // 用于 JSON 文件导出（deltaContent 保持为 List）
  Map<String, dynamic> toJsonMap() {
    return {
      'title': title,
      'content': content,
      'deltaContent': deltaContent ?? emptyDelta,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'archived': archived,
      'categoryId': categoryId,
    };
  }

// 用于数据库存储（deltaContent 转为 String）
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'deltaContent': jsonEncode(deltaContent ?? emptyDelta), // 👈 转字符串
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'archived': archived ? 1 : 0,
      'categoryId': categoryId,
    };
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    List<dynamic>? deltaContent,
    int? createdAt,
    int? updatedAt,
    bool? archived,
    int? categoryId,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      deltaContent: deltaContent ?? this.deltaContent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived ?? this.archived,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}
