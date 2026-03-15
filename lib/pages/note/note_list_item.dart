import 'package:flutter/gestures.dart';

import '../../domain/note.dart';
import '../../domain/category.dart';
import 'package:flutter/material.dart';
import '../../services/theme_provider.dart';

/// 列表视图中的笔记项，支持右滑归档和左滑删除
class NoteListItem extends StatefulWidget {
  final Note note;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback? onSwipeRight;
  final Color? tintColor;
  final VoidCallback? onDelete;
  final IconData? rightSwipeIcon;
  final String? rightSwipeLabel;

  const NoteListItem({
    super.key,
    required this.note,
    this.category,
    required this.onTap,
    this.onSwipeRight,
    this.tintColor,
    this.onDelete,
    this.rightSwipeIcon,
    this.rightSwipeLabel,
  });

  @override
  State<NoteListItem> createState() => NoteListItemState();
}

class NoteListItemState extends State<NoteListItem>
    with TickerProviderStateMixin {
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
      _playSwipeAnimation().then((_) {
        widget.onSwipeRight!();
      });
    }
  }

  void _handleSwipeLeft() {
    debugPrint('左滑删除被触发');
    if (widget.onDelete != null) {
      debugPrint('调用 onDelete 回调');
      _playSwipeAnimation().then((_) {
        widget.onDelete!();
      });
    } else {
      debugPrint('onDelete 为 null');
    }
  }

  /// 播放滑出动画
  Future<void> _playSwipeAnimation() async {
    if (_isDeleting) return;
    _isDeleting = true;

    await _deleteController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? ThemeProvider.darkCardColor : ThemeProvider.lightCardColor;
    final screenWidth = MediaQuery.of(context).size.width;

    // 计算右滑进度（0-1）
    final archiveProgress =
        _offset > 0 ? (_offset / (screenWidth * 0.6)).clamp(0.0, 1.0) : 0.0;
    // 计算左滑进度（0-1）
    final deleteProgress =
        _offset < 0 ? (-_offset / (screenWidth * 0.8)).clamp(0.0, 1.0) : 0.0;

    // 如果正在删除，使用动画包装
    Widget content = Stack(
      children: [
        // 右滑背景层（归档）- 带提示
        if (_offset > 0)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              decoration: BoxDecoration(
                color: ThemeProvider.secondaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              child: Row(
                children: [
                  // 图标
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.rightSwipeIcon ?? Icons.archive_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 文字提示
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 主标题
                        Text(
                          widget.rightSwipeLabel ?? '归档',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 提示文字（当进度达到1.0时表示已达到归档阈值）
                        Text(
                          archiveProgress < 1.0
                            ? '继续右滑以${widget.rightSwipeLabel ?? '归档'}'
                            : '松开以确认',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 进度指示器
                  Container(
                    margin: const EdgeInsets.only(right: 24),
                    width: 36,
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.transparent),
                        ),
                        CircularProgressIndicator(
                          value: archiveProgress,
                          strokeWidth: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        if (archiveProgress >= 1.0)
                          const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        // 左滑背景层（删除）- 带提示
        if (_offset < 0)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 进度指示器
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    width: 36,
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.transparent),
                        ),
                        CircularProgressIndicator(
                          value: deleteProgress,
                          strokeWidth: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        if (deleteProgress >= 1.0)
                          const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                  // 文字提示
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 主标题
                        const Text(
                          '删除',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 提示文字（当进度达到1.0时表示已达到删除阈值）
                        Text(
                          deleteProgress < 1.0
                            ? '继续左滑以删除'
                            : '松开以确认',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 图标
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // 卡片层
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          dragStartBehavior: DragStartBehavior.start,
          onHorizontalDragStart: (_) {},
          onHorizontalDragUpdate: (details) {
            final delta = details.delta.dx;
            // 增加阻力效果
            double resistance = 1.0;
            if (_offset > 0 && delta > 0) {
              // 右滑时增加阻力
              resistance = 1.0 - (_offset / (screenWidth * 0.8)) * 0.4;
              resistance = resistance.clamp(0.6, 1.0);
            } else if (_offset < 0 && delta < 0) {
              // 左滑时增加阻力
              resistance = 1.0 - (-_offset / (screenWidth * 0.8)) * 0.4;
              resistance = resistance.clamp(0.6, 1.0);
            }
            final newOffset =
                (_offset + delta * resistance).clamp(-screenWidth * 0.8, screenWidth * 0.8);

            setState(() {
              _offset = newOffset;
            });
          },
          onHorizontalDragEnd: (details) {
            final deleteThreshold = -screenWidth * 0.7;
            debugPrint('onHorizontalDragEnd: _offset=$_offset, threshold=$deleteThreshold, screenWidth=$screenWidth');
            final velocity = details.primaryVelocity ?? 0;

            // 如果左滑超过阈值（屏幕宽度的70%），触发删除
            if (_offset <= deleteThreshold) {
              debugPrint('左滑超过阈值，触发删除');
              _handleSwipeLeft();
              return;
            }

            // 如果右滑超过阈值（屏幕宽度的60%），触发归档
            final archiveThreshold = screenWidth * 0.6;
            debugPrint('右滑检查: _offset=$_offset, threshold=$archiveThreshold');
            if (_offset > archiveThreshold) {
              debugPrint('右滑超过阈值，触发归档');
              _handleSwipeRight();
              return;
            }

            // 快速滑动回弹（只有在未达到阈值时才触发）
            if (velocity.abs() > 200) {
              debugPrint('快速滑动回弹');
              _animateSwipeTo(0);
              return;
            }

            // 回弹到原位
            debugPrint('回弹到原位');
            _animateSwipeTo(0);
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
        ),
      ],
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
