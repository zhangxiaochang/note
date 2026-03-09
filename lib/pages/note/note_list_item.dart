import '../../domain/note.dart';
import '../../domain/category.dart';
import '../../utils/page_routes.dart';
import 'package:flutter/material.dart';
import '../../services/theme_provider.dart';

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
    final cardColor = isDark ? ThemeProvider.darkCardColor : ThemeProvider.lightCardColor;
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
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              decoration: BoxDecoration(
                color: Color.lerp(
                  isDark ? ThemeProvider.darkCardColor : ThemeProvider.lightCardColor,
                  ThemeProvider.secondaryColor.withOpacity(0.8),
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
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              decoration: BoxDecoration(
                color: isDark ? ThemeProvider.darkCardColor : ThemeProvider.lightCardColor,
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
            child: Transform.translate(
              offset: Offset(_offset, 0),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.06),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(16),
                    hoverColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 标题行
                          Text(
                            widget.note.title.isEmpty
                                ? '无标题'
                                : widget.note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? ThemeProvider.darkTextColor
                                  : ThemeProvider.lightTextColor,
                            ),
                          ),
                          // 底部信息栏：时间 | 内容预览 | 分类标签
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // 时间
                              Text(
                                _formatDate(widget.note.updatedAt),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: isDark
                                      ? ThemeProvider.darkSecondaryTextColor
                                      : ThemeProvider.lightSecondaryTextColor,
                                ),
                              ),
                              // 分隔符和内容预览（如果有内容）
                              if (widget.note.content.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 1,
                                  height: 12,
                                  color: isDark
                                      ? ThemeProvider.darkSecondaryTextColor.withOpacity(0.3)
                                      : ThemeProvider.lightSecondaryTextColor.withOpacity(0.3),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.note.content,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? ThemeProvider.darkSecondaryTextColor
                                          : ThemeProvider.lightSecondaryTextColor,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const Spacer(),
                              ],
                              // 分类标签
                              if (widget.category != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? ThemeProvider.categoryTagDarkBg
                                        : ThemeProvider.categoryTagLightBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    widget.category!.name,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: widget.category!.color,
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
          )
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

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    // 判断是否是今年
    final isThisYear = date.year == now.year;

    if (isThisYear) {
      // 今年：只显示月日（单位数）
      return '${date.month}月${date.day}日';
    } else {
      // 往年：显示年月日
      return '${date.year}年${date.month}月${date.day}日';
    }
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
