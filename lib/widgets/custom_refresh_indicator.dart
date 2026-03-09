import 'package:flutter/material.dart';

/// 自定义刷新指示器 - 带有渐变色的刷新动画
class CustomRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const CustomRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<CustomRefreshIndicator> createState() => _CustomRefreshIndicatorState();
}

class _CustomRefreshIndicatorState extends State<CustomRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    _controller.repeat();
    await widget.onRefresh();
    _controller.stop();
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).cardColor,
      strokeWidth: 3,
      displacement: 50,
      edgeOffset: 20,
      child: widget.child,
    );
  }
}

/// 渐变进度指示器
class GradientProgressIndicator extends StatelessWidget {
  final Animation<double> animation;
  final Color primaryColor;

  const GradientProgressIndicator({
    super.key,
    required this.animation,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                primaryColor.withOpacity(0.1),
                primaryColor.withOpacity(0.3),
                primaryColor.withOpacity(0.6),
                primaryColor,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
              transform: GradientRotation(animation.value * 2 * 3.14159),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: CircularProgressIndicator(
              value: null,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
        );
      },
    );
  }
}
