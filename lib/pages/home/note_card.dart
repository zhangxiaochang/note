import '../../domain/note.dart';// 引入自定义note实体
import 'package:flutter/material.dart';// 引入 flutter material

class NoteCard extends StatelessWidget { // 无状态组件 less  有状态组件 ful
  final Note note; // 数据容器
  final VoidCallback onTap; // 点击方法
  final VoidCallback onLongPress;  // 1. 添加长按回调参数

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,      // 2. 添加到构造函数
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceVariant, // 使用表面变体色
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(  // 提供水波纹点击效果 InkWell
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,  // 3. 添加长按事件
        child: Container(
          padding: const EdgeInsets.all(12), // 内边距12像素
          width: double.infinity, // 宽度充满父容器
          child: Column(  // 垂直排列
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // 重要：让Column只占用必要高度
            children: [
              Text(
                note.title,
                maxLines: 2,  // 最多2行标题
                overflow: TextOverflow.ellipsis, // 超出的字体
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                  note.content,
                  maxLines: 10, // 限制最大行数，避免单个卡片过高
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}