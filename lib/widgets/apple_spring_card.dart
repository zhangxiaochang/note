import 'package:flutter/material.dart';

/// Apple 风格弹性卡片入场动画
///
/// 卡片出现时从下方弹出 (spring bounce)，子卡片依次错开。
/// 适用于: 笔记卡片列表、瀑布流卡片、任何需要弹性入场的卡片组。
///
/// 用法:
/// ```dart
/// ListView.builder(
///   itemCount: notes.length,
///   itemBuilder: (context, index) => AppleSpringCard(
///     index: index,
///     child: NoteCard(note: notes[index], ...),
///   ),
/// )
/// ```
class AppleSpringCard extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration staggerDelay;
  final bool animate;

  const AppleSpringCard({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 500),
    this.staggerDelay = const Duration(milliseconds: 60),
    this.animate = true,
  });

  @override
  State<AppleSpringCard> createState() => _AppleSpringCardState();
}

class _AppleSpringCardState extends State<AppleSpringCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late Animation<Offset> _slide;
  bool _started = false;

  // Apple spring: cubic-bezier(0.34, 1.56, 0.64, 1)
  static const Curve _spring = Cubic(0.34, 1.56, 0.64, 1.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.75, curve: _spring),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.75, curve: _spring),
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startAnimation();
    }
  }

  void _startAnimation() {
    final delayMs = (widget.staggerDelay.inMilliseconds * widget.index)
        .clamp(0, 1200);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        if (widget.animate) {
          _controller.forward();
        } else {
          _controller.value = 1.0;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: SlideTransition(
            position: _slide,
            child: Transform.scale(
              scale: 0.92 + (0.08 * _scale.value),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 简化版：直接用 builder 包一层，无需单独 StatefulWidget
///
/// 用于包裹已有子组件，自动处理 index 和延迟。
class AnimatedCardList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Duration duration;
  final Duration staggerDelay;

  const AnimatedCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.duration = const Duration(milliseconds: 500),
    this.staggerDelay = const Duration(milliseconds: 60),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(itemCount, (index) {
        return AppleSpringCard(
          index: index,
          duration: duration,
          staggerDelay: staggerDelay,
          child: itemBuilder(context, index),
        );
      }),
    );
  }
}
