import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import '../../domain/note.dart';
import '../../domain/category.dart';
import 'package:flutter/material.dart';
import '../../services/theme_provider.dart';

/// 列表视图中的笔记项：仅支持左滑，在右侧露出「归档 / 删除」两个圆形操作按钮
class NoteListItem extends StatefulWidget {
  final Note note;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback? onSwipeRight;
  final Color? tintColor;
  final VoidCallback? onDelete;
  final IconData? rightSwipeIcon;
  final String? rightSwipeLabel;

  /// 列表父级当前允许保持左滑打开的那条笔记 uuid；切换时非该 uuid 的行会自动收回
  final String? swipeOpenExclusiveUuid;
  final void Function(String noteUuid)? onSwipeExclusiveClaim;
  final void Function(String noteUuid)? onSwipeExclusiveRelease;

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
    this.swipeOpenExclusiveUuid,
    this.onSwipeExclusiveClaim,
    this.onSwipeExclusiveRelease,
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

  String get heroTag => 'note_list_${widget.note.uuid}';

  /// 获取同步状态图标
  Widget _getSyncStatusIcon() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (widget.note.syncStatus) {
      case 'synced':
        return Icon(
          Icons.check_circle_outline,
          size: 14,
          color: isDark ? Colors.green.withOpacity(0.7) : Colors.green,
        );
      case 'pending_upload':
        return Icon(
          Icons.cloud_upload_outlined,
          size: 14,
          color: isDark ? Colors.blue.withOpacity(0.7) : Colors.blue,
        );
      case 'pending_download':
        return Icon(
          Icons.cloud_download_outlined,
          size: 14,
          color: isDark ? Colors.orange.withOpacity(0.7) : Colors.orange,
        );
      default:
        return const SizedBox.shrink();
    }
  }

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

  @override
  void didUpdateWidget(covariant NoteListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final host = widget.swipeOpenExclusiveUuid;
    if (host != null &&
        host != widget.note.uuid &&
        _offset < 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.swipeOpenExclusiveUuid != widget.note.uuid && _offset < 0) {
          _animateSwipeTo(0);
        }
      });
    }
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

  void _triggerArchive() {
    if (widget.onSwipeRight != null) {
      if (widget.swipeOpenExclusiveUuid == widget.note.uuid) {
        widget.onSwipeExclusiveRelease?.call(widget.note.uuid);
      }
      _playSwipeAnimation().then((_) {
        widget.onSwipeRight!();
      });
    }
  }

  void _triggerDelete() {
    if (widget.onDelete != null) {
      if (widget.swipeOpenExclusiveUuid == widget.note.uuid) {
        widget.onSwipeExclusiveRelease?.call(widget.note.uuid);
      }
      _playSwipeAnimation().then((_) {
        widget.onDelete!();
      });
    }
  }

  void _notifySwipeExclusiveReleaseIfNeeded() {
    if (widget.swipeOpenExclusiveUuid == widget.note.uuid) {
      widget.onSwipeExclusiveRelease?.call(widget.note.uuid);
    }
  }

  void _notifySwipeExclusiveClaim() {
    widget.onSwipeExclusiveClaim?.call(widget.note.uuid);
  }

  /// 左滑展开宽度按按钮布局常量推导，避免不同屏宽下「卡片到按钮」间距漂移。
  double _maxReveal(double screenWidth) {
    const buttonDiameter = 40.0;
    const buttonGap = 10.0;
    const gapFromCard = 12.0;
    const trailingPadding = 8.0;
    final target = buttonDiameter * 2 + buttonGap + gapFromCard + trailingPadding;
    return target.clamp(102.0, 118.0);
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
    final maxReveal = _maxReveal(screenWidth);

    // 左滑进度（0–1），仅用于按钮轻微缩放；前景卡片保持不透明，与参考图一样是「实心条 + 硬边」
    final stripProgress =
        _offset < 0 ? (-_offset / maxReveal).clamp(0.0, 1.0) : 0.0;

    // 如果正在删除，使用动画包装
    // clipBehavior 必须为 hardEdge：避免 Transform 画进相邻瀑布流格子。
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final stackW = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
        if (_offset < 0)
          _buildLeftSwipeBackground(
            progress: stripProgress,
            maxReveal: maxReveal,
            stackWidth: stackW,
          ),
        // 卡片层（仅允许向左拖动）
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          dragStartBehavior: DragStartBehavior.start,
          onHorizontalDragStart: (_) {},
          onHorizontalDragUpdate: (details) {
            final delta = details.delta.dx;
            double resistance = 1.0;
            if (_offset < 0 && delta < 0) {
              resistance = 1.0 - ((-_offset) / (maxReveal * 1.15)) * 0.38;
              resistance = resistance.clamp(0.62, 1.0);
            }
            var newOffset = _offset + delta * resistance;
            if (newOffset > 0) newOffset = 0;
            newOffset = newOffset.clamp(-maxReveal, 0);

            final wasOpen = _offset < 0;
            setState(() {
              _offset = newOffset;
            });
            if (!wasOpen && newOffset < 0) {
              _notifySwipeExclusiveClaim();
            }
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;

            if (_offset >= 0) {
              _animateSwipeTo(0);
              return;
            }

            if (velocity < -420) {
              _notifySwipeExclusiveClaim();
              _animateSwipeTo(-maxReveal);
              return;
            }
            if (velocity > 420) {
              _notifySwipeExclusiveReleaseIfNeeded();
              _animateSwipeTo(0);
              return;
            }
            if (-_offset > maxReveal / 2) {
              _notifySwipeExclusiveClaim();
              _animateSwipeTo(-maxReveal);
            } else {
              _notifySwipeExclusiveReleaseIfNeeded();
              _animateSwipeTo(0);
            }
          },
          child: Transform.translate(
              offset: Offset(_offset, 0),
              child: LayoutBuilder(
              builder: (context, constraints) {
                // 计算可用宽度（与下方 horizontal padding 一致）
                final availableWidth = constraints.maxWidth - 28;
                final hasContent = widget.note.content.isNotEmpty;
                final categoryColor = widget.category?.color;
                // 如果有分类颜色，使用淡化的分类颜色作为背景，否则使用默认卡片颜色
                final cardBackgroundColor = categoryColor != null
                    ? categoryColor.withOpacity(isDark ? 0.15 : 0.08)
                    : cardColor;
                
                // 根据屏幕宽度决定是否显示内容预览
                final showContent = hasContent && availableWidth > 280;

                // 左滑时仍保持四角圆角；与底层叠像素 overlap 减轻圆角与直边接缝露线
                const cardBorderRadius = BorderRadius.all(Radius.circular(16));

                return ClipRRect(
                  borderRadius: cardBorderRadius,
                  child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                  decoration: BoxDecoration(
                    color: cardBackgroundColor,
                    borderRadius: cardBorderRadius,
                    border: Border.all(
                      color: categoryColor != null
                          ? categoryColor.withOpacity(isDark ? 0.3 : 0.2)
                          : (isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.06)),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    borderRadius: cardBorderRadius,
                    child: InkWell(
                      onTap: widget.onTap,
                      borderRadius: cardBorderRadius,
                      hoverColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                height: 1.25,
                                color: isDark
                                    ? ThemeProvider.darkTextColor
                                    : ThemeProvider.lightTextColor,
                              ),
                            ),
                            // 底部信息栏：时间 | 同步状态 | 内容预览
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // 时间
                                Text(
                                  _formatDate(widget.note.updatedAt),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    height: 1.2,
                                    color: isDark
                                        ? ThemeProvider.darkSecondaryTextColor
                                        : ThemeProvider.lightSecondaryTextColor,
                                  ),
                                ),
                                // 同步状态图标
                                const SizedBox(width: 5),
                                _getSyncStatusIcon(),
                                // 分隔符和内容预览（如果有内容且空间足够）
                                if (showContent) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 1,
                                    height: 12,
                                    color: isDark
                                        ? ThemeProvider.darkSecondaryTextColor.withOpacity(0.3)
                                        : ThemeProvider.lightSecondaryTextColor.withOpacity(0.3),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      widget.note.content,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        height: 1.2,
                                        color: isDark
                                            ? ThemeProvider.darkSecondaryTextColor
                                            : ThemeProvider.lightSecondaryTextColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                );
              },
              ),
            ),
        ),
          ],
        );
      },
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

  /// 左滑操作区（深浅共用布局：靠右双钮 + 固定间距；仅条底色浅透 / 深 scaffold 不同）
  ///
  /// 左叠 overlap 与卡片圆角右缘衔接，减轻细缝。
  Widget _buildLeftSwipeBackground({
    required double progress,
    required double maxReveal,
    required double stackWidth,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const archiveCircleColor = Color(0xFF2196F3);
    const deleteCircleColor = Color(0xFFEF5350);
    final primaryIcon =
        widget.rightSwipeIcon ?? Icons.drive_file_move_rtl;

    final reveal = (-_offset).clamp(0.0, maxReveal);
    // 略大叠盖，适配卡片右侧圆角下的楔形区域，减轻接缝露线
    const overlap = 12.0;

    // 固定「卡片右缘 -> 首个按钮」距离，保证不同屏宽视觉一致
    const gapFromCard = 12.0;
    const trailingPadding = 8.0;

    // 浅色用透明避免与页面底色差一条；深色用 scaffold 铺满槽位
    final stripBg =
        isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.transparent;

    Widget swipeActionPair() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSwipeCircleButton(
            icon: primaryIcon,
            tint: archiveCircleColor,
            progress: progress,
            onTap: () {
              if (widget.onSwipeRight != null) _triggerArchive();
            },
            semanticLabel: widget.rightSwipeLabel ?? '归档',
            onCapsuleSurface: false,
            onFloatingStrip: true,
            diameter: 40,
            iconSize: 19,
          ),
          const SizedBox(width: 10),
          _buildSwipeCircleButton(
            icon: Icons.delete_outline_rounded,
            tint: deleteCircleColor,
            progress: progress,
            onTap: () {
              if (widget.onDelete != null) _triggerDelete();
            },
            semanticLabel: '删除',
            onCapsuleSurface: false,
            onFloatingStrip: true,
            diameter: 40,
            iconSize: 19,
          ),
        ],
      );
    }

    return Positioned(
      left: stackWidth + _offset - overlap,
      top: 6,
      bottom: 6,
      width: reveal + overlap,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        child: ColoredBox(
          color: stripBg,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(overlap + gapFromCard, 2, trailingPadding, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: math.max(0, reveal - gapFromCard - trailingPadding),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: swipeActionPair(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeCircleButton({
    required IconData icon,
    required Color tint,
    required double progress,
    required VoidCallback onTap,
    String? semanticLabel,
    bool onDarkStrip = false,
    bool onCapsuleSurface = false,
    bool onFloatingStrip = false,
    double diameter = 40,
    double iconSize = 20,
  }) {
    final scale = 0.92 + progress * 0.08;
    final List<BoxShadow> circleShadow;
    if (onCapsuleSurface) {
      circleShadow = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
    } else if (onFloatingStrip) {
      circleShadow = const [];
    } else {
      final shadowColor = onDarkStrip
          ? Colors.black.withValues(alpha: 0.55)
          : Colors.black.withValues(alpha: 0.2);
      circleShadow = [
        BoxShadow(
          color: shadowColor,
          blurRadius: onDarkStrip ? 8 : 6,
          offset: const Offset(0, 2),
        ),
      ];
    }

    final tip = semanticLabel;
    // 不用 InkWell：桌面端易在圆钮外出现矩形焦点/水波纹色块（常被看成多出来的「红/橙方块」）
    Widget circle = Transform.scale(
      scale: scale,
      child: Semantics(
        button: true,
        label: tip,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint,
                boxShadow: circleShadow,
              ),
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
          ),
        ),
      ),
    );
    if (tip != null && tip.isNotEmpty) {
      circle = Tooltip(message: tip, child: circle);
    }
    return circle;
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
