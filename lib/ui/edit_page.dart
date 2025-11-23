import 'package:flutter/material.dart';
import '../dao/db.dart';
import '../domain/note.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
class EditPage extends StatefulWidget {
  final Note? note;
  const EditPage({this.note, super.key});
  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  @override
  void initState() {
    super.initState();
    // 有旧数据就填进去，没有就空着
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题和内容不能都为空')),
      );
      return;
    }
    final db = await DB.instance.db;   // 拿到数据库实例
    if (widget.note == null) {
      // ======== 新增 ========
      await db.insert('notes', {
        'title': title,
        'content': content,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      // ======== 更新 ========
      await db.update(
        'notes',
        {
          'title': title,
          'content': content,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [widget.note!.id],
      );
    }
    if (mounted) Navigator.of(context).pop(true); // 返回 true 告诉上一页已改动
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新建笔记' : '编辑笔记'),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.save))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '标题'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  decoration: const InputDecoration(
                    labelText: '内容',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ],
          )) ,
    );
  }
}