import 'package:flutter/material.dart';
import 'package:project/pages/editor/quill_edit_page.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import 'dart:convert';
class EditPage extends StatefulWidget {
  final Note? note;
  const EditPage({this.note, super.key});
  @override
  State<EditPage> createState() => _EditPageState();
}
class _EditPageState extends State<EditPage> {

  String getPlainText(List<dynamic> delta) {
    final buffer = StringBuffer();
    for (final op in delta) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        if (insert is String) {
          buffer.write(insert);
        }
      }
    }
    return buffer.toString();
  }
  Future<void> _save(title,content) async {
    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题和内容不能都为空')),
      );
      return;
    }
    final plainText = getPlainText(content);
    final db = await DB.instance.db;   // 拿到数据库实例
    if (widget.note == null) {
      // ======== 新增 ========
      await db.insert('notes', {
        'title': title,
        'content': plainText,
        'deltaContent': jsonEncode(content),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      // ======== 更新 ========
      await db.update(
        'notes',
        {
          'title': title,
          'content': plainText,
          'deltaContent': jsonEncode(content),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [widget.note!.id],
      );
    }
    if (mounted) Navigator.of(context).pop(true); // 返回 true 告诉上一页已改动
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QuillEditorWidget(
          initialTitle:widget.note?.title,
          initialDelta:widget.note?.deltaContent,
          onSave: (title,content) {
            _save(title,content);
          }
      ) ,
    );
  }
}