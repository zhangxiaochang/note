import 'package:flutter/material.dart';

/// 笔记分类模型
class Category {
  int? id;
  final String name;
  final int colorValue; // 存储颜色值
  final int createdAt;

  Category({
    this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });

  /// 获取颜色
  Color get color => Color(colorValue);

  /// 预设颜色列表（7个清淡的彩虹色）
  static final List<Color> presetColors = [
    const Color(0xFFFFA7A7), // 浅红
    const Color(0xFFFFD6A5), // 浅橙
    const Color(0xFFFFFD9E), // 浅黄
    const Color(0xFFCAFFBF), // 浅绿
    const Color(0xFF9BF6FF), // 浅青
    const Color(0xFFA0C4FF), // 浅蓝
    const Color(0xFFBDB2FF), // 浅紫
  ];

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'createdAt': createdAt,
  };

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '未分类',
      colorValue: (map['colorValue'] as int?) ?? Colors.grey.value,
      createdAt: (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    int? colorValue,
    int? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
