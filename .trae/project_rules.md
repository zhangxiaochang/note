# 笔记应用项目规则

## UI 设计规则

### 设置页面圆角规则

设置页面的列表项圆角必须遵循以下规则：

- **第一项**: 只有顶部有圆角 (topLeft, topRight)
- **中间项**: 无圆角
- **最后一项**: 只有底部有圆角 (bottomLeft, bottomRight)

**实现方式:**
```dart
// 错误示例 - 所有项都有完整圆角
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12), // ❌ 错误
  ),
)

// 正确示例 - 第一项
Container(
  decoration: const BoxDecoration(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(12),
    ),
  ),
)

// 正确示例 - 中间项
Container(
  decoration: const BoxDecoration(
    borderRadius: BorderRadius.zero, // 无圆角
  ),
)

// 正确示例 - 最后一项
Container(
  decoration: const BoxDecoration(
    borderRadius: BorderRadius.only(
      bottomLeft: Radius.circular(12),
      bottomRight: Radius.circular(12),
    ),
  ),
)
```

## 页面修改规则

### 笔记页面和归档页面同步规则

当修改以下文件时，**必须**检查并同步修改对应的另一个文件：

| 修改文件 | 必须检查的文件 | 原因 |
|---------|--------------|------|
| `lib/pages/note/notes_page.dart` | `lib/pages/archive/archive_page.dart` | 两个页面功能对称，UI和逻辑应保持一致 |
| `lib/pages/archive/archive_page.dart` | `lib/pages/note/notes_page.dart` | 两个页面功能对称，UI和逻辑应保持一致 |
| `lib/pages/note/note_card.dart` | 无需检查（通用组件） | 卡片组件被两个页面共用 |
| `lib/pages/note/home_page_body.dart` | 检查归档页面是否使用 | 归档页面可能使用独立的列表实现 |

### 检查清单

修改笔记页面或归档页面时，必须检查以下方面的一致性：

1. **UI 组件**
   - 顶部标题栏样式
   - 分类下拉菜单样式
   - 搜索框样式和行为
   - 刷新按钮
   - 笔记数量显示

2. **功能逻辑**
   - 分类过滤逻辑
   - 搜索过滤逻辑
   - 视图切换（列表/卡片）
   - 下拉菜单选项

3. **交互行为**
   - 点击笔记卡片的行为
   - 长按菜单选项
   - 动画效果

4. **视觉样式**
   - 背景颜色
   - 卡片样式（边框、颜色条）
   - 文字样式
   - 图标样式

### 示例

**场景1**: 修改笔记页面的搜索功能
- 修改 `notes_page.dart` 后
- 必须检查 `archive_page.dart` 是否有相同的搜索功能
- 确保两个页面的搜索行为一致

**场景2**: 修改归档页面的分类显示
- 修改 `archive_page.dart` 后
- 必须检查 `notes_page.dart` 的分类显示是否一致
- 确保两个页面的分类样式和行为一致

### 注意事项

- 归档页面通常以只读模式打开笔记
- 归档页面不允许创建新分类
- 归档页面的笔记操作菜单与笔记页面不同（归档/取消归档）
