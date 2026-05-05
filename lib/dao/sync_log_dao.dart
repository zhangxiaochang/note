import 'package:sqflite/sqflite.dart';

import 'db.dart';

/// 一条同步日志记录（展示与持久化共用）。
class SyncLogEntry {
  SyncLogEntry({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.kind,
    required this.outcome,
    required this.summary,
    this.detailJson,
  });

  final int id;
  final int startedAt;
  final int endedAt;
  final String kind;
  final String outcome;
  final String summary;
  final String? detailJson;

  factory SyncLogEntry.fromMap(Map<String, Object?> m) {
    return SyncLogEntry(
      id: m['id']! as int,
      startedAt: m['started_at']! as int,
      endedAt: m['ended_at']! as int,
      kind: m['kind']! as String,
      outcome: m['outcome']! as String,
      summary: m['summary']! as String,
      detailJson: m['detail_json'] as String?,
    );
  }

  Duration get duration => Duration(milliseconds: endedAt - startedAt);
}

/// 同步会话日志（全量 / 单条），存 SQLite 便于查询与展示。
class SyncLogDao {
  SyncLogDao._();
  static final instance = SyncLogDao._();

  Future<void> insert({
    required int startedAt,
    required int endedAt,
    required String kind,
    required String outcome,
    required String summary,
    String? detailJson,
  }) async {
    final db = await DB.instance.db;
    await db.insert('sync_log', {
      'started_at': startedAt,
      'ended_at': endedAt,
      'kind': kind,
      'outcome': outcome,
      'summary': summary,
      'detail_json': detailJson,
    });
    await _pruneIfNeeded(db);
  }

  /// 仅保留最近 [maxRows] 条，避免无限增长。
  Future<void> _pruneIfNeeded(Database db, {int maxRows = 400}) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sync_log'),
        ) ??
        0;
    if (count <= maxRows) return;
    final toDelete = count - maxRows;
    await db.rawDelete('''
      DELETE FROM sync_log WHERE id IN (
        SELECT id FROM sync_log ORDER BY ended_at ASC LIMIT ?
      )
    ''', [toDelete]);
  }

  Future<List<SyncLogEntry>> recent({int limit = 40}) async {
    final db = await DB.instance.db;
    final rows = await db.query(
      'sync_log',
      orderBy: 'ended_at DESC',
      limit: limit,
    );
    return rows.map(SyncLogEntry.fromMap).toList();
  }
}
