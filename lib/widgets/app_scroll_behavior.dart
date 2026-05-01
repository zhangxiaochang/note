import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 全局滚动：桌面端轻回弹（BouncingScrollPhysics），列表/滚轮边界不再死硬；
/// 统一滚动条粗细与圆角。移动端保持系统默认物理。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return super.getScrollPhysics(context);
      default:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
    }
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(
      controller: details.controller,
      thickness: 6,
      radius: const Radius.circular(8),
      child: child,
    );
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

/// 笔记/归档列表专用：桌面端 **不把鼠标拖动** 算作纵向滚动（请用滚轮），否则与行内 [Slidable] 横向手势抢竞技场。
/// 触控笔、触控板、触摸屏拖动滚动仍可用。
class NoteListScrollBehavior extends AppScrollBehavior {
  const NoteListScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return super.getScrollPhysics(context);
      default:
        return const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
    }
  }
}
