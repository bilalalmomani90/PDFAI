import 'dart:io';
import 'dart:math';
import 'enums.dart';
import 'file_store.dart';
import 'models.dart';
import 'repositories/documents_repository.dart';

/// Import / delete a PDF (file copy + database record together).
class LibraryService {
  LibraryService(this._documents, this._files);
  final DocumentsRepository _documents;
  final FileStore _files;

  static String newId() {
    final r = Random.secure();
    final suffix = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$suffix';
  }

  Future<PdfRecord> importPdf(File source, {required String name}) async {
    if (!await _looksLikePdf(source)) {
      throw const FormatException('Not a PDF file');
    }
    final id = newId();
    final size = await source.length();
    await _files.importFile(source, id);
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = PdfRecord(
      id: id,
      name: name,
      sizeBytes: size,
      status: DocStatus.imported,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _documents.create(record);
    } catch (_) {
      await _files.delete(id); // do not leave an orphan file
      rethrow;
    }
    return record;
  }

  Future<void> delete(String id) async {
    await _documents.delete(id);
    await _files.delete(id);
  }

  String pathOf(String id) => _files.pathFor(id);

  static Future<bool> _looksLikePdf(File f) async {
    final raf = await f.open();
    try {
      final head = await raf.read(1024);
      return String.fromCharCodes(head).contains('%PDF-');
    } finally {
      await raf.close();
    }
  }
}
