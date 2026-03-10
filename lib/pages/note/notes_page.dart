import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import '../../domain/category.dart';
import '../../services/theme_provider.dart';
import '../../utils/page_routes.dart';
import '../category/category_manage_page.dart';
import 'home_page_body.dart';

class NotePages extends StatefulWidget {
  const NotePages({super.key});

  @override
  State<NotePages> createState() => _NotePagesState();
}

class _NotePagesState extends State<NotePages> with SingleTickerProviderStateMixin {
  List<Category> _categories = [];
  int _totalCount = 0;
  int _uncategorizedCount = 0;
  bool _isLoading = true;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // 缓存笔记列表，避免每次搜索都查询数据库
  List<Note> _cachedNotes = [];

  // 刷新动画控制器
  late AnimationController _refreshController;

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final categories = await DB.instance.queryAllCategories();
    final total = await DB.instance.getTotalActiveNoteCount();
    final uncategorized = await DB.instance.getUncategorizedNoteCount();

    // 获取每个分类的笔记数量
    for (final cat in categories) {
      cat.noteCount = await DB.instance.getNoteCountByCategory(cat.id!);
    }

    // 缓存所有笔记
    final notes = await DB.instance.queryActive();

    setState(() {
      _categories = categories;
      _totalCount = total;
      _uncategorizedCount = uncategorized;
      _cachedNotes = notes;
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
              // 标题栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '选择分类',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showCreateCategoryDialog(context);
                          },
                          child: const Text('新建'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CategoryManagePage(),
                              ),
                            ).then((_) => _loadData());
                          },
                          child: const Text('管理'),
                        ),
                      ],
                    ),
                  ],
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
                      // 全部笔记
                      _buildMenuCategoryItem(
                        context,
                        color: isDark ? Colors.white70 : Colors.black54,
                        name: '全部笔记',
                        count: _totalCount,
                        onTap: () {
                          Navigator.pop(context);
                          _selectCategory(null, '全部笔记');
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
                          _selectCategory(-1, '未分类');
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
                              _selectCategory(category.id, category.name);
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

  int? _selectedCategoryId;
  String _currentTitle = '全部笔记';

  void _selectCategory(int? categoryId, String title) {
    setState(() {
      _selectedCategoryId = categoryId;
      _currentTitle = title;
    });
  }

  void _showCreateCategoryDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    int selectedColorIndex = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题栏
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '新建笔记本',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 颜色选择
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: Category.presetColors.asMap().entries.map((entry) {
                          final index = entry.key;
                          final color = entry.value;
                          final isSelected = index == selectedColorIndex;
                          return GestureDetector(
                            onTap: () => setState(() => selectedColorIndex = index),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: isDark ? Colors.white : Colors.black,
                                        width: 2,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 名称输入
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              margin: const EdgeInsets.only(left: 16),
                              decoration: BoxDecoration(
                                color: Category.presetColors[selectedColorIndex],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: nameController,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: '名称',
                                  hintStyle: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 按钮
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                '取消',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) return;
                                
                                final category = Category(
                                  name: name,
                                  colorValue: Category.presetColors[selectedColorIndex].value,
                                  createdAt: DateTime.now().millisecondsSinceEpoch,
                                );
                                
                                await DB.instance.insertCategory(category);
                                Navigator.pop(context);
                                _loadData();
                              },
                              child: Text(
                                '保存',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: nameController.text.trim().isEmpty
                                      ? (isDark ? Colors.white38 : Colors.black38)
                                      : Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

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
                                hintText: '搜索笔记...',
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
              '${_getCurrentCount()} 条笔记',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? ThemeProvider.darkSecondaryTextColor : ThemeProvider.lightSecondaryTextColor,
              ),
            ),
          ),
          // 笔记列表
          Expanded(
            child: _buildNoteListView(),
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 24, right: 20),
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.of(context).push(editPageRoute(null, heroTag: 'note_card_new'));
            _loadData();
          },
          tooltip: '新建笔记',
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          shape: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFFD4A017) : const Color(0xFFFFB800),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? const Color(0xFFD4A017) : const Color(0xFFFFB800)).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.add, size: 24, color: isDark ? Colors.black : Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteListView() {
    final themeProvider = context.watch<ThemeProvider>();
    return HomePageBody(
      notes: _getFilteredNotes(),
      onRefresh: _loadData,
      isCardView: themeProvider.isCardView,
      refreshCount: _refreshCount,
    );
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
