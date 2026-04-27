import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/note.dart';

/// 用于跨设备一致的笔记内容指纹（排除 syncStatus、categoryId，使用 categoryUuid）。
String noteSyncContentHash(Note note) {
  final delta = note.deltaContent ?? Note.emptyDelta;
  final canonical = SplayTreeMap<String, dynamic>.from({
    'archived': note.archived,
    'categoryUuid': note.categoryUuid,
    'content': note.content,
    'createdAt': note.createdAt,
    'deltaContent': delta,
    'deletedAt': note.deletedAt,
    'isDeleted': note.isDeleted,
    'title': note.title,
    'updatedAt': note.updatedAt,
    'uuid': note.uuid,
  });
  final bytes = utf8.encode(jsonEncode(canonical));
  return sha256.convert(bytes).toString();
}
