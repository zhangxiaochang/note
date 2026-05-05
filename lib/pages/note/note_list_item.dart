import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../domain/category.dart';
import '../../domain/note.dart';
import '../../services/theme_provider.dart';
import '../../widgets/bouncy_slidable_controller.dart';

/// 列表视图中的笔记项：左滑在右侧露出「归档 / （可选）同步 / 删除」（flutter_slidable）。
class NoteListItem extends StatefulWidget {
  final Note note;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback? onSwipeRight;
  final Color? tintColor;
  final VoidCallback? onDelete;
  final IconData? rightSwipeIcon;
  final String? rightSwipeLabel;
  /// 若提供则左滑露出第三枚「同步」按钮（WebDAV 单条同步）。
  final Future<void> Function()? onSingleSync;

  /// 与 [SlidableAutoCloseBehavior] 配合：同组同时只展开一行。
  final Object slidableGroupTag;

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
    this.onSingleSync,
    this.slidableGroupTag = 'note_slidable_default',
  });

  @override
  State<NoteListItem> createState() => NoteListItemState();
}

class NoteListItemState extends State<NoteListItem>
    with TickerProviderStateMixin {
  /// 左滑露出区：左右边距与两钮间距固定像素，露出宽度按此合计，避免随列变宽「只有右边空一大堆」。
  static const double _swipeSideMargin = 12.0;
  static const double _swipeIconGap = 10.0;
  static const double _swipeIconDiameter = 40.0;
  double _swipeRevealPx() {
    final n = widget.onSingleSync != null ? 3 : 2;
    return _swipeSideMargin * 2 +
        _swipeIconDiameter * n +
        _swipeIconGap * (n - 1);
  }

  late final BouncySlidableController _slidableController;
  late AnimationController _deleteController;
  late Animation<double> _deleteHeightAnimation;
  late Animation<double> _deleteFadeAnimation;

  bool _isDeleting = false;

  String get heroTag => 'note_list_${widget.note.uuid}';

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
    _slidableController = BouncySlidableController(this);
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
    _slidableController.dispose();
    _deleteController.dispose();
    super.dispose();
  }

  Future<void> _playSwipeAnimation() async {
    if (_isDeleting) return;
    _isDeleting = true;
    await _deleteController.forward();
  }

  Future<void> _onArchive() async {
    if (widget.onSwipeRight == null) return;
    await _playSwipeAnimation();
    if (!mounted) return;
    widget.onSwipeRight!();
  }

  Future<void> _onDelete() async {
    if (widget.onDelete == null) return;
    await _playSwipeAnimation();
    if (!mounted) return;
    widget.onDelete!();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? ThemeProvider.darkCardColor : ThemeProvider.lightCardColor;

    const archiveCircleColor = Color(0xFF2196F3);
    const syncCircleColor = Color(0xFF26A69A);
    const deleteCircleColor = Color(0xFFEF5350);
    final primaryIcon = widget.rightSwipeIcon ?? Icons.drive_file_move_rtl;

    final card = LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 28;
        final hasContent = widget.note.content.isNotEmpty;
        final categoryColor = widget.category?.color;
        final cardBackgroundColor = categoryColor != null
            ? categoryColor.withOpacity(isDark ? 0.15 : 0.08)
            : cardColor;

        final showContent = hasContent && availableWidth > 280;
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
                      Text(
                        widget.note.title.isEmpty ? '无标题' : widget.note.title,
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
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
                          const SizedBox(width: 5),
                          _getSyncStatusIcon(),
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
    );

    return LayoutBuilder(
      builder: (context, itemConstraints) {
        final itemW = itemConstraints.maxWidth;
        // 露出比例 = 固定像素总长 / 当前项宽度；尽量不设过高的下限，以免宽列多出一块-only-right 空白
        final extentRatio = itemW > 0
            ? (_swipeRevealPx() / itemW).clamp(0.07, 0.82)
            : 0.36;

        final content = Slidable(
          key: ValueKey('slidable_${widget.note.uuid}'),
          controller: _slidableController,
          groupTag: widget.slidableGroupTag,
          closeOnScroll: true,
          dragStartBehavior: DragStartBehavior.start,
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: extentRatio,
            children: [
              CustomSlidableAction(
                flex: 1,
                autoClose: false,
                onPressed: (_) {},
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                // 必须贴右端：居中会让左侧大块空白先露出，归档钮被前景盖住。（CustomSlidableAction 仅接受 Alignment）
                alignment: Alignment.centerRight,
                child: Builder(
                  builder: (ctx) {
                    final slidable = Slidable.of(ctx);
                    if (slidable == null) return const SizedBox.shrink();
                    return AnimatedBuilder(
                      animation: slidable.animation,
                      builder: (context, __) {
                        final pane = ActionPane.of(context);
                        final er = pane?.extentRatio ?? extentRatio;
                        final t = (slidable.animation.value / er).clamp(0.0, 1.0);
                        final scale = 0.92 + t * 0.08;
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _swipeSideMargin,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _slidableCircle(
                                  scale: scale,
                                  icon: primaryIcon,
                                  color: archiveCircleColor,
                                  semanticLabel: widget.rightSwipeLabel ?? '归档',
                                  tooltip: widget.rightSwipeLabel ?? '归档',
                                  onTap: () async {
                                    await slidable.close();
                                    if (!mounted) return;
                                    await _onArchive();
                                  },
                                ),
                                if (widget.onSingleSync != null) ...[
                                  const SizedBox(width: _swipeIconGap),
                                  _slidableCircle(
                                    scale: scale,
                                    icon: Icons.cloud_sync_rounded,
                                    color: syncCircleColor,
                                    semanticLabel: '同步',
                                    tooltip: '同步到云端',
                                    onTap: () async {
                                      await slidable.close();
                                      if (!mounted) return;
                                      await widget.onSingleSync!.call();
                                    },
                                  ),
                                ],
                                const SizedBox(width: _swipeIconGap),
                                _slidableCircle(
                                  scale: scale,
                                  icon: Icons.delete_outline_rounded,
                                  color: deleteCircleColor,
                                  semanticLabel: '删除',
                                  tooltip: '删除',
                                  onTap: () async {
                                    await slidable.close();
                                    if (!mounted) return;
                                    await _onDelete();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          child: card,
        );

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
      },
    );
  }

  Widget _slidableCircle({
    required double scale,
    required IconData icon,
    required Color color,
    required String semanticLabel,
    required String tooltip,
    required Future<void> Function() onTap,
  }) {
    return Transform.scale(
      scale: scale,
      alignment: Alignment.center,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Tooltip(
          message: tooltip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final isThisYear = date.year == now.year;

    if (isThisYear) {
      return '${date.month}月${date.day}日';
    }
    return '${date.year}年${date.month}月${date.day}日';
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
