import 'package:flutter/material.dart';

/// 动画限制器
/// 用于控制子动画的播放，避免重复动画
class AnimationLimiter extends InheritedWidget {
  final bool animate;

  const AnimationLimiter({
    super.key,
    required this.animate,
    required super.child,
  });

  static bool shouldAnimate(BuildContext context) {
    final limiter = context.dependOnInheritedWidgetOfExactType<AnimationLimiter>();
    return limiter?.animate ?? true;
  }

  @override
  bool updateShouldNotify(AnimationLimiter oldWidget) {
    return animate != oldWidget.animate;
  }
}

/// 带动画的列表项包装器
/// 支持淡入和位移动画
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration delay;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 800),
    this.delay = const Duration(milliseconds: 180),
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // 淡入动画 - 从半透明开始，更自然
    _fadeAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // 位移动画 - 从下方小距离滑入，更 subtle
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animationStarted) {
      _animationStarted = true;
      _startAnimation();
    }
  }

  void _startAnimation() {
    // 检查是否应该播放动画
    final shouldAnimate = AnimationLimiter.shouldAnimate(context);

    // 延迟启动动画，根据索引错开，但限制最大延迟
    final actualDelay = Duration(
      milliseconds: (widget.delay.inMilliseconds * widget.index).clamp(0, 1500),
    );

    Future.delayed(actualDelay, () {
      if (mounted) {
        if (shouldAnimate) {
          _controller.forward(from: 0.0);
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// 带动画的网格项包装器
class AnimatedGridItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration delay;

  const AnimatedGridItem({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 800),
    this.delay = const Duration(milliseconds: 180),
  });

  @override
  State<AnimatedGridItem> createState() => _AnimatedGridItemState();
}

class _AnimatedGridItemState extends State<AnimatedGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // 淡入动画 - 从半透明开始
    _fadeAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // 缩放动画 - 从 0.95 缩放到 1.0，更 subtle
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animationStarted) {
      _animationStarted = true;
      _startAnimation();
    }
  }

  void _startAnimation() {
    // 检查是否应该播放动画
    final shouldAnimate = AnimationLimiter.shouldAnimate(context);

    // 延迟启动动画，限制最大延迟
    final actualDelay = Duration(
      milliseconds: (widget.delay.inMilliseconds * widget.index).clamp(0, 1500),
    );

    Future.delayed(actualDelay, () {
      if (mounted) {
        if (shouldAnimate) {
          _controller.forward(from: 0.0);
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
