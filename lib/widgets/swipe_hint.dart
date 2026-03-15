import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 右滑操作提示组件
class SwipeHint extends StatefulWidget {
  final String hintText;
  final IconData icon;
  final Duration displayDuration;

  const SwipeHint({
    super.key,
    this.hintText = '右滑笔记可快速归档',
    this.icon = Icons.swipe_right,
    this.displayDuration = const Duration(seconds: 5),
  });

  @override
  State<SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<SwipeHint>
    with SingleTickerProviderStateMixin {
  bool _shouldShow = false;
  bool _isDismissed = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _checkShouldShow();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkShouldShow() async {
    // 暂时禁用 SharedPreferences 检查，方便测试
    // final prefs = await SharedPreferences.getInstance();
    // final hasShown = prefs.getBool('swipe_hint_shown') ?? false;
    
    // 始终显示提示（测试用）
    if (mounted) {
      setState(() {
        _shouldShow = true;
      });
      _animationController.forward();

      // 自动隐藏
      Future.delayed(widget.displayDuration, () {
        if (mounted && !_isDismissed) {
          _dismiss();
        }
      });
    }
  }

  Future<void> _dismiss() async {
    if (_isDismissed) return;
    _isDismissed = true;

    await _animationController.reverse();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('swipe_hint_shown', true);

    if (mounted) {
      setState(() {
        _shouldShow = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              // 动画图标
              _AnimatedSwipeIcon(
                icon: widget.icon,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              // 提示文字
              Expanded(
                child: Text(
                  widget.hintText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                  ),
                ),
              ),
              // 关闭按钮
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _dismiss,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 动画滑动图标
class _AnimatedSwipeIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _AnimatedSwipeIcon({
    required this.icon,
    required this.color,
  });

  @override
  State<_AnimatedSwipeIcon> createState() => _AnimatedSwipeIconState();
}

class _AnimatedSwipeIconState extends State<_AnimatedSwipeIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(
      begin: -5,
      end: 5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: 24,
          ),
        );
      },
    );
  }
}
