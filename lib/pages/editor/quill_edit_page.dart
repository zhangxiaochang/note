import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class QuillEditorWidget extends StatefulWidget {
  final String? initialTitle; // ✅ 新增：初始标题
  final List<dynamic>? initialDelta;
  final void Function(String title, List<dynamic> content)? onSave;

  const QuillEditorWidget({
    super.key,
    this.initialTitle,
    this.initialDelta,
    this.onSave,
  });

  @override
  State<QuillEditorWidget> createState() => _QuillEditorWidgetState();
}

class _QuillEditorWidgetState extends State<QuillEditorWidget> {
  late final QuillController _controller;
  late final TextEditingController _titleController;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // 初始化标题
    _titleController = TextEditingController(
      text: widget.initialTitle ?? '请填写标题',
    );

    // 初始化正文
    final document = widget.initialDelta != null
        ? Document.fromJson(widget.initialDelta!)
        : Document();

    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: false,
      keepStyleOnNewLine:false
    );
  }

  void _handleSave() {
    final title = _titleController.text;
    final content = _controller.document.toDelta().toJson();

    // 推荐：通过 onSave 回调让父组件统一处理保存
    widget.onSave?.call(title, content);

    // 或者直接在这里处理（二选一）
    // saveData(title, content);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存')));
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea( // 👈 关键：包裹整个 UI
      top: true,     // 确保顶部避开刘海/状态栏
      bottom: true,  // 确保底部避开手势导航栏（可选，但推荐）
      left: false,   // 左右一般不需要（除非特殊设计）
      right: false,
      child: Stack(
        children: [
          Column(
            children: [
              // ✅ 可编辑标题
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: '请输入标题',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                ),
              ),

              const Divider(height: 1),

              // Quill 工具栏
              QuillSimpleToolbar(
                controller: _controller,
                config: const QuillSimpleToolbarConfig(
                  multiRowsDisplay: true,
                  showFontFamily: false,
                  showFontSize: true,
                  showHeaderStyle: false,
                  showColorButton: true,
                  showBackgroundColorButton: false,
                  showStrikeThrough: false,
                  showInlineCode: false,
                  showQuote: false,
                  showCodeBlock: false,
                  showIndent: false,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                  showLineHeightButton: false,
                  showClearFormat: false,
                  showLink: false,
                  // 核心功能保留
                  showBoldButton: true,
                  showItalicButton: false,
                  showUnderLineButton: false,
                  showListBullets: false,
                  showListNumbers: true,
                  showUndo: false,
                  showRedo: false,
                ),
              ),

              const Divider(height: 1),

              // 编辑区域
              Expanded(
                child: QuillEditor(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  config: QuillEditorConfig(
                    autoFocus: false,
                    expands: false,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),

          // ✅ 右下角保存按钮（SafeArea 会自动为其留出底部空间）
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _handleSave,
              tooltip: '保存',
              child: const Icon(Icons.save),
            ),
          ),
        ],
      ),
    );
  }
}
