import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class QuillEditorWidget extends StatefulWidget {
  /// Delta JSON（用于编辑/回显）
  final List<dynamic>? initialDelta;

  /// 是否只读
  final bool readOnly;

  /// 内容变化回调（Delta JSON）
  final ValueChanged<List<dynamic>>? onChanged;

  const QuillEditorWidget({
    super.key,
    this.initialDelta,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  State<QuillEditorWidget> createState() => _QuillEditorWidgetState();
}

class _QuillEditorWidgetState extends State<QuillEditorWidget> {
  late final QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    final document = widget.initialDelta != null
        ? Document.fromJson(widget.initialDelta!)
        : Document();

    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: widget.readOnly
    );

    _controller.addListener(_handleChange);
  }

  void _handleChange() {
    widget.onChanged?.call(
      _controller.document.toDelta().toJson(),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!widget.readOnly)
          QuillSimpleToolbar(
            controller: _controller,
            config: const QuillSimpleToolbarConfig(
              showSubscript:false,
              showSuperscript:false,
              showClearFormat:false,
              showBoldButton: true,
              showFontFamily: false,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: true,
              showHeaderStyle: true,
              showListBullets: true,
              showListNumbers: true,
              showQuote: true,
              showCodeBlock: true,
              showUndo: true,
              showRedo: true,
            ),
          ),
        Expanded(
          child: QuillEditor(
            controller: _controller,
            focusNode: _focusNode,
            scrollController: _scrollController,
            config: QuillEditorConfig(
              autoFocus: false,
              expands: false,
              padding: const EdgeInsets.all(12)
            ),
          ),
        ),
      ],
    );
  }
}
