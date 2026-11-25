import 'package:pdfrx/pdfrx.dart';

class PdfReadException implements Exception {
  PdfReadException(this.message, {this.passwordRequired = false});
  final String message;
  final bool passwordRequired;
  @override
  String toString() => message;
}

/// Thin wrapper around pdfrx (PDFium). All pdfrx-version differences are
/// kept in THIS file so the rest of the engine never touches the library.
class PdfReader {
  PdfReader._(this._doc);
  final PdfDocument _doc;

  static Future<PdfReader> open(String path) async {
    try {
      return PdfReader._(await PdfDocument.openFile(path));
    } catch (e) {
      final msg = e.toString();
      throw PdfReadException(
        msg,
        passwordRequired: msg.toLowerCase().contains('password'),
      );
    }
  }

  int get pageCount => _doc.pages.length;

  /// Raw text of a page (1-based). Empty string if the page has no text.
  Future<String> pageText(int pageNumber) async {
    final page = _doc.pages[pageNumber - 1];
    // loadText() returns a String or a PdfPageText depending on pdfrx version.
    final dynamic t = await page.loadText();
    if (t == null) return '';
    if (t is String) return t;
    return (t.fullText as String?) ?? '';
  }

  Future<void> dispose() async {
    try {
      await (_doc as dynamic).dispose();
    } catch (_) {}
  }
}
