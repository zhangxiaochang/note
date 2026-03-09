import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import '../../domain/category.dart';
import '../../utils/confirm_dialog.dart';
import '../../utils/page_routes.dart';
import 'dart:math' as math;

import 'note_card.dart';
import 'note_list_item.dart';

class HomePageBody extends StatefulWidget {
  final Future<List<Note>> future;
  final Future<void> Function() onRefresh;
  final bool isCardView;

  const HomePageBody({
    super.key,
    required this.future,
    required this.onRefresh,
    this.isCardView = true,
  });

  @override
  State<HomePageBody> createState() => _HomePageBodyState();
}

class _HomePageBodyState extends State<HomePageBody> {
  List<Category> _categories = [];
  Map<int, Category> _categoryMap = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void didUpdateWidget(HomePageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 future 变化时，重新加载分类
    if (oldWidget.future != widget.future) {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    final categories = await DB.instance.queryAllCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _categoryMap = {for (var c in categories) c.id!: c};
      });
    }
  }

  Category? _getCategoryForNote(Note note) {
    if (note.categoryId == null) return null;
    return _categoryMap[note.categoryId];
  }

  static Future<void> _deleteNote(BuildContext context, Note note) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '删除笔记',
      content: '确定要删除 "${note.title}" 吗？此操作不可恢复。',
      actionType: ConfirmActionType.delete,
    );

    if (confirmed == true) {
      try {
        await DB.instance.delete(note.id!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已删除笔记: ${note.title}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  static Future<void> _archiveNote(BuildContext context, Note note) async {
    try {
      await DB.instance.archiveNote(note.id!, true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已归档笔记: ${note.title}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('归档失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  static List<PopupMenuEntry<String>> _buildNoteMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      PopupMenuItem<String>(
        value: 'archive',
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.archive_outlined,
                size: 18,
                color: Colors.orange.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '归档',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'delete',
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '删除',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.red.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  void _handleMenuSelected(BuildContext context, String value, Note note, VoidCallback onRefresh) {
    switch (value) {
      case 'archive':
        _archiveNote(context, note).then((_) => onRefresh());
        break;
      case 'delete':
        _deleteNote(context, note).then((_) => onRefresh());
        break;
    }
  }

  /// 构建列表视图右滑显示的操作按钮
  List<Widget> _buildListActions(BuildContext context, Note note, VoidCallback onRefresh) {
    return [
      // 归档按钮
      GestureDetector(
        onTap: () => _archiveNote(context, note).then((_) => onRefresh()),
        child: Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.archive_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
      // 删除按钮
      GestureDetector(
        onTap: () => _deleteNote(context, note).then((_) => onRefresh()),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    ];
  }

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return math.max(1, width ~/ 170);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Note>>(
      future: widget.future,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('加载失败: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: widget.onRefresh, child: const Text('重试')),
              ],
            ),
          );
        }

        final notes = snapshot.data ?? [];
        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.note_add, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('暂无笔记', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  '点击右上角 + 按钮创建新笔记',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
              ],
            ),
          );
        }

        Widget content;
        if (widget.isCardView) {
          content = MasonryGridView.count(
            crossAxisCount: _crossAxisCount(context),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            itemCount: notes.length,
            itemBuilder: (_, index) {
              final note = notes[index];
              final cardKey = GlobalKey();
              return NoteCard(
                key: cardKey,
                note: note,
                category: _getCategoryForNote(note),
                onTap: () {
                  final RenderBox? renderBox = cardKey.currentContext?.findRenderObject() as RenderBox?;
                  Rect? cardRect;
                  if (renderBox != null) {
                    cardRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
                  }
                  Navigator.of(context)
                      .push<bool>(editPageRoute(note, cardRect: cardRect))
                      .then((edited) {
                        if (edited == true) {
                          widget.onRefresh();
                        }
                      });
                },
                onBuildMenu: _buildNoteMenu,
                onMenuSelected: (value) => _handleMenuSelected(context, value, note, widget.onRefresh),
                tintColor: Colors.blue,
              );
            },
          );
        } else {
          content = ListView.builder(
            itemCount: notes.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (_, index) {
              final note = notes[index];
              return NoteListItem(
                key: ValueKey('note_list_${note.id}'),
                note: note,
                category: _getCategoryForNote(note),
                onTap: () {
                  Navigator.of(context)
                      .push<bool>(editPageRoute(note))
                      .then((edited) {
                    if (edited == true) {
                      widget.onRefresh();
                    }
                  });
                },
                onBuildActions: (context) => _buildListActions(context, note, widget.onRefresh),
                onSwipeRight: () => _archiveNote(context, note).then((_) => widget.onRefresh()),
                tintColor: Colors.blue,
              );
            },
          );
        }

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          color: Theme.of(context).primaryColor,
          backgroundColor: Theme.of(context).cardColor,
          strokeWidth: 3,
          displacement: 60,
          edgeOffset: 10,
          triggerMode: RefreshIndicatorTriggerMode.onEdge,
          child: content,
        );
      },
    );
  }
}
