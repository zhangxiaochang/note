import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import '../../domain/category.dart';
import '../../utils/page_routes.dart';
import 'note_card.dart';
import 'dart:math' as math;

class NoteListPage extends StatefulWidget {
  final int? categoryId; // null: 全部, -1: 未分类, 其他: 具体分类
  final String title;
  final bool showSearch;

  const NoteListPage({
    super.key,
    this.categoryId,
    required this.title,
    this.showSearch = false,
  });

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  late Future<List<Note>> _future;
  List<Category> _categories = [];
  Map<int, Category> _categoryMap = {};
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _reload();
    if (widget.showSearch) {
      _isSearching = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await DB.instance.queryAllCategories();
    setState(() {
      _categories = categories;
      _categoryMap = {for (var c in categories) c.id!: c};
    });
  }

  Category? _getCategoryForNote(Note note) {
    if (note.categoryId == null) return null;
    return _categoryMap[note.categoryId];
  }

  void _reload() {
    setState(() {
      if (_isSearching && _searchQuery.isNotEmpty) {
        _future = DB.instance.queryActive().then((notes) {
          var filtered = notes;
          if (widget.categoryId != null) {
            if (widget.categoryId == -1) {
              filtered = notes.where((n) => n.categoryId == null || n.categoryId == -1).toList();
            } else {
              filtered = notes.where((n) => n.categoryId == widget.categoryId).toList();
            }
          }
          return filtered.where((note) {
            return note.title.toLowerCase().contains(_searchQuery) ||
                note.content.toLowerCase().contains(_searchQuery);
          }).toList();
        });
      } else {
        _future = DB.instance.queryActive().then((notes) {
          if (widget.categoryId == null) {
            return notes;
          } else if (widget.categoryId == -1) {
            return notes.where((n) => n.categoryId == null || n.categoryId == -1).toList();
          } else {
            return notes.where((n) => n.categoryId == widget.categoryId).toList();
          }
        });
      }
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
      _reload();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _reload();
    });
  }

  Future<void> _handleRefresh() async {
    await _loadCategories();
    _reload();
    await _future;
  }

  Future<void> _deleteNote(BuildContext context, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定要删除 "${note.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DB.instance.delete(note.id!);
      _reload();
    }
  }

  Future<void> _archiveNote(BuildContext context, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档笔记'),
        content: Text('确定要归档 "${note.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DB.instance.archiveNote(note.id!, true);
      _reload();
    }
  }

  List<PopupMenuEntry<String>> _buildNoteMenu(BuildContext context) {
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

  void _handleMenuSelected(BuildContext context, String value, Note note) {
    switch (value) {
      case 'archive':
        _archiveNote(context, note);
        break;
      case 'delete':
        _deleteNote(context, note);
        break;
    }
  }

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return math.max(1, width ~/ 170);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索笔记...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                onChanged: _onSearchChanged,
              )
            : Text(
                widget.title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: Icon(Icons.close, color: iconColor),
              onPressed: _stopSearch,
              tooltip: '关闭搜索',
            )
          else
            IconButton(
              icon: Icon(Icons.search, color: iconColor),
              onPressed: _startSearch,
              tooltip: '搜索',
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: iconColor),
            onPressed: _handleRefresh,
            tooltip: '刷新',
          ),
        ],
      ),
      body: FutureBuilder<List<Note>>(
        future: _future,
        builder: (context, snapshot) {
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
                  ElevatedButton(
                    onPressed: _reload,
                    child: const Text('重试'),
                  ),
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
                  Icon(
                    widget.showSearch ? Icons.search_off : Icons.note_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.showSearch ? '没有找到相关笔记' : '暂无笔记',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: MasonryGridView.count(
              crossAxisCount: _crossAxisCount(context),
              padding: const EdgeInsets.all(8.0),
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
                        .then((_) => _reload());
                  },
                  onBuildMenu: _buildNoteMenu,
                  onMenuSelected: (value) => _handleMenuSelected(context, value, note),
                  tintColor: Colors.blue,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(editPageRoute(null, heroTag: 'note_card_new'));
          _reload();
        },
        tooltip: '新建笔记',
        child: const Icon(Icons.add),
        shape: const CircleBorder(),
        backgroundColor: isDark ? Colors.lightBlueAccent : Colors.blue,
      ),
    );
  }
}
