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
  
  // 分类按钮的 GlobalKey，用于定位下拉菜单
  final GlobalKey _categoryButtonKey = GlobalKey();

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
    
    // 从 GlobalKey 获取按钮位置
    final RenderBox? button = _categoryButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset? offset = button?.localToGlobal(Offset.zero);
    final Size? size = button?.size;

    // Apple 风格颜色
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1D1D1F);
    final secondaryTextColor = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF8E8E93);
    final dividerColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E5EA);

    // 计算菜单位置
    final double menuWidth = 300;
    final double left = offset != null && size != null 
        ? offset.dx + size.width - menuWidth 
        : (MediaQuery.of(context).size.width - menuWidth) / 2;
    final double top = offset != null && size != null 
        ? offset.dy + size.height + 6 
        : 100;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '分类菜单',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            // 点击外部关闭区域
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.transparent),
              ),
            ),
            // 菜单内容
            Positioned(
              left: left.clamp(16, MediaQuery.of(context).size.width - menuWidth - 16),
              top: top,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: menuWidth,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 标题栏 - Apple 风格（归档页面没有新建/管理按钮）
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            border: Border(
                              bottom: BorderSide(
                                color: dividerColor,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '选择分类',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 分类列表 - Apple 风格
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 380),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 全部归档
                                _buildArchiveCategoryItem(
                                  context,
                                  color: isDark ? Colors.white70 : const Color(0xFF8E8E93),
                                  name: '全部归档',
                                  count: _totalCount,
                                  isSelected: _selectedCategoryId == null,
                                  textColor: textColor,
                                  secondaryTextColor: secondaryTextColor,
                                  dividerColor: dividerColor,
                                  onTap: () {
                                    setState(() {
                                      _selectedCategoryId = null;
                                      _currentTitle = '全部归档';
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                                // 未分类
                                _buildArchiveCategoryItem(
                                  context,
                                  color: Colors.grey,
                                  name: '未分类',
                                  count: _uncategorizedCount,
                                  isSelected: _selectedCategoryId == -1,
                                  textColor: textColor,
                                  secondaryTextColor: secondaryTextColor,
                                  dividerColor: dividerColor,
                                  onTap: () {
                                    setState(() {
                                      _selectedCategoryId = -1;
                                      _currentTitle = '未分类归档';
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                                // 各分类
                                ..._categories.map((category) {
                                  return _buildArchiveCategoryItem(
                                    context,
                                    color: category.color,
                                    name: category.name,
                                    count: category.noteCount ?? 0,
                                    isSelected: _selectedCategoryId == category.id,
                                    textColor: textColor,
                                    secondaryTextColor: secondaryTextColor,
                                    dividerColor: dividerColor,
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
            ),
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
    );
  }

  // Apple 风格分类项（归档页面）
  Widget _buildArchiveCategoryItem(
    BuildContext context, {
    required Color color,
    required String name,
    required int count,
    required bool isSelected,
    required Color textColor,
    required Color secondaryTextColor,
    required Color dividerColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // 颜色指示器 - Apple 风格小圆点
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 14),
              // 分类名称
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              // 选中标记
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.check,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              // 笔记数量 - Apple 风格
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
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

  /// 构建列表视图左滑显示的操作按钮
  List<Widget> _buildListActions(BuildContext context, Note note) {
    return [
      // 恢复按钮
      GestureDetector(
        onTap: () => _restoreNote(context, note),
        child: Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.unarchive,
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
                        key: _categoryButtonKey,
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
                onSwipeRight: () => _unarchiveNote(context, note),
                onDelete: () => _deleteNote(context, note),
                rightSwipeIcon: Icons.unarchive,
                rightSwipeLabel: '恢复',
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
                onSwipeRight: () => _unarchiveNote(context, note),
                onDelete: () => _deleteNote(context, note),
                rightSwipeIcon: Icons.unarchive,
                rightSwipeLabel: '恢复',
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
