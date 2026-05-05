import 'package:flutter/material.dart';

import '../../dao/db.dart';
import '../../domain/note.dart';
import '../../utils/image_path_resolver.dart';
import '../../utils/quill_image_paths.dart';
import '../models/sync_progress.dart';
import '../models/sync_state.dart';
import 'synchronizer.dart';
import 'single_note_sync.dart';
import 'sync_client_base.dart';
import 'sync_ui_prefs.dart';
import 'sync_log_writer.dart';
import 'sync_session_marker.dart';

/// 异步同步：批量 [Synchronizer] 与单条 [SingleNoteSync] 入口
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
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    await SyncSessionMarker.markBatchPending(startedAt);
    try {
      final sync = Synchronizer(
        _client,
        progress: _progressController,
        isCancelled: () => _isCancelled,
      );
      if (_context != null && _context!.mounted) {
        sync.setContext(_context!);
      }

      final result = await sync.run();
      final endedAt = DateTime.now().millisecondsSinceEpoch;
      final snap = _progressController.currentProgress;

      await SyncLogWriter.appendBatch(
        startedAt: startedAt,
        endedAt: endedAt,
        userCancelled: _isCancelled,
        result: result,
        progress: snap,
      );

      if (snap.localNotesCount > 0 ||
          snap.remoteNotesCount > 0 ||
          snap.totalNotes > 0) {
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
    } finally {
      await SyncSessionMarker.clearBatchPending();
    }
  }

  Future<SyncResult> syncSingleNote(String noteUuid,
      {VoidCallback? onComplete, bool forceSync = false}) async {
    _progressController.setPhase(SyncPhase.preparing,
        message: '正在同步笔记…');

    final startedAt = DateTime.now().millisecondsSinceEpoch;
    await SyncSessionMarker.markSinglePending(
      noteUuid: noteUuid,
      startedAtMs: startedAt,
    );
    try {
      try {
        final result =
            await _singleNoteSync.syncNote(noteUuid, forceSync: forceSync);
        final endedAt = DateTime.now().millisecondsSinceEpoch;

        final note = await DB.instance.queryNoteByUuid(noteUuid);
        final title = note?.title ?? '';
        final imgRefs = _countLocalImageRefs(note);

        await SyncLogWriter.appendSingleNote(
          startedAt: startedAt,
          endedAt: endedAt,
          noteUuid: noteUuid,
          noteTitle: title,
          localImageRefCount: imgRefs,
          result: result,
        );

        if (result.isSuccess) {
          _progressController.complete();
        } else {
          _progressController.setError(result.message);
        }

        onComplete?.call();
        return result;
      } catch (e) {
        final endedAt = DateTime.now().millisecondsSinceEpoch;
        final fail = SyncResult.failure(e.toString(), SyncFailureType.unknown);
        final note = await DB.instance.queryNoteByUuid(noteUuid);
        await SyncLogWriter.appendSingleNote(
          startedAt: startedAt,
          endedAt: endedAt,
          noteUuid: noteUuid,
          noteTitle: note?.title ?? '',
          localImageRefCount: _countLocalImageRefs(note),
          result: fail,
        );
        _progressController.setError(e.toString());
        onComplete?.call();
        return fail;
      }
    } finally {
      await SyncSessionMarker.clearSinglePending();
    }
  }

  static int _countLocalImageRefs(Note? note) {
    if (note?.deltaContent == null) return 0;
    final paths = extractImagePathsFromQuillDelta(note!.deltaContent);
    var n = 0;
    for (final p in paths) {
      final t = p.trim();
      if (t.isEmpty || ImagePathResolver.isWebUrl(t)) continue;
      n++;
    }
    return n;
  }

  void dispose() {
    _progressController.dispose();
  }
}
