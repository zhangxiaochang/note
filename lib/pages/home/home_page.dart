import 'package:flutter/material.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
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
  bool _isCardView = true; // 👈 新增：默认卡片视图

  // 动画状态变量
  double _refreshOpacity = 1.0;
  double _scale = 1.0;

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
    // 开始动画
    if (!mounted) return;
    setState(() {
      _refreshOpacity = 0.6;
      _scale = 0.98;
    });

    await Future.delayed(const Duration(milliseconds: 200));

    _reload();

    // 等待数据加载完成
    await _future;

    // 结束动画
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _refreshOpacity = 1.0;
        _scale = 1.0;
      });
    }
  }

  // 👇 新增：切换视图模式
  void _toggleViewMode() {
    setState(() {
      _isCardView = !_isCardView;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _refreshOpacity,
        child: Transform.scale(
          scale: _scale,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  backgroundColor:Colors.yellow.shade300, // 👈 淡黄色（Material Design 调色板）
                  floating: true,
                  // 滚动停止后是否立即显示
                  snap: true,
                  // 快速滑动时“吸附”展开/收起
                  stretch: true,
                  // 允许下拉拉伸（配合刷新）
                  pinned: false,
                  // 不固定（设为 true 则始终显示标题）
                  title: Align(
                    alignment: Alignment.centerLeft, // 将标题左对齐
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
                        }
                      },
                      child: const Text('Notes'),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 5),

                      child: IconButton(
                        icon: Icon(
                          _isCardView ? Icons.view_list : Icons.grid_view,
                        ),
                        onPressed: _toggleViewMode,
                        tooltip: _isCardView ? '切换为列表' : '切换为卡片',
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
            body: HomePageBody(
              future: _future,
              onRefresh: _handleRefresh,
              isCardView: _isCardView,
            ),
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
        mini: true,
        backgroundColor: Color(0xFF2979FF),
      ),
    );
  }
}
