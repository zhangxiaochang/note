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

  void _showCategoryMenu(BuildContext context, {required GlobalKey buttonKey}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 从 GlobalKey 获取按钮位置
    final RenderBox? button = buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset? offset = button?.localToGlobal(Offset.zero);
    final Size? size = button?.size;

    if (offset == null || size == null) {
      // 如果获取不到按钮位置，显示在屏幕中间
      _showCategoryMenuCentered(context);
      return;
    }

    // Apple 风格颜色
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1D1D1F);
    final secondaryTextColor = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF8E8E93);
    final dividerColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E5EA);

    // 计算菜单位置（在按钮下方）
    final double menuWidth = 300;
    final double left = offset.dx + size.width - menuWidth;
    final double top = offset.dy + size.height + 6;

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
                        // 标题栏 - Apple 风格
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              Row(
                                children: [
                                  _buildAppleMenuButton(
                                    context: context,
                                    label: '新建',
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showCreateCategoryDialog(context);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildAppleMenuButton(
                                    context: context,
                                    label: '管理',
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const CategoryManagePage(),
                                        ),
                                      ).then((_) => _loadData());
                                    },
                                  ),
                                ],
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
                                // 全部笔记
                                _buildAppleCategoryItem(
                                  context,
                                  color: isDark ? Colors.white70 : const Color(0xFF8E8E93),
                                  name: '全部笔记',
                                  count: _totalCount,
                                  isSelected: _selectedCategoryId == null,
                                  textColor: textColor,
                                  secondaryTextColor: secondaryTextColor,
                                  dividerColor: dividerColor,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _selectCategory(null, '全部笔记');
                                  },
                                ),
                                // 未分类
                                _buildAppleCategoryItem(
                                  context,
                                  color: Colors.grey,
                                  name: '未分类',
                                  count: _uncategorizedCount,
                                  isSelected: _selectedCategoryId == -1,
                                  textColor: textColor,
                                  secondaryTextColor: secondaryTextColor,
                                  dividerColor: dividerColor,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _selectCategory(-1, '未分类');
                                  },
                                ),
                                // 自定义分类
                                ..._categories.expand((category) {
                                  return [
                                    _buildAppleCategoryItem(
                                      context,
                                      color: category.color,
                                      name: category.name,
                                      count: category.noteCount ?? 0,
                                      isSelected: _selectedCategoryId == category.id,
                                      textColor: textColor,
                                      secondaryTextColor: secondaryTextColor,
                                      dividerColor: dividerColor,
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
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
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

  // 备用：居中显示分类菜单（Apple 风格）
  void _showCategoryMenuCentered(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Apple 风格颜色
    final backgroundColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7);
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1D1D1F);
    final secondaryTextColor = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF8E8E93);
    final dividerColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E5EA);
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '分类菜单',
      barrierColor: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题栏 - Apple 风格
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          Row(
                            children: [
                              _buildAppleMenuButton(
                                context: context,
                                label: '新建',
                                onTap: () {
                                  Navigator.pop(context);
                                  _showCreateCategoryDialog(context);
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildAppleMenuButton(
                                context: context,
                                label: '管理',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const CategoryManagePage(),
                                    ),
                                  ).then((_) => _loadData());
                                },
                              ),
                            ],
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
                            _buildAppleCategoryItem(
                              context,
                              color: isDark ? Colors.white70 : const Color(0xFF8E8E93),
                              name: '全部笔记',
                              count: _totalCount,
                              isSelected: _selectedCategoryId == null,
                              textColor: textColor,
                              secondaryTextColor: secondaryTextColor,
                              dividerColor: dividerColor,
                              onTap: () {
                                Navigator.pop(context);
                                _selectCategory(null, '全部笔记');
                              },
                            ),
                            _buildAppleCategoryItem(
                              context,
                              color: Colors.grey,
                              name: '未分类',
                              count: _uncategorizedCount,
                              isSelected: _selectedCategoryId == -1,
                              textColor: textColor,
                              secondaryTextColor: secondaryTextColor,
                              dividerColor: dividerColor,
                              onTap: () {
                                Navigator.pop(context);
                                _selectCategory(-1, '未分类');
                              },
                            ),
                            ..._categories.expand((category) {
                              return [
                                _buildAppleCategoryItem(
                                  context,
                                  color: category.color,
                                  name: category.name,
                                  count: category.noteCount ?? 0,
                                  isSelected: _selectedCategoryId == category.id,
                                  textColor: textColor,
                                  secondaryTextColor: secondaryTextColor,
                                  dividerColor: dividerColor,
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
              ),
            ),
          ),
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

  // Apple 风格菜单按钮
  Widget _buildAppleMenuButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  // Apple 风格分类项
  Widget _buildAppleCategoryItem(
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
                        key: _categoryButtonKey,
                        onTap: () => _showCategoryMenu(context, buttonKey: _categoryButtonKey),
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
    // 加载时传入空列表，isLoading 控制骨架屏显示
    return HomePageBody(
      notes: _getFilteredNotes(),
      onRefresh: _loadData,
      isCardView: themeProvider.isCardView,
      refreshCount: _refreshCount,
      isLoading: _isLoading,
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
