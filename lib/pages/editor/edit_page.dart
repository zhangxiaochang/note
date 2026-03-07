import 'package:flutter/material.dart';
import 'package:project/pages/editor/quill_edit_page.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import '../../domain/category.dart';
import '../../utils/page_routes.dart';
import 'dart:convert';

class EditPage extends StatefulWidget {
  final Note? note;
  final bool readOnly;
  final String? heroTag;

  const EditPage({this.note, this.readOnly = false, this.heroTag, super.key});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await DB.instance.queryAllCategories();
    setState(() {
      _categories = categories;
    });
  }

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
    return buffer.toString().replaceAll(RegExp(r'\n+$'), '');
  }

  Future<void> _save(String title, List<dynamic> content, int? categoryId) async {
    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题和内容不能都为空')),
      );
      return;
    }
    final plainText = getPlainText(content);
    final db = await DB.instance.db;

    if (widget.note == null) {
      // ======== 新增 ========
      await db.insert('notes', {
        'title': title,
        'content': plainText,
        'deltaContent': jsonEncode(content),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'categoryId': categoryId,
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
          'categoryId': categoryId,
        },
        where: 'id = ?',
        whereArgs: [widget.note!.id],
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Scaffold(
      body: QuillEditorWidget(
        initialDelta: widget.note?.deltaContent,
        readOnly: widget.readOnly,
        createdAt: widget.note?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        initialTitle: widget.note?.title,
        initialCategoryId: widget.note?.categoryId,
        categories: _categories,
        onSave: widget.readOnly ? null : (title, content, categoryId) {
          _save(title, content, categoryId);
        },
      ),
    );

    // 如果有 heroTag，包裹在 Hero 中
    if (widget.heroTag != null) {
      content = NoteHero(
        tag: widget.heroTag!,
        child: content,
      );
    }

    return content;
  }
}
