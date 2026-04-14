import 'dart:convert';

class Note {
  final String uuid;
  final String title;
  final String content;
  final List<dynamic>? deltaContent; // 👈 富文本 Delta JSON
  final int createdAt;
  final int updatedAt;
  final bool archived;
  final int? categoryId; // 👈 分类ID，可为空表示未分类
  final String syncStatus; // 同步状态: 'synced' | 'pending_upload' | 'pending_download'
  final bool isDeleted; // 👈 删除标记：true 表示已删除
  final int? deletedAt; // 👈 删除时间戳，用于冲突判断

  Note({
    required this.uuid,
    required this.title,
    required this.content,
    required this.deltaContent,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
    this.categoryId,
    this.syncStatus = 'pending_upload',
    this.isDeleted = false,
    this.deletedAt,
  });

  // ✅ 修复：包含 deltaContent、archived 和 categoryId
  Map<String, dynamic> toMap() => {
    'uuid': uuid,
    'title': title,
    'content': content,
    'deltaContent': deltaContent, // 👈 必须添加！
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'archived': archived ? 1 : 0,
    'categoryId': categoryId,
    'syncStatus': syncStatus,
    'isDeleted': isDeleted ? 1 : 0,
    'deletedAt': deletedAt,
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

    // 处理 syncStatus 字段
    String status = 'pending_upload';
    final rawSyncStatus = map['syncStatus'];
    if (rawSyncStatus != null && rawSyncStatus is String) {
      status = rawSyncStatus;
    }

    // 处理 isDeleted 字段
    bool isDeleted = false;
    final rawIsDeleted = map['isDeleted'];
    if (rawIsDeleted != null) {
      if (rawIsDeleted is int) {
        isDeleted = rawIsDeleted == 1;
      } else if (rawIsDeleted is bool) {
        isDeleted = rawIsDeleted;
      }
    }

    // 处理 deletedAt 字段
    int? deletedAt;
    final rawDeletedAt = map['deletedAt'];
    if (rawDeletedAt != null) {
      if (rawDeletedAt is int) {
        deletedAt = rawDeletedAt;
      }
    }

    return Note(
      uuid: (map['uuid'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '', // 如果 content 是纯文本摘要，保留
      deltaContent: delta, // ✅ 确保是 List<dynamic>
      createdAt: (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: (map['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      archived: isArchived,
      categoryId: catId,
      syncStatus: status,
      isDeleted: isDeleted,
      deletedAt: deletedAt,
    );
  }
  static const emptyDelta = [{'insert': '\n'}];


  // 用于 JSON 文件导出（deltaContent 保持为 List）
  Map<String, dynamic> toJsonMap() {
    return {
      'uuid': uuid,
      'title': title,
      'content': content,
      'deltaContent': deltaContent ?? emptyDelta,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'archived': archived,
      'categoryId': categoryId,
      'syncStatus': syncStatus,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
    };
  }

// 用于数据库存储（deltaContent 转为 String）
  Map<String, dynamic> toDbMap() {
    return {
      'uuid': uuid,
      'title': title,
      'content': content,
      'deltaContent': jsonEncode(deltaContent ?? emptyDelta), // 👈 转字符串
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'archived': archived ? 1 : 0,
      'categoryId': categoryId,
      'syncStatus': syncStatus,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt,
    };
  }

  Note copyWith({
    String? uuid,
    String? title,
    String? content,
    List<dynamic>? deltaContent,
    int? createdAt,
    int? updatedAt,
    bool? archived,
    int? categoryId,
    String? syncStatus,
    bool? isDeleted,
    int? deletedAt,
  }) {
    return Note(
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      content: content ?? this.content,
      deltaContent: deltaContent ?? this.deltaContent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived ?? this.archived,
      categoryId: categoryId ?? this.categoryId,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
