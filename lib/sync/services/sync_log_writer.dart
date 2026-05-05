import 'dart:convert';

import 'package:intl/intl.dart';

import '../../dao/sync_log_dao.dart';
import '../models/sync_progress.dart';
import '../models/sync_state.dart';

/// 将全量 / 单条同步结果写入 [sync_log]，供同步页展示与时间线追溯。
class SyncLogWriter {
  SyncLogWriter._();

  static const String kindBatch = 'batch';
  static const String kindSingle = 'single_note';

  static const String outcomeSuccess = 'success';
  static const String outcomeError = 'error';
  static const String outcomeCancelled = 'cancelled';
  /// 进程被杀、崩溃等导致未执行到正常收尾（由冷启动恢复逻辑写入）。
  static const String outcomeTerminated = 'terminated';

  static String _fmtStart(int startedAtMs) => DateFormat('yyyy-MM-dd HH:mm:ss').format(
        DateTime.fromMillisecondsSinceEpoch(startedAtMs),
      );

  /// 冷启动时发现仍有「全量同步进行中」标记时调用。
  static Future<void> appendBatchProcessEnded({
    required int startedAt,
    required int endedAt,
  }) async {
    final durationMs = endedAt - startedAt;
    final detail = <String, dynamic>{
      'durationMs': durationMs,
      'interruptReason': 'process_terminated_or_os_kill',
      'startedAtFormatted': _fmtStart(startedAt),
    };
    final summary =
        '全量同步 · 未正常结束 · 推断原因：应用被系统回收、从任务列表划掉或崩溃，未完成收尾（曾于 ${_fmtStart(startedAt)} 开始）';
    await SyncLogDao.instance.insert(
      startedAt: startedAt,
      endedAt: endedAt,
      kind: kindBatch,
      outcome: outcomeTerminated,
      summary: summary,
      detailJson: jsonEncode(detail),
    );
  }

  /// 冷启动时发现仍有「单条同步进行中」标记时调用。
  static Future<void> appendSingleNoteProcessEnded({
    required int startedAt,
    required int endedAt,
    required String noteUuid,
  }) async {
    final durationMs = endedAt - startedAt;
    final detail = <String, dynamic>{
      'noteUuid': noteUuid,
      'durationMs': durationMs,
      'interruptReason': 'process_terminated_or_os_kill',
      'startedAtFormatted': _fmtStart(startedAt),
    };
    final summary =
        '单条同步 · 未正常结束 · 推断原因：应用进程被结束（笔记 $noteUuid · 曾于 ${_fmtStart(startedAt)} 开始）';
    await SyncLogDao.instance.insert(
      startedAt: startedAt,
      endedAt: endedAt,
      kind: kindSingle,
      outcome: outcomeTerminated,
      summary: summary,
      detailJson: jsonEncode(detail),
    );
  }

  /// 全量同步结束调用（含用户取消、失败、成功）。
  static Future<void> appendBatch({
    required int startedAt,
    required int endedAt,
    required bool userCancelled,
    required SyncResult result,
    required SyncProgress progress,
  }) async {
    final durationMs = endedAt - startedAt;
    final detail = <String, dynamic>{
      'durationMs': durationMs,
      'localNotesCount': progress.localNotesCount,
      'remoteNotesCount': progress.remoteNotesCount,
      'totalNotes': progress.totalNotes,
      'processedNotes': progress.processedNotes,
      'resultMessage': result.message,
    };

    String outcome;
    String summary;

    if (userCancelled) {
      outcome = outcomeCancelled;
      summary =
          '全量同步 · 已中断 · 原因：用户取消或同步过程中主动中止（${durationMs ~/ 1000}s）';
      detail['interruptReason'] = 'user_cancelled_or_abort';
    } else if (result.isSuccess) {
      outcome = outcomeSuccess;
      summary =
          '全量同步 · 成功 · 用时 ${durationMs ~/ 1000}s · 本机 ${progress.localNotesCount} 条 · 云端索引 ${progress.remoteNotesCount} 条 · 计划步骤 ${progress.totalNotes} · 已处理 ${progress.processedNotes}';
    } else {
      outcome = outcomeError;
      summary = '全量同步 · 失败 · ${result.message}（用时 ${durationMs ~/ 1000}s）';
      if (result.failureType != null) {
        detail['failureType'] = result.failureType!.name;
      }
    }

    await SyncLogDao.instance.insert(
      startedAt: startedAt,
      endedAt: endedAt,
      kind: kindBatch,
      outcome: outcome,
      summary: summary,
      detailJson: jsonEncode(detail),
    );
  }

  /// 单条笔记同步结束调用。
  static Future<void> appendSingleNote({
    required int startedAt,
    required int endedAt,
    required String noteUuid,
    required String noteTitle,
    required int localImageRefCount,
    required SyncResult result,
  }) async {
    final durationMs = endedAt - startedAt;
    final titleShort =
        noteTitle.trim().isEmpty ? '(无标题)' : noteTitle.trim();
    final detail = <String, dynamic>{
      'noteUuid': noteUuid,
      'noteTitle': noteTitle,
      'localImageRefsInDelta': localImageRefCount,
      'durationMs': durationMs,
      'resultMessage': result.message,
    };

    String outcome;
    String summary;
    if (result.isSuccess) {
      outcome = outcomeSuccess;
      summary =
          '单条同步 · $titleShort · ${result.message} · 用时 ${durationMs}ms · 正文内本地图片引用 $localImageRefCount 张（已随笔记一并处理）';
    } else {
      outcome = outcomeError;
      summary =
          '单条同步 · $titleShort · 失败 · ${result.message}（用时 ${durationMs}ms）';
      if (result.failureType != null) {
        detail['failureType'] = result.failureType!.name;
      }
    }

    await SyncLogDao.instance.insert(
      startedAt: startedAt,
      endedAt: endedAt,
      kind: kindSingle,
      outcome: outcome,
      summary: summary,
      detailJson: jsonEncode(detail),
    );
  }
}
