# Repository Guidelines

## 项目结构与模块组织
这是一个 Flutter 多端笔记应用，支持 Android、iOS、macOS 和 Windows。主要代码位于 `lib/`。

- `lib/main.dart`：应用入口、主题初始化
- `lib/dao/`：SQLite 访问与数据库升级逻辑
- `lib/domain/`：核心数据模型，如笔记、分类
- `lib/pages/`：页面与界面逻辑，包含首页、编辑、归档、设置等
- `lib/services/`：主题、备份、配置等服务
- `lib/sync/`：WebDAV 同步、冲突处理、同步状态管理
- `android/`、`ios/`、`macos/`、`windows/`：各平台工程

`build/`、`.dart_tool/` 等生成目录不要手动修改。

## 构建、测试与开发命令
在仓库根目录执行 Flutter 命令：

- `flutter pub get`：安装依赖
- `flutter run -d windows`：在 Windows 本地运行
- `flutter run -d android`：在 Android 设备或模拟器运行
- `flutter analyze`：执行静态检查
- `flutter test`：运行测试
- `flutter build windows`：构建 Windows 版本

## 代码风格与命名规范
遵循 Dart / Flutter 默认风格，使用 2 空格缩进。文件名使用 `snake_case.dart`，类名使用 `PascalCase`，变量和方法使用 `camelCase`。

界面、数据库、同步逻辑按目录分层，不要把大量业务逻辑直接堆在页面文件中。提交前建议运行 `dart format lib`。静态规则来自 `analysis_options.yaml`，基于 `flutter_lints`。

## 测试规范
当前仓库还没有 `test/` 目录；新增测试时请放在 `test/` 下，并使用 `*_test.dart` 命名，例如 `test/dao/db_test.dart`、`test/sync/sync_service_test.dart`。

涉及数据库、同步、编辑器行为修改时，优先补回归测试。提交前至少运行 `flutter analyze`；如果已添加测试，再运行 `flutter test`。

## 提交与 Pull Request 规范
现有提交历史以简短中文为主，例如 `feat 权限优化`、`feat 易用性优化`。保持提交信息简洁明确，推荐前缀：`feat`、`fix`、`refactor`、`docs`。

PR 建议包含：

- 变更摘要，说明用户可见影响
- 关联任务或问题编号
- UI 改动的截图或录屏
- 是否影响数据库迁移、同步逻辑或平台兼容性

## 配置与风险说明
本项目核心风险点在本地数据库和 WebDAV 同步。修改 `lib/dao/`、`lib/services/`、`lib/sync/` 下的代码时，应明确说明迁移影响、同步冲突风险，以及是否验证过真实数据路径而不只是界面流程。
