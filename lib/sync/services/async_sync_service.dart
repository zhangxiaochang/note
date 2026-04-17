import 'package:flutter/material.dart';

import '../models/sync_progress.dart';
import '../models/sync_state.dart';
import 'incremental_sync.dart';
import 'single_note_sync.dart';
import 'sync_client_base.dart';
import 'sync_ui_prefs.dart';

/// 异步同步：批量增量同步（与 [IncrementalSync] 一致）及单条笔记同步入口
class AsyncSyncService {
  AsyncSyncService(this._client) {
    _singleNoteSync = SingleNoteSync(_client);
  }

  final SyncClientBase _client;
  late final SingleNoteSync _singleNoteSync;
  final SyncProgressController _progressController = SyncProgressController();

  BuildContext? _context;

  bool _isCancelled = false;
  bool _isRunning = false;

  Stream<SyncProgress> get progressStream => _progressController.progressStream;

  SyncProgress get currentProgress => _progressController.currentProgress;

  bool get isRunning => _isRunning;

  void setContext(BuildContext context) {
    _context = context;
    _singleNoteSync.setContext(context);
  }

  Future<void> startBatchSync() async {
    if (_isRunning) {
      return;
    }

    _isRunning = true;
    _isCancelled = false;
    _progressController.reset();

    try {
      await _performBatchSync();
    } on SyncUserCancelled {
      _progressController.complete(resultSummary: '同步已取消');
    } catch (e) {
      _progressController.setError(e.toString());
    } finally {
      _isRunning = false;
    }
  }

  void cancelSync() {
    if (_isRunning) {
      _isCancelled = true;
    }
  }

  Future<void> _performBatchSync() async {
    final incremental = IncrementalSync(
      _client,
      progress: _progressController,
      isCancelled: () => _isCancelled,
    );
    if (_context != null && _context!.mounted) {
      incremental.setContext(_context!);
    }

    final result = await incremental.sync();

    final snap = _progressController.currentProgress;
    if (snap.localNotesCount > 0 || snap.remoteNotesCount > 0 || snap.totalNotes > 0) {
      await SyncUiPrefs.saveAfterSession(
        localCount: snap.localNotesCount,
        remoteCount: snap.remoteNotesCount,
        success: !_isCancelled && result.isSuccess,
        message: _isCancelled
            ? '同步已取消'
            : (result.isSuccess ? null : result.message),
      );
    }

    if (_isCancelled) {
      _progressController.complete(resultSummary: '同步已取消');
      return;
    }

    if (result.isSuccess) {
      _progressController.complete();
    } else {
      _progressController.complete(resultSummary: result.message);
    }
  }

  Future<SyncResult> syncSingleNote(String noteUuid,
      {VoidCallback? onComplete}) async {
    _progressController.setPhase(SyncPhase.preparing,
        message: '正在同步笔记…');

    try {
      final result = await _singleNoteSync.syncNote(noteUuid);

      if (result.isSuccess) {
        _progressController.complete();
      } else {
        _progressController.setError(result.message);
      }

      onComplete?.call();
      return result;
    } catch (e) {
      _progressController.setError(e.toString());
      onComplete?.call();
      return SyncResult.failure(e.toString(), SyncFailureType.unknown);
    }
  }

  void dispose() {
    _progressController.dispose();
  }
}
