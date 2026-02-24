import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

class QuillEditorWidget extends StatefulWidget {
  final List<dynamic>? initialDelta;
  final void Function(String title, List<dynamic> content)? onSave;

  const QuillEditorWidget({
    super.key,
    this.initialDelta,
    this.onSave,
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

    Document document;
    if (widget.initialDelta != null) {
      document = Document.fromJson(widget.initialDelta!);
    } else {
      final delta = Delta()
        ..insert('在此输入标题', {'header': 1})
        ..insert('\n');
      document = Document()..compose(delta,ChangeSource.local);
    }

    _controller = QuillController(
      document: document,
      selection: TextSelection.collapsed(offset: document.length),
      readOnly: false,
      keepStyleOnNewLine: false,
    );
  }

  String _extractTitleFromDelta(List<dynamic> delta) {
    if (delta.isEmpty) return '无标题';
    for (final op in delta) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        if (insert is String) {
          return insert.split('\n').first.trim().isEmpty ? '无标题' : insert.split('\n').first.trim();
        }
      }
      break;
    }
    return '无标题';
  }

  void _handleSave() {
    final content = _controller.document.toDelta().toJson();
    final title = _extractTitleFromDelta(content);

    widget.onSave?.call(title, content);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: true,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: QuillSimpleToolbar(
                  controller: _controller,
                  config: const QuillSimpleToolbarConfig(
                    multiRowsDisplay: true,
                    showFontFamily: false,
                    showFontSize: false,
                    showHeaderStyle: true,
                    showColorButton: true,
                    showBoldButton: true,
                    showListNumbers: true,
                    showUndo: false,
                    showRedo: false,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: QuillEditor(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  config: QuillEditorConfig(
                    expands: true,
                    scrollable: false,
                    padding: const EdgeInsets.all(16),
                    customStyles: DefaultStyles(
                      h1: DefaultTextBlockStyle(
                        const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                        HorizontalSpacing(0, 0),
                        VerticalSpacing(16, 16),
                        VerticalSpacing.zero,
                        BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          // border: Border.all(color: Colors.grey),
                        ),
                      ),
                      paragraph: DefaultTextBlockStyle(
                        const TextStyle(fontSize: 16),
                        HorizontalSpacing(0, 0),
                        VerticalSpacing(8, 8),
                        VerticalSpacing.zero,
                        BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          // border: Border.all(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _handleSave,
              tooltip: '保存',
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.save, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}