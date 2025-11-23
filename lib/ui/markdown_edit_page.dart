import 'package:flutter/material.dart';
import 'quill_markdown_editor.dart';  // 导入 QuillMarkdownEditor
import '../domain/note.dart';
import '../dao/db.dart';
import 'editable_app_bar_title.dart';

class MarkdownEditPage extends StatefulWidget {
  final Note? note;

  const MarkdownEditPage({super.key, this.note});

  @override
  State<MarkdownEditPage> createState() => _MarkdownEditPageState();
}

class _MarkdownEditPageState extends State<MarkdownEditPage> {
  late TextEditingController _titleController;
  final GlobalKey<QuillMarkdownEditorState> _editorKey = GlobalKey();
  String _currentContent = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _currentContent = widget.note?.content ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _generateTitleFromContent(String content) {
    if (content.isEmpty) return '';

    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        return trimmed.length > 20 ? '${trimmed.substring(0, 20)}...' : trimmed;
      }
      if (trimmed.startsWith('#')) {
        final title = trimmed.replaceAll(RegExp(r'^#+\s*'), '');
        if (title.isNotEmpty) {
          return title.length > 20 ? '${title.substring(0, 20)}...' : title;
        }
      }
    }

    return content.length > 30 ? '${content.substring(0, 30)}...' : content;
  }

  void _onContentChanged(String content) {
    setState(() {
      _currentContent = content;
    });

    // 如果标题为空，自动生成标题
    if (_titleController.text.trim().isEmpty) {
      final autoTitle = _generateTitleFromContent(content);
      _titleController.text = autoTitle;
    }
  }

  Future<void> _saveNote() async {
    final content = _editorKey.currentState?.currentContent ?? _currentContent;
    final title = _titleController.text.trim().isEmpty
        ? _generateTitleFromContent(content)
        : _titleController.text;

    if (title.isEmpty && content.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('标题和内容不能都为空')),
        );
      }
      return;
    }

    try {
      final db = await DB.instance.db;

      if (widget.note == null) {
        // 新增笔记
        await db.insert('notes', {
          'title': title.isEmpty ? _generateTitleFromContent(content) : title,
          'content': content,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        // 更新现有笔记
        await db.update(
          'notes',
          {
            'title': title.isEmpty ? _generateTitleFromContent(content) : title,
            'content': content,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [widget.note!.id],
        );
      }

      if (mounted) Navigator.of(context).pop(true);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: EditableAppBarTitle(
          controller: _titleController,
          hintText: '输入笔记标题',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: QuillMarkdownEditor(  // 使用 QuillMarkdownEditor
        key: _editorKey,
        initialContent: _currentContent,
        onContentChanged: _onContentChanged,
        onSave: _saveNote,
        onCancel: () {
          Navigator.of(context).pop(false);
        },
      ),
    );
  }
}