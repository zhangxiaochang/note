import 'dart:async';
import '../services/sync_service.dart';
import '../models/sync_state.dart';

/// 同步调度器
/// 管理自动同步的定时任务
class SyncScheduler {
  SyncService? _syncService;
  Timer? _syncTimer;
  bool _isRunning = false;

  // 配置
  Duration _interval = const Duration(minutes: 30);
  bool _onlyOnWifi = false;
  bool _autoSync = false;

  /// 同步完成回调
  void Function(SyncResult)? onSyncComplete;

  /// 同步错误回调
  void Function(String error)? onSyncError;

  /// 设置同步服务
  void setSyncService(SyncService service) {
    _syncService = service;
  }

  /// 配置自动同步
  void configure({
    Duration? interval,
    bool? onlyOnWifi,
    bool? autoSync,
  }) {
    _interval = interval ?? _interval;
    _onlyOnWifi = onlyOnWifi ?? _onlyOnWifi;
    _autoSync = autoSync ?? _autoSync;

    // 如果启用了自动同步，启动定时器
    if (_autoSync) {
      start();
    } else {
      stop();
    }
  }

  /// 启动自动同步
  void start() {
    if (_isRunning) return;

    _isRunning = true;
    _scheduleNextSync();
    print('SyncScheduler: 自动同步已启动，间隔: $_interval');
  }

  /// 停止自动同步
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _isRunning = false;
    print('SyncScheduler: 自动同步已停止');
  }

  /// 立即执行同步
  Future<void> syncNow({SyncDirection direction = SyncDirection.both}) async {
    if (_syncService == null) {
      onSyncError?.call('同步服务未配置');
      return;
    }

    // 检查是否应该同步
    if (!await _shouldSync()) {
      print('SyncScheduler: 当前条件不适合同步');
      return;
    }

    print('SyncScheduler: 开始执行同步');
    final result = await _syncService!.sync(direction);

    if (result.isSuccess) {
      onSyncComplete?.call(result);
    } else {
      onSyncError?.call(result.message);
    }

    // 重新调度下一次同步
    if (_isRunning) {
      _scheduleNextSync();
    }
  }

  /// 调度下一次同步
  void _scheduleNextSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(_interval, () => syncNow());
    print('SyncScheduler: 下次同步时间: ${DateTime.now().add(_interval)}');
  }

  /// 检查是否应该同步
  Future<bool> _shouldSync() async {
    // 检查自动同步开关
    if (!_autoSync) return false;

    // 检查 WiFi 设置
    if (_onlyOnWifi) {
      // 实际项目中应该检查网络连接类型
      // final connectivity = await Connectivity().checkConnectivity();
      // if (!connectivity.contains(ConnectivityResult.wifi)) {
      //   return false;
      // }
    }

    return true;
  }

  /// 应用进入前台时触发同步
  void onAppResumed() {
    if (_autoSync) {
      print('SyncScheduler: 应用进入前台，检查是否需要同步');
      syncNow();
    }
  }

  /// 应用进入后台时停止同步
  void onAppPaused() {
    // 可以选择在后台继续或暂停同步
    print('SyncScheduler: 应用进入后台');
  }

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 当前配置
  Map<String, dynamic> get config => {
        'interval': _interval.inMinutes,
        'onlyOnWifi': _onlyOnWifi,
        'autoSync': _autoSync,
      };

  /// 释放资源
  void dispose() {
    stop();
    _syncService = null;
  }
}

/// 同步触发时机
enum SyncTrigger {
  appStart,      // 应用启动时
  appResume,     // 应用恢复时
  manual,        // 手动触发
  scheduled,     // 定时触发
  bookAdded,     // 添加书籍时
  bookUpdated,   // 更新书籍时
  noteAdded,     // 添加笔记时
}

/// 同步触发器
class SyncTriggerManager {
  final SyncScheduler _scheduler;
  final Map<SyncTrigger, bool> _enabledTriggers = {};

  SyncTriggerManager(this._scheduler);

  /// 配置触发器
  void configure(Map<SyncTrigger, bool> triggers) {
    _enabledTriggers.clear();
    _enabledTriggers.addAll(triggers);
  }

  /// 触发同步
  void trigger(SyncTrigger trigger) {
    if (_enabledTriggers[trigger] ?? false) {
      print('SyncTrigger: 触发同步 - $trigger');
      _scheduler.syncNow();
    }
  }

  /// 启用触发器
  void enable(SyncTrigger trigger) {
    _enabledTriggers[trigger] = true;
  }

  /// 禁用触发器
  void disable(SyncTrigger trigger) {
    _enabledTriggers[trigger] = false;
  }
}
