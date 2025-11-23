import 'package:flutter/material.dart';

class MarkdownEditorNow extends StatefulWidget {
  final TextEditingController controller;

  const MarkdownEditorNow({
    super.key,
    required this.controller,
  });

  @override
  State<MarkdownEditorNow> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditorNow> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // 外壳
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),

      // 用 Column + Expanded 控制高度，避免 expands:true
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,

              // 让输入自然换行
              maxLines: null,

              // ---- macOS 输入法稳定配置核心 ----
              enableSuggestions: false,
              autocorrect: false,

              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,

              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                fontFamily: 'Menlo',
              ),

              decoration: const InputDecoration(
                hintText: '开始编写 Markdown…',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          )
        ],
      ),
    );
  }
}
