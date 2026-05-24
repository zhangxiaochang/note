# Benny 同步模块说明（`lib/sync`）

本文档说明项目中 **WebDAV 笔记同步** 相关目录结构、各文件职责、调用关系与主流程逻辑。路径以仓库根 `e:\project\note` 为基准。

---

## 1. 总览：分层与数据流

```
┌─────────────────────────────────────────────────────────────┐
│  UI / 入口                                                    │
│  · lib/pages/sync/sync_progress_page.dart（全量同步页）      │
│  · lib/pages/settings/settings_page.dart、notes_page.dart     │
│  · lib/utils/note_single_sync.dart（列表单条同步）           │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  AsyncSyncService（异步封装 + 进度流 + 会话日志）             │
│  lib/sync/services/async_sync_service.dart                   │
└───────────────┬─────────────────────────┬───────────────────┘
                │                         │
                ▼                         ▼
    ┌───────────────────────┐   ┌──────────────────────┐
    │ Synchronizer          │   │ SingleNoteSync       │
    │ 全库增量合并           │   │ 单条 LWW + 冲突 UI   │
    └───────────┬───────────┘   └──────────┬───────────┘
                │                           │
                └───────────┬───────────────┘
                            ▼
                ┌───────────────────────┐
                │ SyncClientBase        │
                │ → WebdavClient        │
                └───────────────────────┘
                            │
                            ▼
              WebDAV：`benny/data/notes/.../*.json`
                    `benny/data/images/...`
                    `benny/data/categories/categories.json`
```

- **传输协议**：当前实现为 **WebDAV**（`WebdavClient` 实现 `SyncClientBase`）。
- **笔记**：每条一个 JSON（`Note.toSyncWireJsonMap()`），按 UUID 分片目录存放。
- **图片**：正文 Quill Delta 中的相对路径对应 `benny/data/images/` 下文件。
- **分类**：独立 JSON 索引，与笔记里的 `categoryUuid` 对齐。

---

## 2. 两种入口：批量 vs 单条


| 入口              | 文件                                      | 行为                                                                                     |
| --------------- | --------------------------------------- | -------------------------------------------------------------------------------------- |
| **批量 / 全量增量同步** | `AsyncSyncService.startBatchSync()`     | 内部创建 `Synchronizer`，跑完整轮：分类 → 列远端索引 → 本地/远端笔记配对 → 新笔记拉取 → 写 `sync_meta` / `sync_items` |
| **单条笔记同步**      | `AsyncSyncService.syncSingleNote(uuid)` | 仅 `SingleNoteSync.syncNote`，不跑整库索引循环                                                   |


**谁调用 `AsyncSyncService`**

- `lib/pages/sync/sync_progress_page.dart`：创建 `WebdavClient` → `AsyncSyncService`，用户点「开始同步」→ `startBatchSync()`；进度用 `progressStream`。
- `lib/utils/note_single_sync.dart`：`NoteSingleSyncRunner.run()` → `syncSingleNote()`（笔记列表/卡片的「同步」按钮）。

**另一条不经过 `AsyncSyncService` 的路径**

- `lib/sync/services/sync_service.dart`：直接 `Synchronizer(_client).run()`，无进度控制器、无 `SyncLogWriter` 包裹。
- 被 `lib/sync/providers/sync_provider.dart` 的 `SyncNotifier` / `syncServiceProvider` 使用（Riverpod）。
- `lib/sync/utils/sync_scheduler.dart` 内部持有 `SyncService?`，但 **工程内暂无其它文件引用 `SyncScheduler`**，可视作预留或旧架构残留。

---

## 3. 核心类：`Synchronizer` 在做什么

**文件**：`lib/sync/services/synchronizer.dart`

**调用方**：`AsyncSyncService._performBatchSync`、`SyncService.sync`。

**大致顺序**（`run()`）：

1. `ping`、确保远端根目录（委托 `SingleNoteSync.ensureRemoteRoots`）。
2. `**CategorySyncService.sync`**：拉/推 `categories.json`，与本地分类表按 `uuid` + `updatedAt` 合并。
3. `**RemoteIndexBuilder.build`**：列举 `benny/data/notes/**.json` 与图片目录等，得到 `Map<uuid, RemoteNoteInfo>`。
4. `**_syncChangedNotes**`（三轮逻辑，与 `sync_planner` 计数一致）：
  - **轮 1**：远端索引 **没有** 该 UUID → 对每条本地笔记（**含已逻辑删除**）调用 `SingleNoteSync.syncNote`，用于 **新建上传** 或 **墓碑上传**。
  - **轮 2**：远端 **有** 该 UUID → 下载远端 JSON，先处理 **删除冲突**（`_resolveDeleteConflict`：远端墓碑 vs 本机时间），再决定上传/下载或仅应用远端墓碑（`_applyRemoteTombstone`）；否则按 `sync_items` + 内容哈希判断是否需要 `syncNote(..., preloadedRemote, forceSync: true)`。
  - **轮 3**：远端有、本地 **没有** 这条 → `_downloadNewNote` 插入本地（远端已是墓碑则跳过）。
5. `**_updateGlobalSyncState`**：更新全局 `sync_meta`。

**依赖**：内部持有一个 `SingleNoteSync` 实例，用于 `syncNote`、规范化图片路径、建远端目录等。

---

## 4. 核心类：`SingleNoteSync` 在做什么

**文件**：`lib/sync/services/single_note_sync.dart`

**职责**：

- 单条 `**syncNote(uuid)`**：判断 `_needsSync`（结合 `SyncItemDao` + 笔记 `syncStatus` + 远端文件是否存在）。
- **无冲突**：`_syncNote` —— 比较本地与远端 `updatedAt`：较新一侧 **上传/下载**；时间戳相同则比 **内容哈希**（`note_sync_hash`）。
- **有冲突**：`_detectConflict`（哈希不一致）→ `_handleConflict` → `ConflictResolver`（可弹 `AlertDialog`；无 `context` 时默认 `useLocal`）。
- **上传**：`ensureNoteHasCategoryUuidForUpload`、`normalizeNoteImageRefs`、`toSyncWireJsonMap()` → WebDAV PUT 字符串。
- **下载**：`mergeRemoteDownloadWithLocal`（与本地合并归档/删除语义）→ `resolveWireNoteForDb`（`categoryUuid` → 本地 `categoryId`）→ 更新 DB → 拉图片。
- **图片**：`syncNoteImages` / `_downloadNoteImages` 等与 `benny/data/images/` 交互。

**调用方**：`Synchronizer`、`AsyncSyncService`；`Synchronizer` 的 `_downloadNewNote` 也会用其 `normalizeNoteImageRefs`、`downloadNoteImages`。

---

## 5. `lib/sync` 下文件一览（职责 + 谁用）

### 5.1 `services/`（运行时服务）


| 文件                           | 职责                                                | 主要调用方                                                                  |
| ---------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------- |
| `sync_client_base.dart`      | 抽象同步客户端（ping、目录、上传下载字符串/文件等）                      | `WebdavClient`、所有 Service                                              |
| `webdav_client.dart`         | 基于 `webdav_client` 包的具体实现                         | `WebDAVConfigService`、`sync_progress_page`、`sync_provider`             |
| `synchronizer.dart`          | 全库增量同步编排                                          | `AsyncSyncService`、`SyncService`                                       |
| `single_note_sync.dart`      | 单条笔记同步、图片、冲突入口                                    | `Synchronizer`、`AsyncSyncService`                                      |
| `async_sync_service.dart`    | 批量/单条异步封装、进度流、`SyncLogWriter`、`SyncSessionMarker` | `sync_progress_page`、`note_single_sync`                                |
| `sync_service.dart`          | 薄封装：直接跑 `Synchronizer`（无日志/进度）                    | `sync_provider`、`sync_scheduler`（仅内部）                                  |
| `category_sync_service.dart` | 远端 `categories.json` 与本地分类合并                      | `Synchronizer`、`RemoteIndexBuilder`、`SingleNoteSync.ensureRemoteRoots` |
| `remote_index_builder.dart`  | 列举远端笔记/图片/分类索引路径 → `RemoteIndex`                  | `Synchronizer`                                                         |
| `incremental_sync.dart`      | 兼容旧类名，内部委托 `Synchronizer`                         | 可被旧代码 import（当前仓库内 grep 以 `Synchronizer` 为主）                           |
| `sync_log_writer.dart`       | 把批量/单条同步结果写入表 `sync_log`                          | `AsyncSyncService`、`SyncSessionRecovery`                               |
| `sync_session_marker.dart`   | SharedPreferences 记录「同步进行中」，防进程被杀无痕迹              | `AsyncSyncService`、`SyncSessionRecovery`                               |
| `sync_session_recovery.dart` | 冷启动补写「上次同步未正常结束」日志                                | `main.dart`                                                            |
| `sync_ui_prefs.dart`         | 同步成功后写少量 UI 偏好（如上次条数）                             | `AsyncSyncService`                                                     |


### 5.2 `utils/`（纯逻辑 / 小工具）


| 文件                            | 职责                                                                                                      | 主要调用方                                            |
| ----------------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| `note_sync_hash.dart`         | `noteSyncContentHash`：笔记同步用内容指纹（含 `archived`/`isDeleted` 等）                                             | `SingleNoteSync`、`Synchronizer`、`SyncItemDao`    |
| `note_download_merge.dart`    | 下载时与本地合并；本机上传胜出时合并 `archived`                                                                           | `SingleNoteSync`                                 |
| `note_wire_resolve.dart`      | 上传前补 `categoryUuid`；下载后 `categoryUuid` → 本地 `categoryId`                                                | `SingleNoteSync`、`Synchronizer._downloadNewNote` |
| `conflict_resolver.dart`      | 冲突详情、弹窗、`resolveConflict`/`_mergeNotes`（与 `SingleNoteSync` 内 `ConflictResolution` 枚举重名但不同文件——笔记级冲突用本文件） | `SingleNoteSync`                                 |
| `sync_planner.dart`           | `plannedSyncOperationCount`：估算与 `Synchronizer` 循环一致的进度总数                                                | `Synchronizer.run`（设置进度条 total）                  |
| `sync_conflict_resolver.dart` | 基于 **文件** mtime 的冲突策略（`RemoteFile`）                                                                     | `conflict_resolution_dialog.dart`（偏旧/备用 UI）      |
| `sync_scheduler.dart`         | 定时触发 `SyncService.sync`                                                                                 | **当前仓库无外部引用**                                    |


### 5.3 `models/`（数据结构）


| 文件                                            | 职责                                                        |
| --------------------------------------------- | --------------------------------------------------------- |
| `sync_state.dart` + `sync_state.freezed.dart` | 同步状态不可变模型（freezed 生成）                                     |
| `sync_progress.dart`                          | `SyncProgress`、`SyncPhase`、`SyncProgressController`（广播进度） |
| `remote_index.dart`                           | 一次远端列举结果容器                                                |
| `remote_note_info.dart`                       | 单条远端笔记 JSON 的路径 + mtime                                   |
| `remote_file.dart`                            | WebDAV 文件/目录项元数据                                          |
| `sync_item_vocabulary.dart`                   | `sync_items` 表用的 item 类型与状态字符串常量                          |


### 5.4 `providers/`、`pages/`（UI 与状态）


| 文件                                      | 职责                                 | 调用关系                                                  |
| --------------------------------------- | ---------------------------------- | ----------------------------------------------------- |
| `providers/sync_provider.dart`          | Riverpod：`SyncService`、手动 `sync()` | 若路由/设置页接入 Provider 则使用                                |
| `pages/sync_settings_page.dart`         | 同步方向等设置 UI（依赖 `sync_provider`）     | **当前仓库无路由引用**，可预留                                     |
| `pages/conflict_resolution_dialog.dart` | 专用冲突对话框 UI                         | **当前仓库无引用**；实际冲突在 `ConflictResolver` 内联 `AlertDialog` |


### 5.5 不在 `lib/sync` 但与同步强相关


| 文件                                        | 职责                                                                 |
| ----------------------------------------- | ------------------------------------------------------------------ |
| `lib/pages/sync/sync_progress_page.dart`  | 全量同步 UI + 启动 `AsyncSyncService`                                    |
| `lib/services/webdav_config_service.dart` | 读存配置、创建 `WebdavClient`                                             |
| `lib/utils/note_single_sync.dart`         | 从列表触发单条同步                                                          |
| `lib/dao/sync_item_dao.dart`              | `sync_items`：dirty/clean、内容哈希、与 `Synchronizer`/`SingleNoteSync` 配合 |
| `lib/dao/sync_log_dao.dart`               | `sync_log` 表 CRUD                                                  |
| `lib/dao/db.dart`                         | 笔记 `update`/`archiveNote`/`delete` 等会 `markNoteDirty`              |


---

## 6. 主流程简图（批量）

```
main → SyncSessionRecovery（补写异常中断日志）
用户打开同步页 → WebdavClient + AsyncSyncService
用户点击开始 → startBatchSync
  → SyncSessionMarker.markBatchPending
  → Synchronizer.run
       → CategorySyncService.sync
       → RemoteIndexBuilder.build
       → _syncChangedNotes（三轮）
       → _updateGlobalSyncState
  → SyncLogWriter.appendBatch
  → SyncSessionMarker.clearBatchPending
```

---

## 7. 扩展阅读（代码内注释）

- **墓碑删除**：远端 `isDeleted` 与 `_resolveDeleteConflict`、`_applyRemoteTombstone`。
- **归档**：`note_download_merge`、`mergeArchivedWhenLocalUploadWins`（上传侧保留他端已归档）、`note_sync_hash` 含 `archived`。
- **分类占位**：`note_wire_resolve.dart` 对未知 `categoryUuid` 建占位分类，避免合并时被旧数据覆盖。

---

*文档随代码演进可能需更新；若新增入口，请在本文件「谁调用」表中补充。*