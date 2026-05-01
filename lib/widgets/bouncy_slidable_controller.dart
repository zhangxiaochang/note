import 'package:flutter/animation.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// 覆盖 flutter_slidable 默认的 `ease` 短时动画，恢复类似原先手势实现的 **easeOutBack** 轻微回弹。
class BouncySlidableController extends SlidableController {
  BouncySlidableController(super.vsync);

  static const Duration _snapDuration = Duration(milliseconds: 320);
  static const Curve _snapCurve = Curves.easeOutBack;

  @override
  Future<void> close({
    Duration duration = _snapDuration,
    Curve curve = _snapCurve,
  }) =>
      super.close(duration: duration, curve: curve);

  @override
  Future<void> openCurrentActionPane({
    Duration duration = _snapDuration,
    Curve curve = _snapCurve,
  }) =>
      super.openCurrentActionPane(duration: duration, curve: curve);

  @override
  Future<void> openEndActionPane({
    Duration duration = _snapDuration,
    Curve curve = _snapCurve,
  }) =>
      super.openEndActionPane(duration: duration, curve: curve);

  @override
  Future<void> openStartActionPane({
    Duration duration = _snapDuration,
    Curve curve = _snapCurve,
  }) =>
      super.openStartActionPane(duration: duration, curve: curve);

  @override
  Future<void> openTo(
    double ratio, {
    Duration duration = _snapDuration,
    Curve curve = _snapCurve,
  }) =>
      super.openTo(ratio, duration: duration, curve: curve);

  @override
  Future<void> dismiss(
    ResizeRequest request, {
    Duration duration = _snapDuration,
    Curve curve = _snapCurve,
  }) =>
      super.dismiss(request, duration: duration, curve: curve);
}
