import 'package:flutter/material.dart';
import 'package:project/pages/editor/quill_edit_page.dart';
import 'package:uuid/uuid.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import '../../domain/category.dart';
import '../../utils/page_routes.dart';
import '../../utils/image_path_resolver.dart';
import '../../widgets/custom_snackbar.dart';
import 'dart:convert';

class EditPage extends StatefulWidget {
  final Note? note;
  final bool readOnly;
  final String? heroTag;

  const EditPage({this.note, this.readOnly = false, this.heroTag, super.key});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await DB.instance.queryAllCategories();
    setState(() {
      _categories = categories;
    });
  }

  String getPlainText(List<dynamic> delta) {
    final buffer = StringBuffer();
    for (final op in delta) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        if (insert is String) {
          buffer.write(insert);
        }
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\n+$'), '');
  }

  Future<void> _save(String title, List<dynamic> content, int? categoryId) async {
    if (title.isEmpty && content.isEmpty) {
      CustomSnackBar.showWarning(
        context,
        message: '标题和内容不能都为空',
      );
      return;
    }
    final plainText = getPlainText(content);
    String? categoryUuid;
    if (categoryId != null) {
      final cat = await DB.instance.queryCategoryById(categoryId);
      categoryUuid = cat?.uuid;
    }

    if (widget.note == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await DB.instance.insert(
        Note(
          uuid: const Uuid().v4(),
          title: title,
          content: plainText,
          deltaContent: content,
          createdAt: now,
          updatedAt: now,
          categoryId: categoryId,
          categoryUuid: categoryUuid,
          syncStatus: 'pending_upload',
        ),
      );
    } else {
      await DB.instance.update(
        {
          'title': title,
          'content': plainText,
          'deltaContent': jsonEncode(content),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'categoryId': categoryId,
          'categoryUuid': categoryUuid,
          'syncStatus': 'pending_upload',
        },
        where: 'uuid = ?',
        whereArgs: [widget.note!.uuid],
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  /// 将 Delta 中的图片绝对路径转换为相对路径
  Future<List<dynamic>> _convertImagePathsToRelative(List<dynamic> content) async {
    final result = <dynamic>[];
    for (final op in content) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        if (insert is Map && insert.containsKey('image')) {
          final imagePath = insert['image'] as String;
          // 转换为相对路径
          final relativePath = await ImagePathResolver.toRelativePath(imagePath);
          result.add({
            'insert': {'image': relativePath}
          });
        } else {
          result.add(op);
        }
      } else {
        result.add(op);
      }
    }
    return result;
  }

  /// 将 Delta 中的图片相对路径转换为绝对路径（异步版本）
  Future<List<dynamic>> _convertImagePathsToAbsoluteAsync(List<dynamic> content) async {
    final result = <dynamic>[];
    for (final op in content) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        if (insert is Map && insert.containsKey('image')) {
          final imagePath = insert['image'] as String;
          // 如果是相对路径，转换为绝对路径
          if (ImagePathResolver.isRelativePath(imagePath)) {
            final absolutePath = await ImagePathResolver.toAbsolutePath(imagePath);
            result.add({
              'insert': {'image': absolutePath}
            });
          } else {
            result.add(op);
          }
        } else {
          result.add(op);
        }
      } else {
        result.add(op);
      }
    }
    return result;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Scaffold(
      body: QuillEditorWidget(
        initialDelta: widget.note?.deltaContent,
        readOnly: widget.readOnly,
        createdAt: widget.note?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        initialTitle: widget.note?.title,
        initialCategoryId: widget.note?.categoryId,
        categories: _categories,
        onSave: widget.readOnly ? null : (title, content, categoryId) {
          _save(title, content, categoryId);
        },
      ),
    );

    // 如果有 heroTag，包裹在 Hero 中
    if (widget.heroTag != null) {
      content = NoteHero(
        tag: widget.heroTag!,
        child: content,
      );
    }

    return content;
  }
}
