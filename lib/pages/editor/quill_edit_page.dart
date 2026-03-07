import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import '../../domain/category.dart';

class QuillEditorWidget extends StatefulWidget {
  final List<dynamic>? initialDelta;
  final void Function(String title, List<dynamic> content, int? categoryId)? onSave;
  final bool readOnly;
  final int? createdAt;
  final String? initialTitle;
  final int? initialCategoryId;
  final List<Category> categories;

  const QuillEditorWidget({
    super.key,
    this.initialDelta,
    this.onSave,
    this.readOnly = false,
    this.createdAt,
    this.initialTitle,
    this.initialCategoryId,
    this.categories = const [],
  });

  @override
  State<QuillEditorWidget> createState() => _QuillEditorWidgetState();
}

class _QuillEditorWidgetState extends State<QuillEditorWidget> {
  late final QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _fontSizeKey = GlobalKey();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();

    // 初始化标题
    if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty && widget.initialTitle != '无标题') {
      _titleController.text = widget.initialTitle!;
    }

    // 初始化分类
    _selectedCategoryId = widget.initialCategoryId;

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
      readOnly: widget.readOnly,
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
  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    
    if (dateDay == today) {
      return '今天 ${DateFormat('HH:mm').format(date)}';
    } else if (dateDay == today.subtract(const Duration(days: 1))) {
      return '昨天 ${DateFormat('HH:mm').format(date)}';
    } else if (date.year == now.year) {
      return DateFormat('MM-dd HH:mm').format(date);
    } else {
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    }
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
    final title = _titleController.text.trim().isEmpty ? '无标题' : _titleController.text.trim();

    widget.onSave?.call(title, content, _selectedCategoryId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存')));
  }

  final GlobalKey _categoryButtonKey = GlobalKey();

  // 构建分类选择器
  Widget _buildCategorySelector(bool isDark) {
    final selectedCategory = widget.categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => Category(name: '选择分类', colorValue: Colors.grey.value, createdAt: 0),
    );
    final isUnselected = _selectedCategoryId == null;

    return GestureDetector(
      key: _categoryButtonKey,
      onTap: widget.readOnly ? null : _showCategoryPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isUnselected
              ? (isDark ? Colors.white12 : Colors.grey.shade100)
              : selectedCategory.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isUnselected)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: selectedCategory.color,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              isUnselected ? '选择分类' : selectedCategory.name,
              style: TextStyle(
                fontSize: 13,
                color: isUnselected
                    ? (isDark ? Colors.white54 : Colors.black45)
                    : selectedCategory.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!widget.readOnly)
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: isUnselected
                    ? (isDark ? Colors.white54 : Colors.black45)
                    : selectedCategory.color,
              ),
          ],
        ),
      ),
    );
  }

  // 构建分类显示（只读模式）
  Widget _buildCategoryDisplay(bool isDark) {
    final category = _selectedCategoryId != null
        ? widget.categories.firstWhere(
            (c) => c.id == _selectedCategoryId,
            orElse: () => Category(name: '未分类', colorValue: Colors.grey.value, createdAt: 0),
          )
        : null;
    final displayName = category?.name ?? '未分类';
    final displayColor = category?.color ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: displayColor,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 13,
              color: displayColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 显示分类选择器
  void _showCategoryPicker() async {
    if (widget.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无分类，请先创建分类')),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 获取按钮位置
    final RenderBox? renderBox = _categoryButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset? offset = renderBox?.localToGlobal(Offset.zero);
    final Size? size = renderBox?.size;

    final result = await showMenu<int?>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset?.dx ?? 100,
        (offset?.dy ?? 100) + (size?.height ?? 0) + 4,
        (offset?.dx ?? 100) + (size?.width ?? 0),
        (offset?.dy ?? 100) + (size?.height ?? 0) + 200,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      items: [
        // 未分类选项
        PopupMenuItem<int?>(
          value: null,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '未分类',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: _selectedCategoryId == null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (_selectedCategoryId == null) ...[
                const Spacer(),
                Icon(Icons.check, color: Theme.of(context).primaryColor, size: 18),
              ],
            ],
          ),
        ),
        // 分类列表
        ...widget.categories.map((category) {
          final isSelected = category.id == _selectedCategoryId;
          return PopupMenuItem<int?>(
            value: category.id,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: category.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  category.name,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Icon(Icons.check, color: Theme.of(context).primaryColor, size: 18),
                ],
              ],
            ),
          );
        }),
      ],
    );

    // 只有用户选择了具体选项时才更新（result != null 表示选择了某个分类）
    // result == null 表示点击了菜单外部关闭，保持原选择不变
    if (result != null) {
      setState(() {
        _selectedCategoryId = result;
      });
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showMenu<double>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - 280,
        offset.dx + size.width,
        offset.dy,
      ),
      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: sizes.map((fontSize) {
        final isSelected = _controller.getSelectionStyle().attributes['size']?.value == fontSize;
        return PopupMenuItem<double>(
          value: fontSize,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 16, color: Colors.blue.withValues(alpha: 0.9))
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                '${fontSize.toInt()}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                'Aa',
                style: TextStyle(
                  fontSize: fontSize.clamp(10, 20),
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((selectedSize) {
      if (selectedSize != null) {
        final attr = selectedSize == 16.0 ? Attribute.size : Attribute.fromKeyValue('size', selectedSize);
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
    final colors = [
      Colors.black,
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.teal,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
      Colors.brown,
      Colors.grey,
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '选择颜色',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: colors.map((color) {
                    return GestureDetector(
                      onTap: () {
                        final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                        _controller.formatSelection(Attribute.fromKeyValue('color', hex));
                        Navigator.pop(dialogContext);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_syncSizeToToggledStyle);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = isDark ? Colors.white70 : Colors.black87;
    final toolbarColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final placeholderColor = isDark ? Colors.white38 : Colors.grey;

    return SafeArea(
      top: true,
      bottom: true,
      child: Container(
        color: bgColor,
        child: Column(
          children: [
            // 顶部栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: toolbarColor, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '返回',
                  ),
                  const Spacer(),
                  if (!widget.readOnly) ...[
                    IconButton(
                      icon: Icon(Icons.undo_outlined, color: toolbarColor, size: 20),
                      onPressed: () {
                        if (_controller.hasUndo) _controller.undo();
                      },
                      tooltip: '撤销',
                    ),
                    IconButton(
                      icon: Icon(Icons.redo_outlined, color: toolbarColor, size: 20),
                      onPressed: () {
                        if (_controller.hasRedo) _controller.redo();
                      },
                      tooltip: '重做',
                    ),
                    IconButton(
                      icon: Icon(Icons.check, color: toolbarColor, size: 22),
                      onPressed: _handleSave,
                      tooltip: '保存',
                    ),
                  ],
                ],
              ),
            ),
            // 标题和时间信息
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题输入框
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    readOnly: widget.readOnly,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: '标题',
                      hintStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 时间和分类
                  Row(
                    children: [
                      // 时间
                      Text(
                        widget.createdAt != null ? _formatDate(widget.createdAt!) : _formatDate(DateTime.now().millisecondsSinceEpoch),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      // 分隔符
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '|',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                        ),
                      ),
                      // 分类选择/显示
                      if (!widget.readOnly)
                        _buildCategorySelector(isDark)
                      else
                        _buildCategoryDisplay(isDark),
                    ],
                  ),
                ],
              ),
            ),

            // 编辑器
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
                      TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        letterSpacing: -0.4,
                        color: textColor,
                      ),
                      HorizontalSpacing.zero,
                      VerticalSpacing(20, 8),
                      VerticalSpacing.zero,
                      null,
                    ),
                    paragraph: DefaultTextBlockStyle(
                      TextStyle(
                        fontSize: 17,
                        height: 1.45,
                        letterSpacing: -0.2,
                        color: textColor,
                      ),
                      HorizontalSpacing.zero,
                      VerticalSpacing(0, 12),
                      VerticalSpacing.zero,
                      null,
                    ),
                    lists: DefaultListBlockStyle(
                      TextStyle(fontSize: 17, color: textColor),
                      HorizontalSpacing.zero,
                      VerticalSpacing(8, 8),
                      VerticalSpacing.zero,
                      null,
                      null,
                    ),
                    leading: DefaultListBlockStyle(
                      TextStyle(fontSize: 17, color: textColor),
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

            // 底部工具栏（只读模式下隐藏）
            if (!widget.readOnly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                      IconButton(
                        icon: Icon(Icons.format_bold_outlined, color: toolbarColor, size: 22),
                        tooltip: '加粗',
                        onPressed: () {
                          _controller.formatSelection(Attribute.bold);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.check_circle_outlined, color: toolbarColor, size: 22),
                        tooltip: '勾选列表',
                        onPressed: () {
                          _controller.formatSelection(
                            Attribute.fromKeyValue('list', 'checked'),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.format_list_bulleted_outlined, color: toolbarColor, size: 22),
                        tooltip: '无序列表',
                        onPressed: () {
                          _controller.formatSelection(
                            Attribute.fromKeyValue('list', 'bullet'),
                          );
                        },
                      ),
                      Builder(
                        builder: (btnContext) {
                          return IconButton(
                            icon: Icon(Icons.format_size_outlined, color: toolbarColor, size: 22),
                            tooltip: '字体大小',
                            onPressed: () {
                              final RenderBox? button =
                              btnContext.findRenderObject() as RenderBox?;
                              if (button == null) return;
                              final Offset offset =
                              button.localToGlobal(Offset.zero);
                              _showFontSizeMenu(
                                btnContext,
                                offset,
                                button.size,
                              );
                            },
                          );
                        },
                      ),
                      Builder(
                        builder: (btnContext) {
                          return IconButton(
                            icon: Icon(Icons.color_lens_outlined, color: toolbarColor, size: 22),
                            tooltip: '文字颜色',
                            onPressed: () {
                              final RenderBox? button =
                              btnContext.findRenderObject() as RenderBox?;
                              if (button == null) return;
                              final Offset offset =
                              button.localToGlobal(Offset.zero);
                              _showColorMenu(
                                btnContext,
                                offset,
                                button.size,
                              );
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.image_outlined, color: toolbarColor, size: 22),
                        tooltip: '插入图片',
                        onPressed: _insertImage,
                      ),
                    ],
                  ),
              ),
          ],
        ),
      ),
    );
  }
}
