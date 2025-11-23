// lib/pages/markdown_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownEditor extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String>? onContentChanged;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;

  const MarkdownEditor({
    super.key,
    this.initialContent = '',
    this.onContentChanged,
    this.onSave,
    this.onCancel,
  });

  @override
  State<MarkdownEditor> createState() => MarkdownEditorState();
}

class MarkdownEditorState extends State<MarkdownEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _focusNode = FocusNode();
    _controller.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    widget.onContentChanged?.call(_controller.text);
  }

  @override
  void didUpdateWidget(covariant MarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialContent != widget.initialContent) {
      _controller.text = widget.initialContent;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onContentChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _wrapSelection(String prefix, String suffix, {String placeholder = '文本'}) {
    final textEditingValue = _controller.value;
    final selection = textEditingValue.selection;
    final selectedText = selection.textInside(_controller.text);

    String newText;
    TextSelection newSelection;

    if (selection.isCollapsed) {
      newText = '$prefix$placeholder$suffix';
      newSelection = TextSelection(
        baseOffset: selection.baseOffset + prefix.length,
        extentOffset: selection.baseOffset + prefix.length + placeholder.length,
      );
    } else {
      newText = '$prefix$selectedText$suffix';
      newSelection = TextSelection.collapsed(
        offset: selection.baseOffset + prefix.length + selectedText.length + suffix.length,
      );
    }

    _controller.value = TextEditingValue(
      text: _controller.text.replaceRange(selection.start, selection.end, newText),
      selection: newSelection,
    );

    _focusNode.requestFocus();
  }

  void _insertInlineFormat(String symbol, {String placeholder = '文本'}) {
    _wrapSelection(symbol, symbol, placeholder: placeholder);
  }

  void _insertBlockFormat(String prefix, {String placeholder = '内容'}) {
    final textEditingValue = _controller.value;
    final selection = textEditingValue.selection;
    final currentText = _controller.text;

    int lineStart = selection.start;
    while (lineStart > 0 && currentText[lineStart - 1] != '\n') {
      lineStart--;
    }

    final newText = currentText.replaceRange(lineStart, lineStart, '$prefix ');
    final newSelection = TextSelection.collapsed(
      offset: selection.start + prefix.length + 1,
    );

    _controller.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );

    _focusNode.requestFocus();
  }

  String get currentContent => _controller.text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: _isEditing ? _buildEditor() : _buildPreview(),
        ),
        if (widget.onSave != null || widget.onCancel != null) _buildActionButtons(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 50,
      color: Colors.grey[100],
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.visibility : Icons.edit,
              color: Colors.blue,
            ),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
            tooltip: _isEditing ? '切换到预览' : '切换到编辑',
          ),
          const VerticalDivider(width: 1),
          if (_isEditing)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ToolbarButton(
                      icon: Icons.format_bold,
                      tooltip: '粗体',
                      onPressed: () => _insertInlineFormat('**', placeholder: '粗体文本'),
                    ),
                    _ToolbarButton(
                      icon: Icons.format_italic,
                      tooltip: '斜体',
                      onPressed: () => _insertInlineFormat('*', placeholder: '斜体文本'),
                    ),
                    _ToolbarButton(
                      icon: Icons.strikethrough_s,
                      tooltip: '删除线',
                      onPressed: () => _insertInlineFormat('~~', placeholder: '删除文本'),
                    ),
                    _ToolbarButton(
                      icon: Icons.code,
                      tooltip: '行内代码',
                      onPressed: () => _insertInlineFormat('`', placeholder: '代码'),
                    ),
                    _ToolbarButton(
                      icon: Icons.link,
                      tooltip: '链接',
                      onPressed: () => _wrapSelection('[', '](https://example.com)', placeholder: '链接文本'),
                    ),
                    _ToolbarButton(
                      icon: Icons.image,
                      tooltip: '图片',
                      onPressed: () => _wrapSelection('![', '](https://example.com/image.jpg)', placeholder: '图片描述'),
                    ),
                    _ToolbarButton(
                      icon: Icons.format_list_bulleted,
                      tooltip: '无序列表',
                      onPressed: () => _insertBlockFormat('-', placeholder: '列表项'),
                    ),
                    _ToolbarButton(
                      icon: Icons.format_list_numbered,
                      tooltip: '有序列表',
                      onPressed: () => _insertBlockFormat('1.', placeholder: '列表项'),
                    ),
                    _ToolbarButton(
                      icon: Icons.format_quote,
                      tooltip: '引用',
                      onPressed: () => _insertBlockFormat('>', placeholder: '引用文本'),
                    ),
                    _ToolbarButton(
                      icon: Icons.title,
                      tooltip: '标题',
                      onPressed: () => _insertBlockFormat('#', placeholder: '标题'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      height: 300, // 或者随你需要的高度
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: const TextStyle(
          fontSize: 16,
          height: 1.6,
          fontFamily: 'Menlo',
        ),
        decoration: const InputDecoration(
          hintText: '开始编写 Markdown...',
          hintStyle: TextStyle(color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          // 移除 isDense 和 isCollapsed
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Markdown(
        data: currentContent.isEmpty ? '*暂无内容*' : currentContent,
        styleSheet: MarkdownStyleSheet(
          h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          p: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
          blockquote: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey.shade700, backgroundColor: Colors.grey.shade100),
          code: TextStyle(backgroundColor: Colors.grey.shade100, fontFamily: 'Monospace', fontSize: 14),
        ),
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.onCancel != null)
            OutlinedButton(
              onPressed: widget.onCancel,
              child: const Text('取消'),
            ),
          const SizedBox(width: 12),
          if (widget.onSave != null)
            FilledButton(
              onPressed: widget.onSave,
              child: const Text('保存'),
            ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}