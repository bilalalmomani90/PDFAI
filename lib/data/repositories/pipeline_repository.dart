import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../enums.dart';
import '../models.dart';

/// Stores the state of each processing stage so work can pause/resume
/// (after the user stops it, the app closes, or the device restarts).
class PipelineRepository {
  PipelineRepository(this._d);
  final AppDatabase _d;
  Database get _db => _d.db;

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Creates pending rows for the given stages; existing rows are kept.
  Future<void> initStages(String documentId, List<String> stageKeys) async {
    final batch = _db.batch();
    for (final key in stageKeys) {
      batch.insert(
        'stages',
        {
          'document_id': documentId,
          'stage_key': key,
          'status': StageStatus.pending.name,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<StageRecord>> stages(String documentId) async {
    final rows = await _db.query('stages',
        where: 'document_id = ?', whereArgs: [documentId], orderBy: 'rowid');
    return rows.map(StageRecord.fromMap).toList();
  }

  Future<void> markRunning(String documentId, String key) => _db.rawUpdate(
        'UPDATE stages SET status = ?, attempts = attempts + 1, error = NULL, '
        'started_at = ?, finished_at = NULL WHERE document_id = ? AND stage_key = ?',
        [StageStatus.running.name, _now(), documentId, key],
      );

  Future<void> updateProgress(String documentId, String key, double progress) =>
      _db.update(
        'stages',
        {'progress': progress.clamp(0.0, 1.0)},
        where: 'document_id = ? AND stage_key = ?',
        whereArgs: [documentId, key],
      );

  Future<void> markCompleted(String documentId, String key) => _db.update(
        'stages',
        {'status': StageStatus.completed.name, 'progress': 1.0, 'finished_at': _now()},
        where: 'document_id = ? AND stage_key = ?',
        whereArgs: [documentId, key],
      );

  Future<void> markFailed(String documentId, String key, String error) => _db.update(
        'stages',
        {'status': StageStatus.failed.name, 'error': error, 'finished_at': _now()},
        where: 'document_id = ? AND stage_key = ?',
        whereArgs: [documentId, key],
      );

  Future<void> markPaused(String documentId) => _db.update(
        'stages',
        {'status': StageStatus.paused.name},
        where: 'document_id = ? AND status = ?',
        whereArgs: [documentId, StageStatus.running.name],
      );

  /// Re-run a stage from scratch (manual retry): clears its chunks and state.
  Future<void> resetStage(String documentId, String key) async {
    await _db.transaction((txn) async {
      await txn.delete('chunks',
          where: 'document_id = ? AND stage_key = ?', whereArgs: [documentId, key]);
      await txn.update(
        'stages',
        {
          'status': StageStatus.pending.name,
          'progress': 0.0,
          'error': null,
          'started_at': null,
          'finished_at': null,
        },
        where: 'document_id = ? AND stage_key = ?',
        whereArgs: [documentId, key],
      );
    });
  }

  // ---- chunk checkpoints (resume inside a stage) ----

  Future<void> saveChunk(String documentId, String key, int index, String output) =>
      _db.insert(
        'chunks',
        {
          'document_id': documentId,
          'stage_key': key,
          'chunk_index': index,
          'output': output,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// chunk index -> output, for chunks that already finished.
  Future<Map<int, String>> completedChunks(String documentId, String key) async {
    final rows = await _db.query('chunks',
        where: 'document_id = ? AND stage_key = ?',
        whereArgs: [documentId, key],
        orderBy: 'chunk_index');
    return {for (final r in rows) r['chunk_index'] as int: r['output'] as String};
  }

  /// Call once at app start. Anything left "running" was interrupted
  /// (app closed / killed): mark it paused so it can be resumed.
  Future<int> recoverInterrupted() async {
    final stagesFixed = await _db.update(
      'stages',
      {'status': StageStatus.paused.name},
      where: 'status = ?',
      whereArgs: [StageStatus.running.name],
    );
    await _db.update(
      'documents',
      {'status': DocStatus.paused.name},
      where: 'status = ?',
      whereArgs: [DocStatus.processing.name],
    );
    return stagesFixed;
  }

  /// Stage had nothing to do (e.g. no scanned pages for OCR).
  Future<void> markSkipped(String documentId, String key) => _db.update(
        'stages',
        {'status': StageStatus.skipped.name, 'progress': 1.0, 'finished_at': _now()},
        where: 'document_id = ? AND stage_key = ?',
        whereArgs: [documentId, key],
      );
}
