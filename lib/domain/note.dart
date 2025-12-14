import 'dart:convert';

class Note {
  int? id;
  final String title;
  final String content;
  final List<dynamic>? deltaContent; // 👈 富文本 Delta JSON
  final int createdAt;
  final int updatedAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.deltaContent,
    required this.createdAt,
    required this.updatedAt,
  });

  // ✅ 修复：包含 deltaContent
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'deltaContent': deltaContent, // 👈 必须添加！
    'createdAt': createdAt,
    'updatedAt': updatedAt,
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

    return Note(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '', // 如果 content 是纯文本摘要，保留
      deltaContent: delta, // ✅ 确保是 List<dynamic>
      createdAt: (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: (map['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
  static const emptyDelta = [{'insert': '\n'}];
}
