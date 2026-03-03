import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class QuillEditorWidget extends StatefulWidget {
  final List<dynamic>? initialDelta;
  final void Function(String title, List<dynamic> content)? onSave;

  const QuillEditorWidget({super.key, this.initialDelta, this.onSave});

  @override
  State<QuillEditorWidget> createState() => _QuillEditorWidgetState();
}

class _QuillEditorWidgetState extends State<QuillEditorWidget> {
  late final QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _fontSizeKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    Document document;
    if (widget.initialDelta != null && widget.initialDelta!.isNotEmpty) {
      document = Document.fromJson(widget.initialDelta!);
    } else {
      document = Document();
      // 插入一个空行，让光标从第一行开始更自然
      document.insert(0, '\n');
    }

    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: false,
      keepStyleOnNewLine: true,
    );

    // 监听光标/选区变化，将光标左侧字符的 size 同步到 toggledStyle
    // 确保中文 IME 上屏时新文字继承正确字号
    _controller.addListener(_syncSizeToToggledStyle);
  }

  String? _lastCursorSizeValue;

  void _syncSizeToToggledStyle() {
    final sel = _controller.selection;
    if (!sel.isCollapsed) return;

    final pos = sel.baseOffset;
    if (pos <= 0) return;

    try {
      final plain = _controller.document.toPlainText();

      int probe = pos - 1;

      // ⭐ 跳过所有换行符，找到真正有样式的字符
      while (probe > 0 && plain[probe] == '\n') {
        probe--;
      }

      if (probe < 0 || probe >= plain.length) return;

      final leftStyle = _controller.document.collectStyle(probe, 1);
      final sizeAttr = leftStyle.attributes['size'];
      final sizeValue = sizeAttr?.value?.toString();

      // 避免重复设置造成死循环
      if (sizeValue == _lastCursorSizeValue) return;
      _lastCursorSizeValue = sizeValue;

      _controller.removeListener(_syncSizeToToggledStyle);

      if (sizeAttr != null) {
        final attr = Attribute.fromKeyValue('size', sizeAttr.value);
        _controller.formatSelection(attr);
      } else {
        // 左侧没有 size，就不要乱清（保持当前状态）
        _controller.formatSelection(Attribute.clone(Attribute.size, null));
      }

      _controller.addListener(_syncSizeToToggledStyle);
    } catch (_) {}
  }
  String _extractTitleFromDelta(List<dynamic> delta) {
    if (delta.isEmpty) return '无标题';
    for (final op in delta) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        if (insert is String) {
          return insert.split('\n').first.trim().isEmpty
              ? '无标题'
              : insert.split('\n').first.trim();
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存')));
  }

  Future<void> _insertImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(pickedFile.path)}';
    final savedImage = File('${appDir.path}/images/$fileName');
    await savedImage.create(recursive: true);
    await File(pickedFile.path).copy(savedImage.path);

    final index = _controller.selection.baseOffset;
    final length = _controller.selection.extentOffset - index;
    _controller.replaceText(index, length, BlockEmbed.image(savedImage.path), null);
  }

  void _showFontSizeMenu(BuildContext context, Offset offset, Size size) {
    final sizes = [10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 36.0, 40.0, 48.0];

    showMenu<double>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - 280,
        offset.dx + size.width,
        offset.dy,
      ),
      items: sizes.map((size) {
        final isSelected = _controller.getSelectionStyle().attributes['size']?.value == size;
        return PopupMenuItem<double>(
          value: size,
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                child: isSelected
                  ? const Icon(Icons.check, size: 18, color: Colors.blue)
                  : null,
              ),
              const SizedBox(width: 8),
              Text(
                '${size.toInt()}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((size) {
      if (size != null) {
        final attr = size == 16.0 ? Attribute.size : Attribute.fromKeyValue('size', size);
        // 收缩选区，排除末尾换行符，避免 \n 携带 size attribute 污染下一行
        final sel = _controller.selection;
        final docText = _controller.document.toPlainText();
        int start = sel.start;
        int end = sel.end;
        while (end > start && end <= docText.length && docText[end - 1] == '\n') {
          end--;
        }
        if (end > start) {
          _controller.formatText(start, end - start, attr);
        } else if (sel.isCollapsed) {
          _controller.formatSelection(attr);
        }
      }
    });
  }

  void _showColorMenu(BuildContext context, Offset offset, Size size) {
    final colors = [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple];
    showMenu<Color>(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx - 120, offset.dy - 80, offset.dx + size.width, offset.dy),
      items: [
        PopupMenuItem<Color>(
          enabled: false,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.map((color) {
              return GestureDetector(
                onTap: () {
                  final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                  _controller.formatSelection(Attribute.fromKeyValue('color', hex));
                  Navigator.pop(context);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_syncSizeToToggledStyle);
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.amber),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '返回',
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.undo, color: Colors.amber),
                      onPressed: () {
                        if (_controller.hasUndo) {
                          _controller.undo();
                        }
                      },
                      tooltip: '撤销',
                    ),
                    IconButton(
                      icon: const Icon(Icons.redo, color: Colors.amber),
                      onPressed: () {
                        if (_controller.hasRedo) {
                          _controller.redo();
                        }
                      },
                      tooltip: '重做',
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.amber),
                      onPressed: _handleSave,
                      tooltip: '保存',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: QuillEditor.basic(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  config: QuillEditorConfig(
                    placeholder: '在此输入内容...',
                    expands: true,
                    scrollable: true,
                    padding: const EdgeInsets.fromLTRB(17, 12, 17, 100),
                    embedBuilders: [...FlutterQuillEmbeds.editorBuilders()],
                    customStyles: DefaultStyles(
                      h1: DefaultTextBlockStyle(
                        const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          letterSpacing: -0.4,
                          color: Colors.black87, // 确保可见
                        ),
                        HorizontalSpacing.zero,
                        // ← 修正：使用 HorizontalSpacing.zero
                        VerticalSpacing(20, 8), // top: 20, bottom: 8
                        VerticalSpacing.zero, // lineSpacing
                        null,
                      ),
                      paragraph: DefaultTextBlockStyle(
                        const TextStyle(
                          fontSize: 17,
                          height: 1.45,
                          letterSpacing: -0.2,
                          color: Colors.black87,
                        ),
                        HorizontalSpacing.zero,
                        VerticalSpacing(0, 12), // top: 0, bottom: 12
                        VerticalSpacing.zero,
                        null,
                      ),
                      lists: DefaultListBlockStyle(
                        const TextStyle(fontSize: 17, color: Colors.black87),
                        HorizontalSpacing.zero,
                        VerticalSpacing(8, 8),
                        VerticalSpacing.zero,
                        null,
                        null,
                      ),
                      leading: DefaultListBlockStyle(
                        const TextStyle(fontSize: 17, color: Colors.black87),
                        HorizontalSpacing.zero,
                        VerticalSpacing(8, 8),
                        VerticalSpacing.zero,
                        null,
                        null,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.format_bold),
                      tooltip: '加粗',
                      onPressed: () {
                        _controller.formatSelection(Attribute.bold);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_list_bulleted),
                      tooltip: '无序列表',
                      onPressed: () {
                        _controller.formatSelection(Attribute.fromKeyValue('list', 'bullet'));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_box),
                      tooltip: '勾选列表',
                      onPressed: () {
                        _controller.formatSelection(Attribute.fromKeyValue('list', 'checked'));
                      },
                    ),
                    Builder(
                      builder: (btnContext) {
                        return IconButton(
                          icon: const Icon(Icons.format_size),
                          tooltip: '字体大小',
                          onPressed: () {
                            final RenderBox? button = btnContext.findRenderObject() as RenderBox?;
                            if (button == null) return;
                            final Offset offset = button.localToGlobal(Offset.zero);
                            _showFontSizeMenu(btnContext, offset, button.size);
                          },
                        );
                      },
                    ),
                    Builder(
                      builder: (btnContext) {
                        return IconButton(
                          icon: const Icon(Icons.color_lens),
                          tooltip: '文字颜色',
                          onPressed: () {
                            final RenderBox? button = btnContext.findRenderObject() as RenderBox?;
                            if (button == null) return;
                            final Offset offset = button.localToGlobal(Offset.zero);
                            _showColorMenu(btnContext, offset, button.size);
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.image),
                      tooltip: '插入图片',
                      onPressed: _insertImage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
