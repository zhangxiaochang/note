import 'package:flutter/material.dart';
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
      await PermissionManager.requestAllPermissions(context);
    }
  }

  // 页面列表
  late final List<Widget> pages = [
    _buildNotesPage(),
    _buildArchivePage(),
    _buildSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark 
          ? ThemeProvider.darkBackgroundColor 
          : ThemeProvider.lightBackgroundColor,

      // ====== 页面主体 ======
      body: IndexedStack(
        index: _currentIndex,
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

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final selectedColor = ThemeProvider.primaryColor;
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
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? ThemeProvider.primaryColor.withOpacity(0.1)
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