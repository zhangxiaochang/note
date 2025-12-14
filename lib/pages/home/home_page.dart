import 'package:flutter/material.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import '../editor/edit_page.dart';
import 'home_page_body.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Note>> _future;

  // 动画状态变量
  double _refreshOpacity = 1.0;
  double _scale = 1.0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Notes'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _handleRefresh,
            ),
          ),
        ],
      ),
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _refreshOpacity,
        child: Transform.scale(
          scale: _scale,
          child: HomePageBody(
            future: _future,
            onRefresh: _handleRefresh, // 传递带动画的刷新函数
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditPage(),
                ),
            );
          },
        tooltip: 'New',
        child: Icon(Icons.add),
        backgroundColor: Color(0xFFA5D6A7),
      ),
    );
  }
}
