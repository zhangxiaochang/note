import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:project/pages/editor/edit_page.dart';
import '../../dao/db.dart';
import '../../domain/note.dart';
import 'note_card.dart';

class HomePageBody extends StatelessWidget {
  final Future<List<Note>> future;
  final Future<void> Function() onRefresh;
  final bool isCardView; // 👈 必须有这个参数

  const HomePageBody({
    super.key,
    required this.future,
    required this.onRefresh,
    required this.isCardView, // 👈
  });

  static Future<void> _deleteNote(BuildContext context, Note note) async {
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

    if (confirmed == true) {
      try {
        await DB.instance.delete(note.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除笔记: ${note.title}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
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

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width ~/ 170;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Note>>(
      future: future,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('加载失败: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: onRefresh, child: const Text('重试')),
              ],
            ),
          );
        }

        final notes = snapshot.data ?? [];
        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.note_add, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('暂无笔记', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  '点击右上角 + 按钮创建新笔记',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
              ],
            ),
          );
        }
        // 👇 核心修改：根据 isCardView 决定布局
        Widget content;
        if (isCardView) {
          // 卡片模式：瀑布流
          content = MasonryGridView.count(
            crossAxisCount: _crossAxisCount(context),
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            itemCount: notes.length,
            itemBuilder: (_, index) {
              final note = notes[index];
              return NoteCard(
                note: note,
                onTap: () {
                  Navigator.of(context)
                      .push<bool>(
                        MaterialPageRoute(builder: (_) => EditPage(note: note)),
                      )
                      .then((edited) {
                        if (edited == true) {
                          onRefresh();
                        }
                      });
                },
                onLongPress: () {
                  _deleteNote(context, note).then((_) {
                    onRefresh();
                  });
                },
              );
            },
          );
        } else {
          // 列表模式：ListView
          content = ListView.builder(
            itemCount: notes.length,
            padding: const EdgeInsets.all(8.0),
            itemBuilder: (_, index) {
              final note = notes[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  title: Text(
                    note.title.isEmpty ? '<无标题>' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context)
                        .push<bool>(
                          MaterialPageRoute(
                            builder: (_) => EditPage(note: note),
                          ),
                        )
                        .then((edited) {
                          if (edited == true) {
                            onRefresh();
                          }
                        });
                  },
                  onLongPress: () {
                    _deleteNote(context, note).then((_) {
                      onRefresh();
                    });
                  },
                ),
              );
            },
          );
        }
        // ✅ 关键：在这里包裹 RefreshIndicator！
        return RefreshIndicator(onRefresh: onRefresh, child: content);
      },
    );
  }
}
