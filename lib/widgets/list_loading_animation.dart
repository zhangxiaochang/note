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

/// 列表加载动画类型
enum ListAnimationType {
  fade,       // 淡入
  slideUp,    // 从下方滑入
  slideLeft,  // 从左侧滑入
  scale,      // 缩放
  bounce,     // 弹跳
}

/// 列表动画配置
class ListAnimationConfig {
  final ListAnimationType type;
  final Duration duration;
  final Duration delay;
  final double startOpacity;
  final Offset? startOffset;
  final double startScale;
  final double bounceFactor;

  const ListAnimationConfig({
    this.type = ListAnimationType.fade,
    this.duration = const Duration(milliseconds: 600),
    this.delay = const Duration(milliseconds: 100),
    this.startOpacity = 0.0,
    this.startOffset,
    this.startScale = 0.8,
    this.bounceFactor = 1.1,
  });
}

/// 带动画的列表项包装器
class AnimatedListWrapper extends StatefulWidget {
  final Widget child;
  final int index;
  final ListAnimationConfig config;

  const AnimatedListWrapper({
    super.key,
    required this.child,
    required this.index,
    this.config = const ListAnimationConfig(),
  });

  @override
  State<AnimatedListWrapper> createState() => _AnimatedListWrapperState();
}

class _AnimatedListWrapperState extends State<AnimatedListWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  Animation<double>? _scaleAnimation;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.config.duration,
    );

    // 淡入动画
    _fadeAnimation = Tween<double>(
      begin: widget.config.startOpacity,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // 位移动画
    if (widget.config.type == ListAnimationType.slideUp) {
      _slideAnimation = Tween<Offset>(
        begin: widget.config.startOffset ?? const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
    } else if (widget.config.type == ListAnimationType.slideLeft) {
      _slideAnimation = Tween<Offset>(
        begin: widget.config.startOffset ?? const Offset(-0.5, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
    }

    // 缩放动画
    if (widget.config.type == ListAnimationType.scale) {
      _scaleAnimation = Tween<double>(
        begin: widget.config.startScale,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
    } else if (widget.config.type == ListAnimationType.bounce) {
      _scaleAnimation = TweenSequence<double>([
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: widget.config.startScale, end: widget.config.bounceFactor),
          weight: 0.5,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: widget.config.bounceFactor, end: 1.0),
          weight: 0.5,
        ),
      ]).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
    }
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
    // 延迟启动动画，根据索引错开
    final actualDelay = Duration(
      milliseconds: (widget.config.delay.inMilliseconds * widget.index).clamp(0, 2000),
    );

    Future.delayed(actualDelay, () {
      if (mounted) {
        _controller.forward(from: 0.0);
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
    Widget child = FadeTransition(
      opacity: _fadeAnimation,
      child: widget.child,
    );

    if (_slideAnimation != null) {
      child = SlideTransition(
        position: _slideAnimation!,
        child: child,
      );
    }

    if (_scaleAnimation != null) {
      child = ScaleTransition(
        scale: _scaleAnimation!,
        child: child,
      );
    }

    return child;
  }
}

/// 列表动画包装器 - 用于整个列表的动画控制
class ListAnimationWrapper extends StatelessWidget {
  final Widget child;
  final ListAnimationConfig config;

  const ListAnimationWrapper({
    super.key,
    required this.child,
    this.config = const ListAnimationConfig(),
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
