import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../dao/db.dart';
import '../../services/webdav_config_service.dart';
import '../../sync/models/sync_progress.dart';
import '../../sync/services/async_sync_service.dart';
import '../../sync/services/sync_ui_prefs.dart';
import '../../sync/services/webdav_client.dart';
import '../../utils/quill_image_paths.dart';

/// 同步进度页面
///
/// 默认 **不自动同步**：进入后可看上次摘要，需要时点击「开始同步」。
/// 若希望进入即拉取（例如快捷入口），传入 `autoStart: true`。
class SyncProgressPage extends StatefulWidget {
  const SyncProgressPage({
    super.key,
    this.autoStart = false,
  });

  final bool autoStart;

  @override
  State<SyncProgressPage> createState() => _SyncProgressPageState();
}

class _SyncProgressPageState extends State<SyncProgressPage>
    with TickerProviderStateMixin {
  AsyncSyncService? _syncService;
  late AnimationController _progressAnimationController;
  String? _errorMessage;
  SyncUiLastSession? _lastSession;
  bool _awaitingManualStart = false;

  /// 本机活跃笔记条数（进入页面时统计，同步完成后会刷新）
  int? _localNoteCount;
  /// 正文中引用的本地图片路径去重数量（不含网络图）
  int? _localImageCount;
  bool _localStatsLoading = true;
  bool _refreshedLocalStatsAfterSync = false;

  @override
  void initState() {
    super.initState();

    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    SyncUiPrefs.loadLastSession().then((s) {
      if (mounted) setState(() => _lastSession = s);
    });

    _refreshLocalStats();
    _initSyncService();
  }

  Future<void> _refreshLocalStats() async {
    try {
      // 与 [IncrementalSync._getLocalNotesToSync] 一致：queryAll = 未删除（含已归档），
      // 避免「上次同步摘要」与本机概要数字对不上。
      final notes = await DB.instance.queryAll();
      final img = countDistinctLocalImageRefs(notes);
      if (!mounted) return;
      setState(() {
        _localNoteCount = notes.length;
        _localImageCount = img;
        _localStatsLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _localStatsLoading = false);
      }
    }
  }

  void _initSyncService() async {
    try {
      // 加载 WebDAV 配置
      final config = await WebDAVConfigService.loadConfig();
      if (!mounted) return;
      if (!config.isValid) {
        setState(() {
          _errorMessage = 'WebDAV 配置无效，请先配置同步设置';
        });
        return;
      }

      // 创建 WebDAV 客户端
      final client = WebdavClient(
        url: config.url,
        username: config.username,
        password: config.password,
      );

      final service = AsyncSyncService(client);
      if (!mounted) return;
      service.setContext(context);
      setState(() {
        _syncService = service;
        _awaitingManualStart = !widget.autoStart;
      });

      if (widget.autoStart) {
        await service.startBatchSync();
      }
    } catch (e) {
      setState(() {
        _errorMessage = '初始化同步服务失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _syncService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 如果有错误，显示错误页面
    if (_errorMessage != null) {
      return _buildErrorPage();
    }

    // 等待同步服务初始化
    if (_syncService == null) {
      return _buildLoadingPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF), // 背景色
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF312E81)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '同步进度',
          style: TextStyle(
            color: Color(0xFF312E81),
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              '手机与电脑请配置同一 WebDAV；「本设备」指当前这台 ${_platformKindName()}。\n'
              '笔记以 JSON 同步，图片单独上传并与正文关联。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<SyncProgress>(
        stream: _syncService!.progressStream,
        initialData: _syncService!.currentProgress,
        builder: (context, snapshot) {
          final progress = snapshot.data!;

          _progressAnimationController.animateTo(
            (progress.percentage / 100).clamp(0.0, 1.0),
            duration: const Duration(milliseconds: 320),
          );

          if (progress.isCompleted && !_refreshedLocalStatsAfterSync) {
            _refreshedLocalStatsAfterSync = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _refreshLocalStats();
            });
          } else if (progress.isRunning) {
            _refreshedLocalStatsAfterSync = false;
          }

          final padH = _syncPageHorizontalPadding(context);

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padH, 8, padH, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        scrollbars: false,
                      ),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_lastSession != null) ...[
                              _buildLastSessionBanner(_lastSession!),
                              SizedBox(height: _syncPageSectionGap(context)),
                            ],
                            _buildMultiDeviceHint(),
                            SizedBox(height: _syncPageSectionGap(context)),
                            _buildLocalLibraryStats(),
                            SizedBox(height: _syncPageSectionGap(context) + 4),

                            // 条形进度 + 实时本机/云端（避免圆环遮挡文字）
                            _buildProgressSection(progress),

                            SizedBox(height: _syncPageSectionGap(context) + 8),

                            // 状态信息
                            _buildStatusInfo(progress),

                            if (progress.isCompleted && progress.resultSummary != null) ...[
                              SizedBox(height: _syncPageSectionGap(context)),
                              _buildResultSummary(progress.resultSummary!),
                            ],
                            SizedBox(height: _syncPageBottomInset(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: _syncPageBottomInset(context),
                    ),
                    child: _buildActionButtons(progress),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double _syncPageHorizontalPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return 12;
    if (w < 420) return 16;
    return 24;
  }

  double _syncPageSectionGap(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    if (h < 640) return 8;
    if (h < 800) return 10;
    return 12;
  }

  double _syncPageBottomInset(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final extra = h < 640 ? 6.0 : 12.0;
    return extra;
  }

  Widget _buildMultiDeviceHint() {
    final isMobile = _isMobilePlatform();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isMobile ? Icons.smartphone : Icons.laptop_mac,
            size: 20,
            color: const Color(0xFF4F46E5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMobile
                  ? '当前在手机：与电脑通过同一云端双向合并；在电脑上打开本应用也会看到「本设备」变为电脑。'
                  : '当前在电脑：与手机通过同一云端双向合并；在手机上打开本应用也会看到「本设备」变为手机。',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 本机资料库规模（笔记条数与增量同步使用的本地集合一致：含已归档、不含回收站）
  Widget _buildLocalLibraryStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: _localStatsLoading
          ? Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '正在统计本机笔记与图片…',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_open, size: 20, color: Colors.indigo.shade400),
                    const SizedBox(width: 8),
                    const Text(
                      '本机资料库',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF312E81),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _localStatChip(
                        icon: Icons.article_outlined,
                        label: '笔记',
                        value: '${_localNoteCount ?? 0}',
                        unit: '条',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _localStatChip(
                        icon: Icons.image_outlined,
                        label: '图片',
                        value: '${_localImageCount ?? 0}',
                        unit: '张',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '笔记条数为未删除笔记（含已归档），与上次同步、下方开始同步后的本机数一致；'
                  '图片为正文中引用的本地路径（已去重，不含网络图）。',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _localStatChip({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF312E81),
                        ),
                      ),
                      TextSpan(
                        text: unit,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isMobilePlatform() {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  IconData _thisDeviceIcon() {
    if (kIsWeb) return Icons.web_outlined;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return Icons.smartphone;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return Icons.laptop_mac;
      case TargetPlatform.fuchsia:
        return Icons.devices;
    }
  }

  String _platformShortName() {
    if (kIsWeb) return '网页';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return '本设备';
    }
  }

  String _platformKindName() {
    if (kIsWeb) return '浏览器';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return '手机或平板';
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return '电脑';
      case TargetPlatform.fuchsia:
        return '设备';
    }
  }

  Widget _buildLastSessionBanner(SyncUiLastSession s) {
    final timeStr = DateFormat('MM-dd HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(s.lastSyncAtMs),
    );
    final ok = s.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok ? const Color(0xFF6EE7B7) : const Color(0xFFFDBA74),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.history : Icons.warning_amber_outlined,
            size: 22,
            color: ok ? const Color(0xFF065F46) : const Color(0xFF9A3412),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '上次同步 · $timeStr',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF312E81),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '本设备 ${s.localCount} 条 · 云端 ${s.remoteCount} 条 · ${ok ? '已完成' : (s.message ?? '未完成')}',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 条形进度 + 实时数量（圆环与文字分层，避免遮挡）
  Widget _buildProgressSection(SyncProgress progress) {
    return AnimatedBuilder(
      animation: _progressAnimationController,
      builder: (context, child) {
        final manualWait = _awaitingManualStart && _syncService != null;
        final animated = _progressAnimationController.value.clamp(0.0, 1.0);
        final showDeterminate = !manualWait &&
            (progress.isRunning || progress.isCompleted || progress.hasError);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '整体进度',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF312E81),
                    ),
                  ),
                  Text(
                    manualWait
                        ? '—'
                        : (progress.isCompleted
                            ? '100%'
                            : '${(animated * 100).round()}%'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF312E81),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: manualWait ? 0 : (showDeterminate ? animated : null),
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildLiveCountChip(
                      icon: _thisDeviceIcon(),
                      title: '本设备笔记',
                      value: progress.localNotesCount,
                      subtitle: _platformShortName(),
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildLiveCountChip(
                      icon: Icons.cloud_queue,
                      title: '云端笔记',
                      value: progress.remoteNotesCount,
                      subtitle: 'WebDAV',
                      color: const Color(0xFF818CF8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  manualWait
                      ? '点击「开始同步」后将拉取 WebDAV 并显示本设备与云端条数'
                      : '本轮步骤 ${progress.processedNotes} / ${progress.totalNotes == 0 ? '—' : '${progress.totalNotes}'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveCountChip({
    required IconData icon,
    required String title,
    required int value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$value 条',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// 状态信息
  Widget _buildStatusInfo(SyncProgress progress) {
    IconData phaseIcon;
    Color phaseColor;

    switch (progress.phase) {
      case SyncPhase.idle:
        phaseIcon = Icons.hourglass_empty;
        phaseColor = Colors.grey;
        break;
      case SyncPhase.preparing:
        phaseIcon = Icons.link;
        phaseColor = const Color(0xFF818CF8);
        break;
      case SyncPhase.syncingNotes:
        phaseIcon = Icons.sync;
        phaseColor = const Color(0xFF4F46E5);
        break;
      case SyncPhase.finalizing:
        phaseIcon = Icons.save_alt;
        phaseColor = const Color(0xFF6366F1);
        break;
      case SyncPhase.uploading:
        phaseIcon = Icons.cloud_upload;
        phaseColor = const Color(0xFF4F46E5);
        break;
      case SyncPhase.downloading:
        phaseIcon = Icons.cloud_download;
        phaseColor = const Color(0xFF22C55E);
        break;
      case SyncPhase.syncingImages:
        phaseIcon = Icons.image;
        phaseColor = const Color(0xFF818CF8);
        break;
      case SyncPhase.completed:
        phaseIcon = Icons.check_circle;
        phaseColor = const Color(0xFF22C55E);
        break;
      case SyncPhase.error:
        phaseIcon = Icons.error;
        phaseColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(phaseIcon, color: phaseColor, size: 20),
              const SizedBox(width: 8),
              Text(
                progress.message,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: phaseColor,
                ),
              ),
            ],
          ),
          if (progress.currentNoteTitle != null && progress.isRunning) ...[
            const SizedBox(height: 12),
            Text(
              '当前: ${progress.currentNoteTitle}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (progress.error != null) ...[
            const SizedBox(height: 12),
            Text(
              progress.error!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultSummary(String text) {
    final isWarning = text.contains('失败') ||
        text.contains('取消') ||
        text.contains('错误');
    final bg = isWarning
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFECFDF5);
    final border = isWarning
        ? const Color(0xFFFDBA74)
        : const Color(0xFF6EE7B7);
    final fg = isWarning
        ? const Color(0xFF9A3412)
        : const Color(0xFF065F46);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 20,
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButtons(SyncProgress progress) {
    if (_awaitingManualStart && _syncService != null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            setState(() => _awaitingManualStart = false);
            _syncService!.startBatchSync();
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('开始同步'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (progress.isRunning) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            _syncService?.cancelSync();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.stop),
          label: const Text('取消同步'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade400,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    } else if (progress.isCompleted) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.check),
          label: const Text('完成'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    } else if (progress.hasError) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: const Text('关闭'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                _syncService?.startBatchSync();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  /// 加载中页面
  Widget _buildLoadingPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF312E81)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '同步进度',
          style: TextStyle(
            color: Color(0xFF312E81),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
        ),
      ),
    );
  }

  /// 错误页面
  Widget _buildErrorPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF312E81)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '同步进度',
          style: TextStyle(
            color: Color(0xFF312E81),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF312E81),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                label: const Text('关闭'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
