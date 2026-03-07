import '../../domain/note.dart';
import '../../domain/category.dart';
import '../../utils/page_routes.dart';
import 'package:flutter/material.dart';

/// 列表视图中的笔记项，支持右滑显示操作按钮和删除动画
class NoteListItem extends StatefulWidget {
  final Note note;
  final Category? category;
  final VoidCallback onTap;
  final List<Widget> Function(BuildContext context)? onBuildActions;
  final VoidCallback? onSwipeRight;
  final Color? tintColor;
  final VoidCallback? onDelete;

  const NoteListItem({
    super.key,
    required this.note,
    this.category,
    required this.onTap,
    this.onBuildActions,
    this.onSwipeRight,
    this.tintColor,
    this.onDelete,
  });

  @override
  State<NoteListItem> createState() => NoteListItemState();
}

class NoteListItemState extends State<NoteListItem>
    with TickerProviderStateMixin {
  // 两个按钮的总宽度
  static const double _actionsWidth = 136;

  // 当前偏移量（像素）
  double _offset = 0;

  late AnimationController _swipeController;
  Animation<double>? _swipeAnimation;

  // 删除动画控制器
  late AnimationController _deleteController;
  late Animation<double> _deleteHeightAnimation;
  late Animation<double> _deleteFadeAnimation;

  bool _isDeleting = false;

  String get heroTag => 'note_list_${widget.note.id ?? 'new'}';

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swipeController.addListener(() {
      if (_swipeAnimation != null) {
        setState(() {
          _offset = _swipeAnimation!.value;
        });
      }
    });

    // 初始化删除动画控制器
    _deleteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _deleteHeightAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _deleteController,
      curve: Curves.easeInOut,
    ));

    _deleteFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _deleteController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _deleteController.dispose();
    super.dispose();
  }

  void _animateSwipeTo(double targetOffset) {
    _swipeAnimation = Tween<double>(
      begin: _offset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOutBack,
    ));
    _swipeController.forward(from: 0);
  }

  void _handleSwipeRight() {
    if (widget.onSwipeRight != null) {
      // 先播放删除动画
      delete().then((_) {
        widget.onSwipeRight!();
      });
    }
  }

  /// 启动删除动画
  Future<void> delete() async {
    if (_isDeleting) return;
    _isDeleting = true;

    await _deleteController.forward();

    if (widget.onDelete != null) {
      widget.onDelete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final categoryColor = widget.category?.color;
    final actions = widget.onBuildActions?.call(context) ?? [];
    final screenWidth = MediaQuery.of(context).size.width;

    // 计算右滑进度（0-1）
    final archiveProgress =
        _offset > 0 ? (_offset / (screenWidth * 0.5)).clamp(0.0, 1.0) : 0.0;
    // 计算左滑进度（0-1）
    final actionProgress =
        _offset < 0 ? (-_offset / _actionsWidth).clamp(0.0, 1.0) : 0.0;

    // 使用更平滑的缓动函数
    final smoothArchiveProgress = Curves.easeInOut.transform(archiveProgress);
    final smoothActionProgress = Curves.easeInOut.transform(actionProgress);

    // 如果正在删除，使用动画包装
    Widget content = NoteHero(
      tag: heroTag,
      child: Stack(
        children: [
          // 归档背景层（右滑时显示）
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: Color.lerp(
                  isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
                  Colors.green.withValues(alpha: 0.8),
                  smoothArchiveProgress,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              child: Transform.translate(
                offset: Offset(-20 * (1 - smoothArchiveProgress), 0),
                child: Opacity(
                  opacity: smoothArchiveProgress,
                  child: Transform.scale(
                    scale: 0.5 + smoothArchiveProgress * 0.5,
                    child: const Icon(
                      Icons.archive_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 操作按钮层（左滑时显示）
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: Transform.translate(
                offset: Offset(20 * (1 - smoothActionProgress), 0),
                child: Opacity(
                  opacity: smoothActionProgress,
                  child: Transform.scale(
                    scale: 0.7 + smoothActionProgress * 0.3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 卡片层
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final delta = details.delta.dx;
              final newOffset =
                  (_offset + delta).clamp(-_actionsWidth, screenWidth * 0.5);

              setState(() {
                _offset = newOffset;
              });
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;

              // 如果右滑超过屏幕一半，触发归档
              if (_offset > screenWidth * 0.4) {
                _handleSwipeRight();
                return;
              }

              // 快速右滑
              if (velocity > 200) {
                _animateSwipeTo(0);
                return;
              }

              // 快速左滑 - 显示操作按钮
              if (velocity < -200) {
                _animateSwipeTo(-_actionsWidth);
                return;
              }

              // 根据位置判断是显示还是隐藏操作按钮
              if (_offset < -_actionsWidth * 0.3) {
                _animateSwipeTo(-_actionsWidth);
              } else {
                _animateSwipeTo(0);
              }
            },
            onTap: widget.onTap,
            child: Transform.translate(
              offset: Offset(_offset, 0),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: categoryColor ??
                        (isDark ? Colors.white24 : Colors.grey.shade300),
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
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 内容预览（如果有内容）- 在上面
                        if (widget.note.content.isNotEmpty) ...[
                          Text(
                            widget.note.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  isDark ? Colors.white70 : Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // 标题行 - 在下面
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 16,
                              decoration: BoxDecoration(
                                color: categoryColor ??
                                    (isDark
                                        ? Colors.white54
                                        : Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.note.title.isEmpty
                                    ? '无标题'
                                    : widget.note.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark ? Colors.white : Colors.black87,
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
          ),
        ],
      ),
    );

    // 添加删除动画
    return AnimatedBuilder(
      animation: _deleteController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _deleteFadeAnimation,
          child: SizeTransition(
            sizeFactor: _deleteHeightAnimation,
            axisAlignment: -1.0,
            child: child!,
          ),
        );
      },
      child: content,
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
    return child;
  }
}
