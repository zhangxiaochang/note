import 'package:flutter/material.dart';

import '../services/theme_provider.dart';

/// 苹果官网风提示卡片：大白 / 深空灰、圆角 22、极淡阴影、无描边；无悬停动画，避免与弹出过程打架。
class AppleToastCard extends StatelessWidget {
  const AppleToastCard({
    super.key,
    required this.message,
    required this.icon,
    required this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final Color iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const double radius = 22;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? ThemeProvider.darkCardColor : Colors.white;
    final primaryText =
        isDark ? ThemeProvider.darkTextColor : ThemeProvider.lightTextColor;
    final shadow = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
        blurRadius: 24,
        offset: const Offset(0, 8),
        spreadRadius: -4,
      ),
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: iconColor),
            const SizedBox(width: 28),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily:
                      Theme.of(context).textTheme.bodyLarge?.fontFamily ?? 'PingFang SC',
                  fontSize: 15,
                  height: 1.35,
                  letterSpacing: -0.24,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 20),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: ThemeProvider.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontFamily:
                        Theme.of(context).textTheme.bodyLarge?.fontFamily ?? 'PingFang SC',
                    fontSize: 15,
                    letterSpacing: -0.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 语义色（图标）：贴近 iOS 系统色，无多余装饰线。
abstract final class AppleToastColors {
  static const success = Color(0xFF34C759);
  static const info = Color(0xFF007AFF);
  static const warning = Color(0xFFFF9500);
  static const destructive = Color(0xFFFF3B30);
  static const archive = Color(0xFFFF9500);
}

/// 用 Overlay + 淡入淡出展示卡片，避免 SnackBar 默认滑入造成的「飞来飞去」感。
class AppleToastMessenger {
  AppleToastMessenger._();

  static OverlayEntry? _active;

  static void show(
    BuildContext context, {
    required Widget child,
    Duration displayDuration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _active?.remove();
    _active = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _AppleToastFadeShell(
        displayDuration: displayDuration,
        onFinished: () {
          entry.remove();
          if (_active == entry) _active = null;
        },
        child: child,
      ),
    );
    _active = entry;
    overlay.insert(entry);
  }
}

class _AppleToastFadeShell extends StatefulWidget {
  const _AppleToastFadeShell({
    required this.child,
    required this.displayDuration,
    required this.onFinished,
  });

  final Widget child;
  final Duration displayDuration;
  final VoidCallback onFinished;

  @override
  State<_AppleToastFadeShell> createState() => _AppleToastFadeShellState();
}

class _AppleToastFadeShellState extends State<_AppleToastFadeShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _play();
  }

  Future<void> _play() async {
    await _controller.forward();
    if (!mounted) return;
    await Future<void>.delayed(widget.displayDuration);
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 16;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
