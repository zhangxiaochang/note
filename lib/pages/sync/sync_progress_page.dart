import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../dao/db.dart';
import '../../dao/sync_log_dao.dart';
import '../../services/theme_provider.dart';
import '../../services/webdav_config_service.dart';
import '../../sync/models/sync_progress.dart';
import '../../sync/services/async_sync_service.dart';
import '../../sync/services/sync_ui_prefs.dart';
import '../../sync/services/webdav_client.dart';
import '../../utils/quill_image_paths.dart';

class SyncProgressPage extends StatefulWidget {
  const SyncProgressPage({super.key, this.autoStart = false});
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
  int? _localNoteCount;
  int? _localImageCount;
  bool _localStatsLoading = true;
  bool _refreshedLocalStatsAfterSync = false;
  int _syncLogListVersion = 0;

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450),
    );
    SyncUiPrefs.loadLastSession().then((s) {
      if (mounted) setState(() => _lastSession = s);
    });
    _refreshLocalStats();
    _initSyncService();
  }

  Future<void> _refreshLocalStats() async {
    try {
      final notes = await DB.instance.queryAll();
      final img = countDistinctLocalImageRefs(notes);
      if (!mounted) return;
      setState(() {
        _localNoteCount = notes.length;
        _localImageCount = img;
        _localStatsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _localStatsLoading = false);
    }
  }

  void _initSyncService() async {
    try {
      final config = await WebDAVConfigService.loadConfig();
      if (!mounted) return;
      if (!config.isValid) {
        setState(() => _errorMessage = 'WebDAV 配置无效，请先配置同步设置');
        return;
      }
      final client = WebdavClient(
        url: config.url, username: config.username, password: config.password,
      );
      final service = AsyncSyncService(client);
      if (!mounted) return;
      service.setContext(context);
      setState(() {
        _syncService = service;
        _awaitingManualStart = !widget.autoStart;
      });
      if (widget.autoStart) await service.startBatchSync();
    } catch (e) {
      setState(() => _errorMessage = '初始化同步服务失败: $e');
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _syncService?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════
  // Colors
  // ═══════════════════════════════════════════

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? ThemeProvider.darkBackgroundColor : ThemeProvider.lightBackgroundColor;
  Color get _card => _isDark ? ThemeProvider.darkCardColor : ThemeProvider.lightCardColor;
  Color get _text => _isDark ? ThemeProvider.darkTextColor : ThemeProvider.lightTextColor;
  Color get _sec => _isDark ? ThemeProvider.darkSecondaryTextColor : ThemeProvider.lightSecondaryTextColor;
  Color get _muted => _isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

  double get _pad {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return 12; if (w < 420) return 16; return 24;
  }
  double get _gap {
    final h = MediaQuery.sizeOf(context).height;
    if (h < 640) return 8; if (h < 800) return 10; return 12;
  }

  // ═══════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) return _buildErrorPage();
    if (_syncService == null) return _buildLoadingPage();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0, scrolledUnderElevation: 0.5,
        title: const Text('同步', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: _text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: Text(
              _platformKindName() == '电脑'
                  ? '手机与电脑请配置同一 WebDAV；笔记以 JSON 同步，图片单独上传并与正文关联。'
                  : '手机与电脑请配置同一 WebDAV；笔记以 JSON 同步，图片单独上传并与正文关联。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _sec, height: 1.35),
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
              if (mounted) {
                setState(() => _syncLogListVersion++);
                _refreshLocalStats();
              }
            });
          } else if (progress.isRunning) {
            _refreshedLocalStatsAfterSync = false;
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(_pad, 0, _pad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_lastSession != null) ...[
                        _banner(_lastSession!),
                        SizedBox(height: _gap),
                      ],
                      _localStats(),
                      SizedBox(height: _gap),
                      _progressCard(progress),
                      SizedBox(height: _gap + 4),
                      _statusCard(progress),
                      if (progress.isCompleted && progress.resultSummary != null) ...[
                        SizedBox(height: _gap),
                        _resultSummary(progress.resultSummary!),
                      ],
                      SizedBox(height: _gap),
                      _recentLogs(),
                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              _bottomButton(progress),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Banner
  // ═══════════════════════════════════════════

  Widget _banner(SyncUiLastSession s) {
    final ok = s.success;
    final timeStr = DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(s.lastSyncAtMs));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ok ? const Color(0xFF6EE7B7) : const Color(0xFFFDBA74)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.history : Icons.warning_amber_outlined,
            size: 22, color: ok ? const Color(0xFF065F46) : const Color(0xFF9A3412)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('上次同步 · $timeStr',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _text)),
                const SizedBox(height: 3),
                Text('本设备 ${s.localCount} 条 · 云端 ${s.remoteCount} 条 · ${ok ? '已完成' : (s.message ?? '未完成')}',
                  style: TextStyle(fontSize: 12, height: 1.3, color: _sec)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Local Stats
  // ═══════════════════════════════════════════

  Widget _localStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: _localStatsLoading
          ? Row(children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _sec)),
              const SizedBox(width: 12),
              Text('正在统计…', style: TextStyle(fontSize: 13, color: _sec)),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本机资料库', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _text)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _statChip('笔记', '${_localNoteCount ?? 0}', '条')),
                  const SizedBox(width: 10),
                  Expanded(child: _statChip('图片', '${_localImageCount ?? 0}', '张')),
                ]),
                const SizedBox(height: 8),
                Text(
                  '笔记条数为未删除笔记（含已归档）；图片为正文中引用的本地路径（已去重，不含网络图）。',
                  style: TextStyle(fontSize: 10, height: 1.3, color: _sec),
                ),
              ],
            ),
    );
  }

  Widget _statChip(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _muted, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: _sec)),
          const SizedBox(height: 2),
          Text.rich(TextSpan(children: [
            TextSpan(text: value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _text)),
            TextSpan(text: unit, style: TextStyle(fontSize: 13, color: _sec)),
          ])),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Progress Card
  // ═══════════════════════════════════════════

  Widget _progressCard(SyncProgress progress) {
    final manualWait = _awaitingManualStart && _syncService != null;
    return AnimatedBuilder(
      animation: _progressAnimationController,
      builder: (context, _) {
        final animated = _progressAnimationController.value.clamp(0.0, 1.0);
        final showDeterminate = !manualWait && (progress.isRunning || progress.isCompleted || progress.hasError);
        final pct = manualWait ? 0.0 : (progress.isCompleted ? 1.0 : animated);
        final pctText = manualWait ? '—' : '${(pct * 100).round()}%';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('整体进度', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _text)),
                  Text(pctText, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ThemeProvider.primaryColor)),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: manualWait ? null : (showDeterminate ? pct : null),
                  minHeight: 10,
                  backgroundColor: _muted,
                  color: progress.isCompleted ? const Color(0xFF34C759) : ThemeProvider.primaryColor,
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _countChip(Icons.laptop_mac, '本设备笔记', progress.localNotesCount, _platformShortName(), ThemeProvider.primaryColor)),
                const SizedBox(width: 10),
                Expanded(child: _countChip(Icons.cloud_queue, '云端笔记', progress.remoteNotesCount, 'WebDAV', const Color(0xFF007AFF))),
              ]),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  manualWait ? '点击「开始同步」后将拉取 WebDAV 并显示本设备与云端条数'
                      : '本轮步骤 ${progress.processedNotes} / ${progress.totalNotes == 0 ? '—' : '${progress.totalNotes}'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _sec),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _countChip(IconData icon, String title, int value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _text), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 6),
          Text('$value 条', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(sub, style: TextStyle(fontSize: 10, color: _sec)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Status Card
  // ═══════════════════════════════════════════

  Widget _statusCard(SyncProgress progress) {
    IconData icon; Color color;
    switch (progress.phase) {
      case SyncPhase.idle:        icon = Icons.hourglass_empty;   color = _sec; break;
      case SyncPhase.preparing:   icon = Icons.link;              color = ThemeProvider.primaryColorDark; break;
      case SyncPhase.syncingNotes:icon = Icons.sync;              color = ThemeProvider.primaryColor; break;
      case SyncPhase.uploading:   icon = Icons.cloud_upload;      color = ThemeProvider.primaryColor; break;
      case SyncPhase.downloading: icon = Icons.cloud_download;    color = ThemeProvider.secondaryColor; break;
      case SyncPhase.syncingImages:icon=Icons.image;             color = ThemeProvider.primaryColorDark; break;
      case SyncPhase.finalizing:  icon = Icons.save_alt;          color = ThemeProvider.primaryColorDark; break;
      case SyncPhase.completed:   icon = Icons.check_circle;      color = ThemeProvider.secondaryColor; break;
      case SyncPhase.error:       icon = Icons.error;             color = Colors.red; break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(progress.message, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color)),
          ]),
          if (progress.currentNoteTitle != null && progress.isRunning) ...[
            const SizedBox(height: 10),
            Text('当前: ${progress.currentNoteTitle}', style: TextStyle(fontSize: 14, color: _sec), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          if (progress.error != null) ...[
            const SizedBox(height: 10),
            Text(progress.error!, style: const TextStyle(fontSize: 12, color: Colors.red), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Result Summary
  // ═══════════════════════════════════════════

  Widget _resultSummary(String text) {
    final isWarning = text.contains('失败') || text.contains('取消') || text.contains('错误');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWarning ? const Color(0xFFFDBA74) : const Color(0xFF6EE7B7)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
          size: 20, color: isWarning ? const Color(0xFF9A3412) : const Color(0xFF065F46)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.35,
          color: isWarning ? const Color(0xFF9A3412) : const Color(0xFF065F46)))),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  // Recent Logs
  // ═══════════════════════════════════════════

  Widget _recentLogs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.history, size: 18, color: _sec),
            const SizedBox(width: 6),
            Text('最近同步记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _text)),
          ]),
          const SizedBox(height: 8),
          FutureBuilder<List<SyncLogEntry>>(
            future: SyncLogDao.instance.recent(limit: 5),
            builder: (_, snap) {
              final items = snap.data ?? [];
              if (items.isEmpty && snap.connectionState == ConnectionState.done) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text('暂无记录', style: TextStyle(fontSize: 13, color: _sec)),
                );
              }
              return Column(children: items.map((e) => _logItem(e)).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _logItem(SyncLogEntry e) {
    final ok = e.outcome == 'success';
    final timeStr = DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(e.startedAt));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8, height: 8, margin: const EdgeInsets.only(top: 4, right: 10),
            decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? const Color(0xFF34C759) : const Color(0xFFFF3B30)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(timeStr, style: TextStyle(fontSize: 11, color: _sec)),
                const SizedBox(height: 2),
                Text(e.summary, style: TextStyle(fontSize: 13, height: 1.3, color: _text)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Bottom Button
  // ═══════════════════════════════════════════

  Widget _bottomButton(SyncProgress progress) {
    Widget btn;
    if (_awaitingManualStart && _syncService != null) {
      btn = _btn('开始同步', ThemeProvider.primaryColor, () {
        setState(() => _awaitingManualStart = false);
        _syncService!.startBatchSync();
      });
    } else if (progress.isRunning) {
      btn = _btn('取消同步', Colors.red.shade400, () {
        _syncService?.cancelSync();
        Navigator.of(context).pop();
      });
    } else if (progress.isCompleted) {
      btn = _btn('完成', const Color(0xFF34C759), () => Navigator.of(context).pop(true));
    } else if (progress.hasError) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          Expanded(child: _btnGhost('关闭', () => Navigator.of(context).pop())),
          const SizedBox(width: 12),
          Expanded(child: _btn('重试', ThemeProvider.primaryColor, () => _syncService?.startBatchSync())),
        ]),
      );
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: btn,
    );
  }

  Widget _btn(String text, Color bg, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _btnGhost(String text, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _muted, foregroundColor: _text,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════

  String _platformShortName() {
    if (kIsWeb) return '网页';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return 'Android';
      case TargetPlatform.iOS: return 'iOS';
      case TargetPlatform.macOS: return 'macOS';
      case TargetPlatform.windows: return 'Windows';
      case TargetPlatform.linux: return 'Linux';
      case TargetPlatform.fuchsia: return '本设备';
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

  Widget _buildErrorPage() {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('同步')),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: _text)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('返回')),
        ]),
      )),
    );
  }

  Widget _buildLoadingPage() {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('同步')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
