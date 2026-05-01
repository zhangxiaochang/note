import 'package:flutter/material.dart';

/// Apple 风格弹性折叠面板
///
/// 展开时子元素依次弹性弹入 (spring bounce)，收起时平滑过渡。
/// 适用于: 分类折叠、设置项展开、FAQ 手风琴。
///
/// 用法:
/// ```dart
/// AppleSpringFold(
///   header: Text('分类'),
///   initiallyExpanded: false,
///   children: [
///     ListTile(title: Text('笔记1')),
///     ListTile(title: Text('笔记2')),
///   ],
/// )
/// ```
class AppleSpringFold extends StatefulWidget {
  final Widget header;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Duration duration;
  final Duration staggerDelay;
  final VoidCallback? onToggle;

  const AppleSpringFold({
    super.key,
    required this.header,
    required this.children,
    this.initiallyExpanded = false,
    this.duration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 50),
    this.onToggle,
  });

  @override
  State<AppleSpringFold> createState() => _AppleSpringFoldState();
}

class _AppleSpringFoldState extends State<AppleSpringFold>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeFactor;
  bool _isExpanded = false;

  // Apple spring curve: CSS cubic-bezier(0.34, 1.56, 0.64, 1)
  static const Curve _appleSpring = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Curve _collapseCurve = Cubic(0.25, 0.1, 0.25, 1.0);

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: _isExpanded ? 1.0 : 0.0,
    );
    _sizeFactor = CurvedAnimation(
      parent: _controller,
      curve: _appleSpring,
      reverseCurve: _collapseCurve,
    );
  }

  void toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    widget.onToggle?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: toggle,
          behavior: HitTestBehavior.opaque,
          child: widget.header,
        ),
        SizeTransition(
          sizeFactor: _sizeFactor,
          axisAlignment: -1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildAnimatedChildren(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAnimatedChildren() {
    return List.generate(widget.children.length, (index) {
      // 每个子元素有独立的弹性入场动画
      return _SpringChild(
        controller: _controller,
        index: index,
        staggerDelay: widget.staggerDelay,
        springCurve: _appleSpring,
        isExpanded: _isExpanded,
        child: widget.children[index],
      );
    });
  }
}

/// 单个子元素的弹性入场动画
class _SpringChild extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Duration staggerDelay;
  final Curve springCurve;
  final bool isExpanded;
  final Widget child;

  const _SpringChild({
    required this.controller,
    required this.index,
    required this.staggerDelay,
    required this.springCurve,
    required this.isExpanded,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 错开每个子元素的动画时间窗口
    final totalMs = controller.duration?.inMilliseconds ?? 400;
    final staggerMs = staggerDelay.inMilliseconds * index;
    final start = (staggerMs / totalMs).clamp(0.0, 0.8);
    final end = (start + 0.25).clamp(0.0, 1.0);

    final childAnimation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: springCurve),
    );

    return AnimatedBuilder(
      animation: childAnimation,
      builder: (context, child) {
        final t = childAnimation.value;
        // 从 0.85 缩放到 1.0 + 弹性回弹
        final scale = 0.85 + (0.15 * t);
        // 从下方 8px 滑入
        final translateY = (1.0 - t) * 8.0;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
