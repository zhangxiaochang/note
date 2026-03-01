import 'package:flutter/material.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import '../../services/BackupActions.dart';
import '../../utils/storage_analyzer_page.dart';
import '../editor/edit_page.dart';
import 'home_page_body.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Note>> _future;
  bool _isCardView = true;
  bool _debugEnabled = false;
  int _tapCount = 0;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = DB.instance.queryAll();
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
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: Colors.yellow.shade300,
              floating: true,
              snap: true,
              stretch: true,
              pinned: true,
              expandedHeight: 60,
                    title: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          final now = DateTime.now();
                          if (_lastTap == null ||
                              now.difference(_lastTap!) <
                                  const Duration(seconds: 1)) {
                            _tapCount++;
                          } else {
                            _tapCount = 1;
                          }
                          _lastTap = now;

                          if (_tapCount >= 5) {
                            setState(() {
                              _debugEnabled = true;
                            });
                            _tapCount = 0;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🔧 Debug mode enabled!'),
                              ),
                            );
                          } else {
                            _toggleViewMode();
                          }
                        },
                        child: const Text('Notes'),
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 5),

                        child: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _reload,
                          tooltip: '刷新',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: IconButton(
                          icon: const Icon(Icons.download_outlined),
                          onPressed: () =>
                              BackupActions.exportNotesWithDialog(context),
                          tooltip: '导出笔记',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: IconButton(
                          icon: const Icon(Icons.upload_outlined),
                          onPressed: () =>
                              BackupActions.importNotesWithDialog(context),
                          tooltip: '导入笔记',
                        ),
                      ),
                      if (_debugEnabled)
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: GestureDetector(
                            onLongPress: () {
                              setState(() {
                                _debugEnabled = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Debug mode disabled'),
                                ),
                              );
                            },
                            child: IconButton(
                              icon: const Icon(Icons.adb),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StorageAnalyzerPage(),
                                  ),
                                );
                              },
                            ),
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
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => EditPage()));
        },
        tooltip: 'New',
        child: Icon(Icons.add),
        shape: const CircleBorder(),
        backgroundColor: Color(0xFF2979FF),
      ),
    );
  }
}
