// editable_app_bar_title.dart
import 'package:flutter/material.dart';

class EditableAppBarTitle extends StatefulWidget implements PreferredSizeWidget {
  final TextEditingController controller;
  final String hintText;

  const EditableAppBarTitle({
    super.key,
    required this.controller,
    required this.hintText,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<EditableAppBarTitle> createState() => _EditableAppBarTitleState();
}

class _EditableAppBarTitleState extends State<EditableAppBarTitle> {
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() {
          _isEditing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _startEditing,
      child: _isEditing
          ? TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) {
          setState(() {
            _isEditing = false;
          });
        },
      )
          : Row(
        children: [
          Expanded(
            child: Text(
              widget.controller.text.isEmpty ? widget.hintText : widget.controller.text,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}