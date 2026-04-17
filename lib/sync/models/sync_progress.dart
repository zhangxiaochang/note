import 'dart:async';
import 'dart:math' as math;

/// 同步阶段
enum SyncPhase {
  idle,
  preparing,
  syncingNotes,
  finalizing,
  uploading,
  downloading,
  syncingImages,
  completed,
  error,
}

/// 同步进度信息
class SyncProgress {
  final SyncPhase phase;
  final int localNotesCount;
  final int remoteNotesCount;
  final int processedNotes;
  final int totalNotes;
  final int currentNoteIndex;
  final String? currentNoteTitle;
  final double percentage;
  final String message;
  final String? error;
  final String? resultSummary;

  const SyncProgress({
    this.phase = SyncPhase.idle,
    this.localNotesCount = 0,
    this.remoteNotesCount = 0,
    this.processedNotes = 0,
    this.totalNotes = 0,
    this.currentNoteIndex = 0,
    this.currentNoteTitle,
    this.percentage = 0,
    this.message = '准备同步',
    this.error,
    this.resultSummary,
  });

  SyncProgress copyWith({
    SyncPhase? phase,
    int? localNotesCount,
    int? remoteNotesCount,
    int? processedNotes,
    int? totalNotes,
    int? currentNoteIndex,
    String? currentNoteTitle,
    double? percentage,
    String? message,
    String? error,
    String? resultSummary,
    bool clearResultSummary = false,
  }) {
    return SyncProgress(
      phase: phase ?? this.phase,
      localNotesCount: localNotesCount ?? this.localNotesCount,
      remoteNotesCount: remoteNotesCount ?? this.remoteNotesCount,
      processedNotes: processedNotes ?? this.processedNotes,
      totalNotes: totalNotes ?? this.totalNotes,
      currentNoteIndex: currentNoteIndex ?? this.currentNoteIndex,
      currentNoteTitle: currentNoteTitle ?? this.currentNoteTitle,
      percentage: percentage ?? this.percentage,
      message: message ?? this.message,
      error: error ?? this.error,
      resultSummary: clearResultSummary ? null : (resultSummary ?? this.resultSummary),
    );
  }

  bool get isRunning =>
      phase != SyncPhase.idle &&
      phase != SyncPhase.completed &&
      phase != SyncPhase.error;

  bool get isCompleted => phase == SyncPhase.completed;

  bool get hasError => phase == SyncPhase.error;
}

/// 同步进度控制器
class SyncProgressController {
  final _progressController = StreamController<SyncProgress>.broadcast();
  SyncProgress _currentProgress = const SyncProgress();

  Stream<SyncProgress> get progressStream => _progressController.stream;

  SyncProgress get currentProgress => _currentProgress;

  void updateProgress(SyncProgress progress) {
    _currentProgress = progress;
    _progressController.add(progress);
  }

  void setPhase(SyncPhase phase, {String? message}) {
    updateProgress(_currentProgress.copyWith(
      phase: phase,
      message: message ?? _getMessageForPhase(phase),
    ));
  }

  void setCounts({
    required int localNotesCount,
    required int remoteNotesCount,
    required int totalNotes,
  }) {
    updateProgress(_currentProgress.copyWith(
      localNotesCount: localNotesCount,
      remoteNotesCount: remoteNotesCount,
      totalNotes: totalNotes,
    ));
  }

  void updateProcessedNotes(int processed, {String? currentNoteTitle}) {
    final total = math.max(1, _currentProgress.totalNotes);
    final clamped = math.min(processed, total);
    final percentage = (clamped / total * 100).clamp(0.0, 99.9);

    updateProgress(_currentProgress.copyWith(
      processedNotes: processed,
      currentNoteIndex: processed,
      currentNoteTitle: currentNoteTitle,
      percentage: percentage,
    ));
  }

  void setError(String error) {
    updateProgress(_currentProgress.copyWith(
      phase: SyncPhase.error,
      error: error,
      message: '同步出错',
    ));
  }

  void complete({String? resultSummary}) {
    final c = _currentProgress;
    final total = math.max(1, c.totalNotes);
    updateProgress(SyncProgress(
      phase: SyncPhase.completed,
      localNotesCount: c.localNotesCount,
      remoteNotesCount: c.remoteNotesCount,
      processedNotes: total,
      totalNotes: c.totalNotes,
      currentNoteIndex: c.currentNoteIndex,
      currentNoteTitle: c.currentNoteTitle,
      percentage: 100,
      message: '同步完成',
      error: null,
      resultSummary: resultSummary,
    ));
  }

  void reset() {
    _currentProgress = const SyncProgress();
    _progressController.add(_currentProgress);
  }

  String _getMessageForPhase(SyncPhase phase) {
    switch (phase) {
      case SyncPhase.idle:
        return '准备同步';
      case SyncPhase.preparing:
        return '正在准备…';
      case SyncPhase.syncingNotes:
        return '正在同步笔记与图片…';
      case SyncPhase.finalizing:
        return '正在保存状态…';
      case SyncPhase.uploading:
        return '正在上传…';
      case SyncPhase.downloading:
        return '正在下载…';
      case SyncPhase.syncingImages:
        return '正在同步图片…';
      case SyncPhase.completed:
        return '同步完成';
      case SyncPhase.error:
        return '同步出错';
    }
  }

  void dispose() {
    _progressController.close();
  }
}
