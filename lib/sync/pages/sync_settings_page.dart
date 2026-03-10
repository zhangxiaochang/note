import 'package:flutter/material.dart';
import '../models/sync_state.dart';
import '../providers/sync_provider.dart';
import '../services/sync_service.dart';
import '../../services/webdav_config_service.dart';

/// 同步设置页面
class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  bool _autoSync = true;
  bool _syncOnWifiOnly = true;
  ConflictResolutionStrategy _conflictStrategy = ConflictResolutionStrategy.askUser;
  SyncDirection _defaultDirection = SyncDirection.both;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // TODO: 从本地存储加载设置
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('同步设置'),
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 同步开关
          _buildSection(
            title: '自动同步',
            children: [
              SwitchListTile(
                title: const Text('启用自动同步'),
                subtitle: const Text('应用启动时自动检查同步'),
                value: _autoSync,
                onChanged: (value) {
                  setState(() => _autoSync = value);
                },
              ),
              SwitchListTile(
                title: const Text('仅 WiFi 同步'),
                subtitle: const Text('避免使用移动数据'),
                value: _syncOnWifiOnly,
                onChanged: (value) {
                  setState(() => _syncOnWifiOnly = value);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 冲突解决策略
          _buildSection(
            title: '冲突解决',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当本地和远程数据冲突时',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...ConflictResolutionStrategy.values.map((strategy) {
                      return RadioListTile<ConflictResolutionStrategy>(
                        title: Text(_getStrategyName(strategy)),
                        subtitle: Text(_getStrategyDescription(strategy)),
                        value: strategy,
                        groupValue: _conflictStrategy,
                        onChanged: (value) {
                          setState(() => _conflictStrategy = value!);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 默认同步方向
          _buildSection(
            title: '默认同步方向',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '手动同步时的默认行为',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...SyncDirection.values.map((direction) {
                      return RadioListTile<SyncDirection>(
                        title: Text(_getDirectionName(direction)),
                        subtitle: Text(_getDirectionDescription(direction)),
                        value: direction,
                        groupValue: _defaultDirection,
                        onChanged: (value) {
                          setState(() => _defaultDirection = value!);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 保存按钮
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('保存设置'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  String _getStrategyName(ConflictResolutionStrategy strategy) {
    switch (strategy) {
      case ConflictResolutionStrategy.newerWins:
        return '较新版本优先';
      case ConflictResolutionStrategy.localWins:
        return '本地版本优先';
      case ConflictResolutionStrategy.remoteWins:
        return '远程版本优先';
      case ConflictResolutionStrategy.askUser:
        return '询问我';
      case ConflictResolutionStrategy.merge:
        return '尝试合并';
    }
  }

  String _getStrategyDescription(ConflictResolutionStrategy strategy) {
    switch (strategy) {
      case ConflictResolutionStrategy.newerWins:
        return '自动选择修改时间较新的版本';
      case ConflictResolutionStrategy.localWins:
        return '总是保留本地版本';
      case ConflictResolutionStrategy.remoteWins:
        return '总是使用远程版本';
      case ConflictResolutionStrategy.askUser:
        return '每次冲突时弹出对话框让我选择';
      case ConflictResolutionStrategy.merge:
        return '尝试合并两个版本的数据（实验性）';
    }
  }

  String _getDirectionName(SyncDirection direction) {
    switch (direction) {
      case SyncDirection.upload:
        return '上传到云端';
      case SyncDirection.download:
        return '从云端下载';
      case SyncDirection.both:
        return '双向同步';
    }
  }

  String _getDirectionDescription(SyncDirection direction) {
    switch (direction) {
      case SyncDirection.upload:
        return '将本地数据上传到 WebDAV 服务器';
      case SyncDirection.download:
        return '从 WebDAV 服务器下载数据到本地';
      case SyncDirection.both:
        return '智能合并本地和远程的数据';
    }
  }

  Future<void> _saveSettings() async {
    // TODO: 保存设置到本地存储
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );
  }
}

/// 冲突解决策略枚举（如果还没定义）
enum ConflictResolutionStrategy {
  newerWins,
  localWins,
  remoteWins,
  askUser,
  merge,
}
