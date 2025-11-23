class Note {
  int? id;
  final String title;
  final String content;
  final int createdAt;
  final int updatedAt;

  Note({this.id, required this.title, required this.content, required this.createdAt,required this.updatedAt});

  Map<String, dynamic> toMap() =>
      {'id': id, 'title': title, 'content': content, 'createdAt': createdAt,'updatedAt':updatedAt};

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    id: map['id'] as int?,
    title: (map['title'] as String?) ?? '',
    content: (map['content'] as String?) ?? '',
    createdAt: (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
    updatedAt: (map['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,

  );
}