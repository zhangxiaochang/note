import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import '../../services/theme_provider.dart';
import '../archive/archive_page.dart';
import '../note/notes_page.dart';
import '../settings/settings_page.dart';
import '../../utils/permission_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Android 平台申请权限
    if (Platform.isAndroid) {
      _requestPermissions();
    }
  }
  
  Future<void> _requestPermissions() async {
    // 延迟一下，等页面完全加载
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      // 检查是否已有权限
      final hasPermission = await PermissionManager.checkStoragePermission();
      if (!hasPermission) {
        // 没有权限，申请权限
        final granted = await PermissionManager.requestStoragePermission(context);
        if (!granted) {
          // 权限被拒绝，退出应用
          SystemNavigator.pop();
        }
      }
    }
  }

  // 页面列表
  late final List<Widget> pages = [
    _buildNotesPage(),
    _buildArchivePage(),
    _buildSettingsPage(),
  ];

  late final PageController _pageController = PageController(initialPage: _currentIndex);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark 
          ? ThemeProvider.darkBackgroundColor 
          : ThemeProvider.lightBackgroundColor,

      // ====== 页面主体 ======
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: pages,
      ),

      // ====== 自定义底部导航栏 ======
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark 
              ? ThemeProvider.darkCardColor 
              : ThemeProvider.lightCardColor,
          border: Border(
            top: BorderSide(
              color: isDark 
                  ? ThemeProvider.darkBorderColor 
                  : ThemeProvider.lightBorderColor,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.description_outlined, '笔记', isDark),
                _buildNavItem(1, Icons.archive_outlined, '归档', isDark),
                _buildNavItem(2, Icons.settings_outlined, '设置', isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 获取每个 tab 的选中颜色
  Color _getSelectedColor(int index) {
    switch (index) {
      case 0: // 笔记
        return ThemeProvider.primaryColor; // 黄色
      case 1: // 归档
        return Colors.blue;
      case 2: // 设置
        return Colors.green;
      default:
        return ThemeProvider.primaryColor;
    }
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final selectedColor = _getSelectedColor(index);
    final unselectedColor = isDark
        ? ThemeProvider.darkSecondaryTextColor
        : ThemeProvider.lightSecondaryTextColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? selectedColor.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: AnimatedScale(
            scale: isSelected ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              size: 24,
              color: isSelected ? selectedColor : unselectedColor,
            ),
          ),
        ),
      ),
    );
  }

  // ===== 页面占位 =====
  static Widget _buildNotesPage() {
    return const NotePages();
  }

  static Widget _buildArchivePage() {
    return const ArchivePage();
  }

  static Widget _buildSettingsPage() {
    return const SettingsPage();
  }
}