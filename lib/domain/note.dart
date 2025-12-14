class Note {
  int? id;
  final String title;
  final String content;
  final String deltaContent; // 👈 富文本 Delta JSON
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

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    id: map['id'] as int?,
    title: (map['title'] as String?) ?? '',
    content: (map['content'] as String?) ?? '',
    deltaContent: (map['deltaContent'] as String?) ?? emptyDelta,
    // 👈 安全默认值
    createdAt:
        (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
    updatedAt:
        (map['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
  );

  static const String emptyDelta = '{"ops":[{"insert":"\\n"}]}';
}
