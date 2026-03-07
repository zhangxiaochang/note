import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../pages/editor/edit_page.dart';
import '../domain/note.dart';

/// iOS 风格的从右侧推入动画
Route<bool> editPageRoute(
  Note? note, {
  bool readOnly = false,
  Rect? cardRect,
  String? heroTag,
}) {
  return CupertinoPageRoute<bool>(
    builder: (context) {
      return EditPage(
        note: note,
        readOnly: readOnly,
        heroTag: heroTag ?? 'note_${note?.id ?? 'new'}',
      );
    },
  );
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
