import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class SettingsKeys {
  SettingsKeys._();
  static const locale = 'locale'; // 'ar' | 'en'
  static const targetLanguage = 'target_language'; // translation target
  static const ocrLanguages = 'ocr_languages'; // e.g. 'ara+eng'
}

class SettingsRepository {
  SettingsRepository(this._d);
  final AppDatabase _d;
  Database get _db => _d.db;

  Future<String?> get(String key) async {
    final rows = await _db.query('settings',
        where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> set(String key, String value) => _db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
