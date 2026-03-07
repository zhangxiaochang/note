import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import '../../domain/category.dart';
import '../../services/theme_provider.dart';
import '../../utils/confirm_dialog.dart';
import '../../utils/page_routes.dart';
import '../note/note_card.dart';
import '../note/note_list_item.dart';
import 'dart:math' as math;

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<Category> _categories = [];
  int _totalCount = 0;
  int _uncategorizedCount = 0;
  bool _isLoading = true;

  int? _selectedCategoryId;
  String _currentTitle = '全部归档';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final categories = await DB.instance.queryAllCategories();
    final archivedNotes = await DB.instance.queryArchived();
    final total = archivedNotes.length;
    final uncategorized = archivedNotes.where((n) => n.categoryId == null || n.categoryId == -1).length;

    // 获取每个分类的归档笔记数量
    for (final cat in categories) {
      cat.noteCount = archivedNotes.where((n) => n.categoryId == cat.id).length;
    }

    setState(() {
      _categories = categories;
      _totalCount = total;
      _uncategorizedCount = uncategorized;
      _isLoading = false;
    });
  }

  void _showCategoryMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏（归档页面没有新建按钮）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Center(
                  child: Text(
                    '选择分类',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              // 分类列表
              Flexible(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // 全部归档
                      _buildMenuCategoryItem(
                        context,
                        color: isDark ? Colors.white70 : Colors.black54,
                        name: '全部归档',
                        count: _totalCount,
                        onTap: () {
                          Navigator.pop(context);
                          _selectCategory(null, '全部归档');
                        },
                      ),
                      _buildMenuDivider(isDark),
                      // 未分类
                      _buildMenuCategoryItem(
                        context,
                        color: Colors.grey,
                        name: '未分类',
                        count: _uncategorizedCount,
                        onTap: () {
                          Navigator.pop(context);
                          _selectCategory(-1, '未分类归档');
                        },
                      ),
                      // 自定义分类
                      ..._categories.expand((category) {
                        return [
                          _buildMenuDivider(isDark),
                          _buildMenuCategoryItem(
                            context,
                            color: category.color,
                            name: category.name,
                            count: category.noteCount ?? 0,
                            onTap: () {
                              Navigator.pop(context);
                              _selectCategory(category.id, '${category.name}归档');
                            },
                          ),
                        ];
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuCategoryItem(
    BuildContext context, {
    required Color color,
    required String name,
    required int count,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 颜色条
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // 分类名称
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            // 笔记数量
            Text(
              '$count',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }

  void _selectCategory(int? categoryId, String title) {
    setState(() {
      _selectedCategoryId = categoryId;
      _currentTitle = title;
    });
  }

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  int _getCurrentCount() {
    if (_selectedCategoryId == null) return _totalCount;
    if (_selectedCategoryId == -1) return _uncategorizedCount;
    final category = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => Category(name: '', colorValue: Colors.grey.value, createdAt: DateTime.now().millisecondsSinceEpoch),
    );
    return category.noteCount ?? 0;
  }

  Future<List<Note>> _getFilteredNotes() async {
    final notes = await DB.instance.queryArchived();
    var filteredNotes = notes;
    
    // 按分类过滤
    if (_selectedCategoryId == null) {
      filteredNotes = notes;
    } else if (_selectedCategoryId == -1) {
      filteredNotes = notes.where((n) => n.categoryId == null || n.categoryId == -1).toList();
    } else {
      filteredNotes = notes.where((n) => n.categoryId == _selectedCategoryId).toList();
    }
    
    // 按搜索词过滤
    if (_searchQuery.isNotEmpty) {
      filteredNotes = filteredNotes.where((n) {
        final titleMatch = n.title.toLowerCase().contains(_searchQuery);
        final contentMatch = n.content.toLowerCase().contains(_searchQuery);
        return titleMatch || contentMatch;
      }).toList();
    }
    
    return filteredNotes;
  }

  Future<void> _unarchiveNote(BuildContext context, Note note) async {
    await DB.instance.archiveNote(note.id!, false);
    _loadData();
  }

  Future<void> _deleteNote(BuildContext context, Note note) async {
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

  List<PopupMenuEntry<String>> _buildNoteMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      PopupMenuItem<String>(
        value: 'unarchive',
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.unarchive_outlined,
                size: 18,
                color: Colors.blue.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '取消归档',
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
      case 'unarchive':
        _unarchiveNote(context, note);
        break;
      case 'delete':
        _deleteNote(context, note);
        break;
    }
  }

  /// 构建列表视图右滑显示的操作按钮
  List<Widget> _buildListActions(BuildContext context, Note note) {
    return [
      // 取消归档按钮
      GestureDetector(
        onTap: () => _unarchiveNote(context, note),
        child: Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.unarchive_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
      // 删除按钮
      GestureDetector(
        onTap: () => _deleteNote(context, note),
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
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _isSearching
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: '搜索归档笔记...',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              border: InputBorder.none,
                            ),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                          onPressed: _stopSearch,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _showCategoryMenu(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _currentTitle,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.search, color: isDark ? Colors.white : Colors.black),
                              onPressed: _startSearch,
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh, color: isDark ? Colors.white : Colors.black),
                              onPressed: _loadData,
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            // 笔记数量
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                '${_getCurrentCount()} 条归档笔记',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
            // 笔记列表
            Expanded(
              child: _buildNoteListView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteListView() {
    return FutureBuilder<List<Note>>(
      future: _getFilteredNotes(),
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
                  onPressed: _loadData,
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
                const Icon(Icons.archive_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('暂无归档笔记', style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        final themeProvider = context.watch<ThemeProvider>();
        final isCardView = themeProvider.isCardView;

        Widget content;
        if (isCardView) {
          content = MasonryGridView.count(
            crossAxisCount: _crossAxisCount(context),
            padding: const EdgeInsets.all(8.0),
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            itemCount: notes.length,
            itemBuilder: (_, index) {
              final note = notes[index];
              final category = _categories.firstWhere(
                (c) => c.id == note.categoryId,
                orElse: () => Category(name: '未分类', colorValue: Colors.grey.value, createdAt: 0),
              );
              final cardKey = GlobalKey();
              return NoteCard(
                key: cardKey,
                note: note,
                category: note.categoryId == null ? null : category,
                onTap: () {
                  final RenderBox? renderBox = cardKey.currentContext?.findRenderObject() as RenderBox?;
                  Rect? cardRect;
                  if (renderBox != null) {
                    cardRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
                  }
                  // 归档笔记以只读模式打开，且不能修改分类
                  Navigator.of(context).push(
                    editPageRoute(note, cardRect: cardRect, readOnly: true),
                  ).then((_) => _loadData());
                },
                onBuildMenu: _buildNoteMenu,
                onMenuSelected: (value) => _handleMenuSelected(context, value, note),
                tintColor: Colors.orange,
              );
            },
          );
        } else {
          content = ListView.builder(
            itemCount: notes.length,
            padding: const EdgeInsets.all(8.0),
            itemBuilder: (_, index) {
              final note = notes[index];
              final category = _categories.firstWhere(
                (c) => c.id == note.categoryId,
                orElse: () => Category(name: '未分类', colorValue: Colors.grey.value, createdAt: 0),
              );
              return NoteListItem(
                key: ValueKey('archive_list_${note.id}'),
                note: note,
                category: note.categoryId == null ? null : category,
                onTap: () {
                  // 归档笔记以只读模式打开，且不能修改分类
                  Navigator.of(context).push(
                    editPageRoute(note, readOnly: true),
                  ).then((_) => _loadData());
                },
                onBuildActions: (context) => _buildListActions(context, note),
                onSwipeRight: () => _unarchiveNote(context, note),
                tintColor: Colors.orange,
              );
            },
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: content,
        );
      },
    );
  }
}

// 扩展Category类添加noteCount字段
extension CategoryExtension on Category {
  static final _noteCounts = <int, int>{};

  int? get noteCount => _noteCounts[id];
  set noteCount(int? value) {
    if (id != null && value != null) {
      _noteCounts[id!] = value;
    }
  }
}
