import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// RULES (user data must survive every update):
/// - NEVER edit or reorder an existing entry in [migrations].
/// - To change the schema, APPEND a new entry. The DB version = migrations.length.
/// - Never drop a table that holds user results.
class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static const _fileName = 'pdfai.db';

  /// Each entry is one schema version (index 0 = version 1).
  static const List<List<String>> migrations = [
    // v1
    [
      '''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        page_count INTEGER,
        detected_language TEXT,
        doc_type TEXT,
        topic TEXT,
        target_language TEXT,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )''',
      'CREATE INDEX idx_documents_updated ON documents(updated_at DESC)',
      '''
      CREATE TABLE pages (
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        page_number INTEGER NOT NULL,
        text TEXT NOT NULL,
        method TEXT NOT NULL,
        confidence REAL,
        PRIMARY KEY (document_id, page_number)
      )''',
      '''
      CREATE TABLE stages (
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        stage_key TEXT NOT NULL,
        status TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0,
        attempts INTEGER NOT NULL DEFAULT 0,
        error TEXT,
        started_at INTEGER,
        finished_at INTEGER,
        PRIMARY KEY (document_id, stage_key)
      )''',
      // A row exists only for a COMPLETED chunk -> used to resume mid-stage.
      '''
      CREATE TABLE chunks (
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        stage_key TEXT NOT NULL,
        chunk_index INTEGER NOT NULL,
        output TEXT NOT NULL,
        PRIMARY KEY (document_id, stage_key, chunk_index)
      )''',
      '''
      CREATE TABLE results (
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        result_key TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (document_id, result_key)
      )''',
      '''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''',
    ],
    // v2: keep the original page text before normalization (undo / safe re-run)
    [
      'ALTER TABLE pages ADD COLUMN raw_text TEXT',
    ],
  ];

  /// Pass [path] (e.g. inMemoryDatabasePath) for tests.
  static Future<AppDatabase> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), _fileName);
    final db = await openDatabase(
      dbPath,
      version: migrations.length,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => _apply(db, 0, version),
      onUpgrade: (db, oldVersion, newVersion) => _apply(db, oldVersion, newVersion),
    );
    return AppDatabase._(db);
  }

  static Future<void> _apply(Database db, int from, int to) async {
    for (var v = from; v < to; v++) {
      for (final sql in migrations[v]) {
        await db.execute(sql);
      }
    }
  }

  Future<void> close() => db.close();
}
