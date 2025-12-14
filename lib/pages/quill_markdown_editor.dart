import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

class QuillMarkdownEditor extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String>? onContentChanged;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;

  const QuillMarkdownEditor({
    super.key,
    this.initialContent = '',
    this.onContentChanged,
    this.onSave,
    this.onCancel,
  });

  @override
  State<QuillMarkdownEditor> createState() => QuillMarkdownEditorState();
}

class QuillMarkdownEditorState extends State<QuillMarkdownEditor> {
  late final QuillController _controller;
  late final FocusNode _focusNode;
  bool _isEditing = true;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = QuillController.basic();

    // 关键：正确创建 markdown Document 并传入
    final markdownDoc = md.Document(encodeHtml: false);
    if (widget.initialContent.isNotEmpty) {
      final delta = MarkdownToDelta(markdownDocument: markdownDoc)
          .convert(widget.initialContent);
      _controller.document = Document.fromDelta(delta);
    }

    _controller.addListener(() {
      final markdown = DeltaToMarkdown().convert(_controller.document.toDelta());
      widget.onContentChanged?.call(markdown);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get currentContent =>
      DeltaToMarkdown().convert(_controller.document.toDelta());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 切换按钮
        Container(
          height: 50,
          color: Colors.grey[100],
          child: Row(
            children: [
              IconButton(
                icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
                onPressed: () => setState(() => _isEditing = !_isEditing),
                tooltip: _isEditing ? '预览' : '编辑',
              ),
              const VerticalDivider(),
            ],
          ),
        ),

        // 编辑区 / 预览区
        Expanded(
          child: _isEditing ? _buildEditor() : _buildPreview(),
        ),

        // 保存取消按钮
        if (widget.onSave != null || widget.onCancel != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onCancel != null)
                  OutlinedButton(onPressed: widget.onCancel, child: const Text('取消')),
                const SizedBox(width: 12),
                if (widget.onSave != null)
                  FilledButton(onPressed: widget.onSave, child: const Text('保存')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        // 工具栏
        Container(
          height: 50,
          color: Colors.grey[100],
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.format_bold),         onPressed: () => _controller.formatSelection(Attribute.bold)),
                IconButton(icon: const Icon(Icons.format_italic),       onPressed: () => _controller.formatSelection(Attribute.italic)),
                IconButton(icon: const Icon(Icons.strikethrough_s),     onPressed: () => _controller.formatSelection(Attribute.strikeThrough)),
                IconButton(icon: const Icon(Icons.format_list_bulleted),onPressed: () => _controller.formatSelection(Attribute.ul)),
                IconButton(icon: const Icon(Icons.format_list_numbered),onPressed: () => _controller.formatSelection(Attribute.ol)),
                IconButton(icon: const Icon(Icons.title),              onPressed: () => _controller.formatSelection(Attribute.h1)),
                IconButton(icon: const Icon(Icons.format_quote),       onPressed: () => _controller.formatSelection(Attribute.blockQuote)),
                IconButton(icon: const Icon(Icons.code),                onPressed: () => _controller.formatSelection(Attribute.codeBlock)),
              ],
            ),
          ),
        ),

        // Quill 编辑器（最新版 QuillEditor 用 configurations 而不是 padding）
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
            child: QuillEditor(
              controller: _controller,
              focusNode: _focusNode,
              scrollController: ScrollController(),
              config: const QuillEditorConfig(
                padding: EdgeInsets.all(16),   // ← 改成这里
                expands: true,
                autoFocus: false,
                scrollable: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
      padding: const EdgeInsets.all(16),
      child: Markdown(
        data: currentContent.isEmpty ? '*暂无内容*' : currentContent,
        shrinkWrap: true,
      ),
    );
  }
}