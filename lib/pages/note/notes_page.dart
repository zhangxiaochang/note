import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import '../../services/theme_provider.dart';
import '../editor/edit_page.dart';
import 'home_page_body.dart';

class NotePages extends StatefulWidget {
  const NotePages({super.key});

  @override
  State<NotePages> createState() => _NotePagesState();
}

class _NotePagesState extends State<NotePages> {
  late Future<List<Note>> _future;
  late Future<List<Note>> _allNotesFuture;
  bool _isCardView = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _allNotesFuture = DB.instance.queryAll();
      _future = _allNotesFuture;
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
      _future = _allNotesFuture;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _future = _allNotesFuture;
      } else {
        _future = _allNotesFuture.then((notes) {
          return notes.where((note) {
            return note.title.toLowerCase().contains(_searchQuery) ||
                note.content.toLowerCase().contains(_searchQuery);
          }).toList();
        });
      }
    });
  }

  Future<void> _handleRefresh() async {
    _reload();
    await _future;
  }

  void _toggleViewMode() {
    setState(() {
      _isCardView = !_isCardView;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final iconColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              stretch: true,
              pinned: true,
              expandedHeight: 60,
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              surfaceTintColor: Colors.transparent,
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
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: _isSearching
                          ? const SizedBox.shrink()
                          : IconButton(
                              icon: Icon(Icons.search, color: iconColor),
                              onPressed: _startSearch,
                              tooltip: '搜索',
                            ),
                    ),
              actions: [
                if (_isSearching)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: IconButton(
                      icon: Icon(Icons.close, color: iconColor),
                      onPressed: _stopSearch,
                      tooltip: '关闭搜索',
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: IconButton(
                    icon: Icon(Icons.refresh, color: iconColor),
                    onPressed: _reload,
                    tooltip: '刷新',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: IconButton(
                    icon: Icon(
                      _isCardView ? Icons.view_list : Icons.view_module,
                      color: iconColor,
                    ),
                    onPressed: _toggleViewMode,
                    tooltip: _isCardView ? '切换列表视图' : '切换卡片视图',
                  ),
                ),

              ],
            ),
          ];
        },
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: HomePageBody(
            future: _future,
            onRefresh: _handleRefresh,
            isCardView: _isCardView,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => EditPage()));
          _reload(); // 返回后刷新
        },
        tooltip: 'New',
        child: const Icon(Icons.add),
        shape: const CircleBorder(),
        backgroundColor: isDark ? Colors.lightBlueAccent : Colors.blue,
      ),
    );
  }
}