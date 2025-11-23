import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'markdown_edit_page.dart';
import '../dao/db.dart';
import '../domain/note.dart';
import 'note_card.dart';
//我声明了一个叫 HomePage 的“页面类”，它继承自 StatefulWidget。
// 凡是你想“让界面以后能变”（比如点击按钮后数字 +1、网络请求后刷列表）就继承 StatefulWidget；
// 如果界面一辈子不变，就继承 StatelessWidget。
class HomePage extends StatefulWidget {
  //构造函数，传入一个 key 参数（Flutter 内部用于组件复用，可以忽略）。
  const HomePage({super.key});

  //作用：重写父类方法，返回一个 专门管理 HomePage 状态和UI 的类（即 _HomePageState）。
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  void _refresh() async {_future = DB.instance.queryAll();}
  late Future<List<Note>> _future;

  @override
  void initState() {
    super.initState();
    _reload(); // 首次加载
  }
  // 添加动画相关变量
  // 增强动画变量
  double _refreshOpacity = 1.0;
  bool _isRefreshing = false;
  double _scale = 1.0;

  void _reload() => _future = DB.instance.queryAll();
  Future<void> _handleRefresh() async {
    // 更明显的开始动画
    setState(() {
      _isRefreshing = true;
      _refreshOpacity = 0.6;  // 更透明
      _scale = 0.98;         // 添加缩放效果
    });

    // 添加短暂延迟让动画更明显
    await Future.delayed(const Duration(milliseconds: 200));

    // 重新加载数据
    setState(() {
      _reload();
    });

    // 等待数据加载完成
    await _future;

    // 更平滑的结束动画
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _isRefreshing = false;
      _refreshOpacity = 1.0;
      _scale = 1.0;
    });
  }

  Widget _buildEditPage({Note? note}) {
    return MarkdownEditPage(note: note);
  }

  Future<void> _deleteNote(Note note) async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除笔记'),
          content: Text('确定要删除 "${note.title}" 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    // 2. 如果用户确认删除，执行删除操作
    if (confirmed == true) {
      try {
        // 执行删除操作
        await DB.instance.delete(note.id!);

        // 显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除笔记: ${note.title}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // 刷新列表
        _handleRefresh();
      } catch (e) {
        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  int _crossAxisCount(BuildContext ctx) {
    final width = MediaQuery.of(ctx).size.width;
    return width ~/ 110;   // 220 dp 一个卡片，想稀一点改大
  }
  //作用：Flutter 中所有页面的根组件都从 build 方法返回。
  //context：包含了父级 Widget 的数据（如主题、导航）。
  @override
  Widget build(BuildContext context) {
    // Scaffold Material Design 的页面骨架，提供默认结构（顶部栏、浮动按钮等）。
    // - appbar 顶部按钮
    // - body：页面的核心内容区域。
    return Scaffold(
        extendBodyBehindAppBar: true,   // ← 加上这行！关键！
        appBar: AppBar(
        title: const Text('Notes'),
          actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: ()  {
              _handleRefresh(); // 使用统一的刷新
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              // 等待编辑页返回，如果返回 true 就刷新
              final added = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => _buildEditPage()),
              );
              if (added == true) {
                _handleRefresh();
              };
            },
          ),
        ],
      ),
      body:AnimatedOpacity(
        duration: const Duration(milliseconds: 300), // 动画时长
        opacity: _refreshOpacity,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child:FutureBuilder<List<Note>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.data!.isEmpty) {
                return const Center(child: Text('暂无笔记'));
              }
              return Padding(
                padding: const EdgeInsets.all(8),
                child: MasonryGridView.count(
                  crossAxisCount: _crossAxisCount(context),
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  itemCount: snap.data!.length,
                  itemBuilder: (_, i) {
                    final note = snap.data![i];
                    return NoteCard(
                      note: note,
                      onTap: () async {
                        final edited = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => _buildEditPage(note: note)),
                        );
                        if (edited == true){
                          _handleRefresh();
                        }
                      },
                      onLongPress: () => _deleteNote(note),
                    );
                  },
                ),
              );
            },
          ),
        ) ,
      )
    );
  }
}
