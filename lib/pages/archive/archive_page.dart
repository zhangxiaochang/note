import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import '../../domain/category.dart';
import '../../services/theme_provider.dart';
import '../../utils/confirm_dialog.dart';
import '../../utils/page_routes.dart';
import '../../widgets/list_loading_animation.dart';
import '../note/note_card.dart';
import '../note/note_list_item.dart';
import 'dart:math' as math;

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> with SingleTickerProviderStateMixin {
  List<Category> _categories = [];
  int _totalCount = 0;
  int _uncategorizedCount = 0;
  bool _isLoading = true;

  int? _selectedCategoryId;
  String _currentTitle = '全部归档';

  // 缓存笔记列表，避免每次搜索都查询数据库
  List<Note> _cachedNotes = [];

  // 刷新动画控制器
  late AnimationController _refreshController;

  // 用于跟踪是否需要播放动画
  bool _shouldAnimate = true;
  List<Note> _lastNotes = [];
  int _lastRefreshCount = 0;

  // 刷新计数器，用于触发动画
  int _refreshCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
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
      _cachedNotes = archivedNotes;
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
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // 分类列表
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // 全部归档
                    ListTile(
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        '全部归档',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      trailing: _selectedCategoryId == null
                          ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = null;
                          _currentTitle = '全部归档';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    // 未分类
                    ListTile(
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        '未分类',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      trailing: _selectedCategoryId == -1
                          ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = -1;
                          _currentTitle = '未分类归档';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    // 分隔线
                    const Divider(height: 1),
                    // 各分类
                    ..._categories.map((category) {
                      return ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: category.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          category.name,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        trailing: _selectedCategoryId == category.id
                            ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedCategoryId = category.id;
                            _currentTitle = '${category.name}归档';
                          });
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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

  List<Note> _getFilteredNotes() {
    // 使用缓存的笔记列表，避免每次查询数据库
    var filteredNotes = _cachedNotes;

    // 按分类过滤
    if (_selectedCategoryId == null) {
      filteredNotes = _cachedNotes;
    } else if (_selectedCategoryId == -1) {
      filteredNotes = _cachedNotes.where((n) => n.categoryId == null || n.categoryId == -1).toList();
    } else {
      filteredNotes = _cachedNotes.where((n) => n.categoryId == _selectedCategoryId).toList();
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
        _loadData();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _restoreNote(BuildContext context, Note note) async {
    try {
      await DB.instance.archiveNote(note.id!, false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已恢复笔记: ${note.title}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢复失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Widget> _buildListActions(BuildContext context, Note note) {
    return [
      // 恢复按钮
      GestureDetector(
        onTap: () => _restoreNote(context, note),
        child: Container(
          width: 80,
          height: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.unarchive,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                '恢复',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
      // 删除按钮
      GestureDetector(
        onTap: () => _deleteNote(context, note),
        child: Container(
          width: 80,
          height: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                '删除',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return math.max(1, width ~/ 170);
  }

  List<PopupMenuItem<String>> _buildNoteMenu(BuildContext context, Note note) {
    return [
      const PopupMenuItem<String>(
        value: 'restore',
        child: Row(
          children: [
            Icon(Icons.unarchive, size: 20),
            SizedBox(width: 8),
            Text('恢复'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 20, color: Colors.red),
            SizedBox(width: 8),
            Text('删除', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  void _handleMenuSelected(BuildContext context, String value, Note note) {
    switch (value) {
      case 'restore':
        _restoreNote(context, note);
        break;
      case 'delete':
        _deleteNote(context, note);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? ThemeProvider.darkBackgroundColor : ThemeProvider.lightBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部标题栏（添加状态栏高度）
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 8),
            child: _isSearching
                ? Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? ThemeProvider.darkCardColor
                                : ThemeProvider.lightCardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                hintText: '搜索归档笔记...',
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  height: 1.0,
                                  color: isDark
                                      ? ThemeProvider.darkSecondaryTextColor
                                      : ThemeProvider.lightSecondaryTextColor,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                prefixIcon: Container(
                                  width: 40,
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.search,
                                    size: 18,
                                    color: isDark
                                        ? ThemeProvider.darkSecondaryTextColor
                                        : ThemeProvider.lightSecondaryTextColor,
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 44,
                                  maxWidth: 40,
                                  maxHeight: 44,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          size: 18,
                                          color: isDark
                                              ? ThemeProvider.darkSecondaryTextColor
                                              : ThemeProvider.lightSecondaryTextColor,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          _onSearchChanged('');
                                        },
                                      )
                                    : null,
                              ),
                              style: TextStyle(
                                color: isDark
                                    ? ThemeProvider.darkTextColor
                                    : ThemeProvider.lightTextColor,
                                fontSize: 15,
                                height: 1.0,
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _stopSearch,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? ThemeProvider.darkCardColor
                                  : ThemeProvider.lightCardColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: isDark
                                  ? ThemeProvider.darkTextColor
                                  : ThemeProvider.lightTextColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 标题和下拉
                      GestureDetector(
                        onTap: () => _showCategoryMenu(context),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentTitle,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? ThemeProvider.darkTextColor
                                      : ThemeProvider.lightTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                                color: isDark
                                    ? ThemeProvider.darkSecondaryTextColor
                                    : ThemeProvider.lightSecondaryTextColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 右侧按钮组
                      Row(
                        children: [
                          // 搜索按钮
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _startSearch,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? ThemeProvider.darkCardColor
                                      : ThemeProvider.lightCardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.search,
                                  size: 18,
                                  color: isDark
                                      ? ThemeProvider.darkTextColor
                                      : ThemeProvider.lightTextColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // 刷新按钮
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _refreshController.forward(from: 0);
                                setState(() => _refreshCount++);
                                _loadData();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? ThemeProvider.darkCardColor
                                      : ThemeProvider.lightCardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: RotationTransition(
                                  turns: _refreshController,
                                  child: Icon(
                                    Icons.refresh,
                                    size: 18,
                                    color: isDark
                                        ? ThemeProvider.darkTextColor
                                        : ThemeProvider.lightTextColor,
                                  ),
                                ),
                              ),
                            ),
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
              '$_totalCount 条归档',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? ThemeProvider.darkSecondaryTextColor
                    : ThemeProvider.lightSecondaryTextColor,
              ),
            ),
          ),
          // 笔记列表
          Expanded(
            child: _buildNoteListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteListView() {
    final themeProvider = context.watch<ThemeProvider>();
    final notes = _getFilteredNotes();

    // 检查笔记是否发生变化，决定是否需要播放动画
    _shouldAnimate = _haveNotesChanged(notes);
    _lastNotes = List.from(notes);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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

    final isCardView = themeProvider.isCardView;

    Widget content;
    if (isCardView) {
      content = MasonryGridView.count(
        crossAxisCount: _crossAxisCount(context),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          return AnimatedListWrapper(
            key: ValueKey('card_${note.id}_$_refreshCount'),
            index: index,
            config: ListAnimationConfig(
              type: ListAnimationType.scale,
              duration: Duration(milliseconds: 400),
              delay: Duration(milliseconds: 80),
            ),
            child: NoteCard(
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
              onBuildMenu: (ctx) => _buildNoteMenu(ctx, note),
              onMenuSelected: (value) => _handleMenuSelected(context, value, note),
              tintColor: Colors.orange,
            ),
          );
        },
      );
    } else {
      // 列表视图 - Windows宽屏时自动分列
      final screenWidth = MediaQuery.of(context).size.width;
      final isWideScreen = screenWidth > 900; // 宽屏阈值
      final crossAxisCount = isWideScreen ? (screenWidth ~/ 450).clamp(2, 4) : 1;

      if (crossAxisCount > 1) {
        // 宽屏多列布局
        content = MasonryGridView.count(
          crossAxisCount: crossAxisCount,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          mainAxisSpacing: 2,
          crossAxisSpacing: 16,
          itemCount: notes.length,
          itemBuilder: (_, index) {
            final note = notes[index];
            final category = _categories.firstWhere(
              (c) => c.id == note.categoryId,
              orElse: () => Category(name: '未分类', colorValue: Colors.grey.value, createdAt: 0),
            );
            return AnimatedListWrapper(
              key: ValueKey('grid_list_${note.id}_$_refreshCount'),
              index: index,
              config: ListAnimationConfig(
                type: ListAnimationType.scale,
                duration: Duration(milliseconds: 400),
                delay: Duration(milliseconds: 80),
              ),
              child: NoteListItem(
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
              ),
            );
          },
        );
      } else {
        // 单列布局（移动端/窄屏）
        content = ListView.builder(
          itemCount: notes.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemBuilder: (_, index) {
            final note = notes[index];
            final category = _categories.firstWhere(
              (c) => c.id == note.categoryId,
              orElse: () => Category(name: '未分类', colorValue: Colors.grey.value, createdAt: 0),
            );
            return AnimatedListWrapper(
              key: ValueKey('list_${note.id}_$_refreshCount'),
              index: index,
              config: ListAnimationConfig(
                type: ListAnimationType.slideUp,
                duration: Duration(milliseconds: 400),
                delay: Duration(milliseconds: 80),
              ),
              child: NoteListItem(
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
              ),
            );
          },
        );
      }
    }

    return AnimationLimiter(
      animate: _shouldAnimate,
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        strokeWidth: 3,
        displacement: 60,
        edgeOffset: 10,
        triggerMode: RefreshIndicatorTriggerMode.onEdge,
        child: content,
      ),
    );
  }

  /// 检查笔记列表是否真正发生变化
  bool _haveNotesChanged(List<Note> currentNotes) {
    // 如果 refreshCount 变化，播放动画
    if (_lastRefreshCount != _refreshCount) {
      _lastRefreshCount = _refreshCount;
      return true;
    }
    // 如果笔记列表发生变化，播放动画
    if (_lastNotes.length != currentNotes.length) return true;
    for (int i = 0; i < currentNotes.length; i++) {
      if (_lastNotes[i].id != currentNotes[i].id) return true;
    }
    return false;
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
