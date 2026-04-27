import 'package:flutter/material.dart';

/// 笔记分类模型
class Category {
  int? id;
  /// WebDAV 同步用稳定标识；新建时由客户端生成
  final String? uuid;
  final String name;
  final int colorValue; // 存储颜色值
  final int createdAt;
  final int updatedAt;
  /// 软删除（同步合并用）
  final bool isDeleted;

  Category({
    this.id,
    this.uuid,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    int? updatedAt,
    this.isDeleted = false,
  }) : updatedAt = updatedAt ?? createdAt;

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
    'uuid': uuid,
    'name': name,
    'colorValue': colorValue,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'isDeleted': isDeleted ? 1 : 0,
  };

  factory Category.fromMap(Map<String, dynamic> map) {
    final rawDel = map['isDeleted'];
    final deleted = rawDel == 1 || rawDel == true;
    return Category(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
      name: (map['name'] as String?) ?? '未分类',
      colorValue: (map['colorValue'] as int?) ?? Colors.grey.value,
      createdAt: (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: (map['updatedAt'] as int?) ?? (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      isDeleted: deleted,
    );
  }

  /// WebDAV `categories.json` 单条记录
  Map<String, dynamic> toSyncJson() {
    return {
      'uuid': uuid,
      'name': name,
      'colorValue': colorValue,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
    };
  }

  static int? _jsonInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory Category.fromSyncJson(Map<String, dynamic> map) {
    final rawDel = map['isDeleted'];
    final deleted = rawDel == 1 || rawDel == true;
    final now = DateTime.now().millisecondsSinceEpoch;
    final created = _jsonInt(map['createdAt']) ?? now;
    final updated = _jsonInt(map['updatedAt']) ?? _jsonInt(map['createdAt']) ?? now;
    return Category(
      uuid: map['uuid'] as String?,
      name: (map['name'] as String?) ?? '未分类',
      colorValue: _jsonInt(map['colorValue']) ?? Colors.grey.value,
      createdAt: created,
      updatedAt: updated,
      isDeleted: deleted,
    );
  }

  Category copyWith({
    int? id,
    String? uuid,
    String? name,
    int? colorValue,
    int? createdAt,
    int? updatedAt,
    bool? isDeleted,
  }) {
    return Category(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
