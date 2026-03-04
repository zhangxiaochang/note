import 'package:flutter/material.dart';
import '../editor/edit_page.dart';
import '../note/notes_page.dart';
import '../settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // 页面列表
  late final List<Widget> pages = [
    _buildNotesPage(),
    _buildArchivePage(),
    _buildSettingsPage(),
  ];

  Color _tabColor(int index, bool isDark) {
    final lightColors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
    ];
    final darkColors = [
      Colors.lightBlueAccent,
      Colors.deepOrangeAccent,
      Colors.lightGreenAccent,
    ];
    return isDark ? darkColors[index] : lightColors[index];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentColor = _tabColor(_currentIndex, isDark);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,

      // ====== 页面主体 ======
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),

      // ====== FAB ======
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerFloat,

      // ====== BottomNavigationBar ======
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        selectedItemColor: currentColor,
        unselectedItemColor: isDark ? Colors.white54 : Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          BottomNavigationBarItem(
            icon: AnimatedScale(
              scale: _currentIndex == 0 ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _currentIndex == 0 ? Icons.note : Icons.note_outlined,
              ),
            ),
            tooltip: '笔记',
              label:""
          ),
          BottomNavigationBarItem(
            icon: AnimatedScale(
              scale: _currentIndex == 1 ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _currentIndex == 1 ? Icons.archive : Icons.archive_outlined,
              ),
            ),
            tooltip: '归档',
              label:""
          ),
          BottomNavigationBarItem(
            icon: AnimatedScale(
              scale: _currentIndex == 2 ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _currentIndex == 2 ? Icons.settings : Icons.settings_outlined,
              ),
            ),
            tooltip: '设置',
            label:""
          ),
        ],
      ),
    );
  }

  // ===== 页面占位 =====
  static Widget _buildNotesPage() {
    return const NotePages();
  }

  static Widget _buildArchivePage() {
    return const Center(
      child: Text(
        '归档页面',
        style: TextStyle(fontSize: 22),
      ),
    );
  }

  static Widget _buildSettingsPage() {
    return const SettingsPage();
  }
}