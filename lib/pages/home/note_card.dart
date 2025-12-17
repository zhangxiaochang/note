import '../../domain/note.dart';// 引入自定义note实体
import 'package:flutter/material.dart';// 引入 flutter material

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // 获取主题颜色，用于边框（浅色/深色模式都好看）
    final borderColor = Theme.of(context).dividerColor.withOpacity(0.15); // 更淡的边框颜色
    final shadowColor = Theme.of(context).brightness == Brightness.light ? Colors.grey.shade300 : Colors.black38; // 根据亮度设置阴影颜色

    return Card(
      elevation: 4, // 轻微的阴影，增加层次感
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5), // 外边距，增加空间感
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1), // 边框宽度和颜色
      ),
      color: Theme.of(context).colorScheme.surface, // 使用标准表面色
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note.content,
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Divider(
                thickness: 0.4, // 更细的分割线
                color: Theme.of(context).dividerColor.withOpacity(0.5), // 比较淡的颜色
              ),
              const SizedBox(height: 2),
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}