import '../../domain/note.dart';
import '../../domain/category.dart';
import '../../utils/page_routes.dart';
import 'package:flutter/material.dart';

/// 卡片视图中的笔记卡片，标题后带更多按钮
class NoteCard extends StatefulWidget {
  final Note note;
  final Category? category;
  final VoidCallback onTap;
  final List<PopupMenuEntry<String>> Function(BuildContext context)? onBuildMenu;
  final void Function(String value)? onMenuSelected;
  final Color? tintColor;

  const NoteCard({
    super.key,
    required this.note,
    this.category,
    required this.onTap,
    this.onBuildMenu,
    this.onMenuSelected,
    this.tintColor,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  final GlobalKey _moreButtonKey = GlobalKey();

  String get heroTag => 'note_card_${widget.note.id ?? 'new'}';

  void _showMenu(BuildContext context) async {
    if (widget.onBuildMenu == null || widget.onMenuSelected == null) return;

    // 获取按钮位置
    final RenderBox? buttonRenderBox = _moreButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonRenderBox == null) return;

    final buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);
    final buttonSize = buttonRenderBox.size;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 获取菜单项
    final menuItems = widget.onBuildMenu!(context);
    if (menuItems.isEmpty) return;

    // 显示自定义菜单
    final value = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            // 点击空白处关闭
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.transparent),
              ),
            ),
            // 菜单内容 - 从更多按钮位置向下展开
            Positioned(
              right: MediaQuery.of(context).size.width - buttonPosition.dx - buttonSize.width + 4,
              top: buttonPosition.dy + buttonSize.height - 4,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildMenuItems(context, menuItems, isDark),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        );
      },
    );

    if (value != null) {
      widget.onMenuSelected!(value);
    }
  }

  /// 将 PopupMenuEntry 转换为 Widget 列表
  List<Widget> _buildMenuItems(BuildContext context, List<PopupMenuEntry<String>> items, bool isDark) {
    final result = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      if (item is PopupMenuItem<String>) {
        final value = item.value;
        final child = item.child;

        // 提取文本和颜色
        String? label;
        Color textColor = isDark ? Colors.white : Colors.black87;

        if (child is Row) {
          // 从 Row 中提取文本
          for (final childWidget in child.children) {
            if (childWidget is Text) {
              label = childWidget.data;
              // 检查文本颜色
              if (childWidget.style?.color != null) {
                textColor = childWidget.style!.color!;
              }
            }
          }
        } else if (child is Text) {
          label = child.data;
          if (child.style?.color != null) {
            textColor = child.style!.color!;
          }
        }

        if (label != null) {
          result.add(
            InkWell(
              onTap: () => Navigator.pop(context, value),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ),
          );
        }
      }

      // 添加分隔线（除了最后一个）
      if (i < items.length - 1) {
        result.add(
          Divider(
            height: 1,
            indent: 12,
            endIndent: 12,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        );
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final categoryColor = widget.category?.color;

    return NoteHero(
      tag: heroTag,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: categoryColor ?? (isDark ? Colors.white24 : Colors.grey.shade300),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 内容预览
                  Text(
                    widget.note.content.isEmpty ? '无内容' : widget.note.content,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 分隔线
                  Container(
                    height: 1,
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 12),
                  // 标题行（带更多按钮）
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: categoryColor ?? (isDark ? Colors.white54 : Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.note.title.isEmpty ? '无标题' : widget.note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      // 更多按钮
                      if (widget.onBuildMenu != null && widget.onMenuSelected != null)
                        GestureDetector(
                          key: _moreButtonKey,
                          onTap: () => _showMenu(context),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.more_vert,
                              size: 20,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 简单的占位组件
class NoteHero extends StatelessWidget {
  final String tag;
  final Widget child;

  const NoteHero({
    super.key,
    required this.tag,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }
}
