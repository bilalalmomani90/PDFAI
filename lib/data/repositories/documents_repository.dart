import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../enums.dart';
import '../models.dart';

class DocumentsRepository {
  DocumentsRepository(this._d);
  final AppDatabase _d;
  Database get _db => _d.db;

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> create(PdfRecord r) => _db.insert('documents', r.toMap());

  Future<List<PdfRecord>> list() async {
    final rows = await _db.query('documents', orderBy: 'updated_at DESC');
    return rows.map(PdfRecord.fromMap).toList();
  }

  Future<PdfRecord?> get(String id) async {
    final rows = await _db.query('documents', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : PdfRecord.fromMap(rows.first);
  }

  Future<void> setStatus(String id, DocStatus status) => _db.update(
        'documents',
        {'status': status.name, 'updated_at': _now()},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Updates only the non-null fields.
  Future<void> updateMetadata(
    String id, {
    int? pageCount,
    String? detectedLanguage,
    String? docType,
    String? topic,
    String? targetLanguage,
  }) async {
    final values = <String, Object?>{
      if (pageCount != null) 'page_count': pageCount,
      if (detectedLanguage != null) 'detected_language': detectedLanguage,
      if (docType != null) 'doc_type': docType,
      if (topic != null) 'topic': topic,
      if (targetLanguage != null) 'target_language': targetLanguage,
      'updated_at': _now(),
    };
    await _db.update('documents', values, where: 'id = ?', whereArgs: [id]);
  }

  /// Cascades to pages, stages, chunks and results.
  Future<void> delete(String id) =>
      _db.delete('documents', where: 'id = ?', whereArgs: [id]);

  // ---- extracted page text ----

  Future<void> savePage(PageText page) => _db.insert(
        'pages',
        page.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<PageText>> pages(String documentId) async {
    final rows = await _db.query('pages',
        where: 'document_id = ?', whereArgs: [documentId], orderBy: 'page_number');
    return rows.map(PageText.fromMap).toList();
  }

  /// Page numbers already extracted (to resume extraction).
  Future<Set<int>> extractedPageNumbers(String documentId) async {
    final rows = await _db.query('pages',
        columns: ['page_number'], where: 'document_id = ?', whereArgs: [documentId]);
    return rows.map((r) => r['page_number'] as int).toSet();
  }

  /// Number of pages per extraction method (cheap summary, no text loaded).
  Future<Map<PageMethod, int>> pageMethodCounts(String documentId) async {
    final rows = await _db.rawQuery(
      'SELECT method, COUNT(*) AS c FROM pages WHERE document_id = ? GROUP BY method',
      [documentId],
    );
    return {
      for (final r in rows)
        enumByName(PageMethod.values, r['method'] as String?, PageMethod.direct):
            r['c'] as int,
    };
  }
}
