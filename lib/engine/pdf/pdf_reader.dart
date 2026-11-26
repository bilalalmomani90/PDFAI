import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as imglib;
import 'package:pdfrx/pdfrx.dart';
import '../analysis/structure_splitter.dart' show OutlineEntry;

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

  /// Renders a page (1-based) to a grayscale PNG for OCR.
  /// ~200 dpi, long side capped at [maxSide] px to protect memory on weak devices.
  Future<Uint8List> renderPagePng(int pageNumber,
      {double dpi = 200, int maxSide = 3000}) async {
    final page = _doc.pages[pageNumber - 1];
    final scale = min(dpi / 72.0, maxSide / max(page.width, page.height));
    final w = max(1, (page.width * scale).round());
    final h = max(1, (page.height * scale).round());

    final dynamic image = await _render(page, w, h);
    try {
      final px = image.pixels as Uint8List; // BGRA, 4 bytes per pixel
      final im = imglib.Image.fromBytes(
        width: image.width as int,
        height: image.height as int,
        bytes: Uint8List.fromList(px).buffer,
        numChannels: 4,
        order: imglib.ChannelOrder.bgra,
      );
      return Uint8List.fromList(imglib.encodePng(imglib.grayscale(im)));
    } finally {
      try {
        image.dispose();
      } catch (_) {}
    }
  }

  /// pdfrx renamed/retyped render()'s size parameters between versions;
  /// try the known variants so this adapter works with any of them.
  Future<dynamic> _render(PdfPage page, int w, int h) async {
    final dynamic p = page;
    final attempts = <Map<Symbol, dynamic>>[
      {#width: w, #height: h},
      {#width: w.toDouble(), #height: h.toDouble()},
      {#fullWidth: w.toDouble(), #fullHeight: h.toDouble()},
      {#fullWidth: w, #fullHeight: h},
    ];
    Object? last;
    for (final a in attempts) {
      try {
        return await Function.apply(p.render, const [], a);
      } on NoSuchMethodError catch (e) {
        last = e;
      } on TypeError catch (e) {
        last = e;
      }
    }
    throw PdfReadException('Could not render page: $last');
  }

  /// The PDF's bookmarks (table of contents). Empty if none / unsupported.
  Future<List<OutlineEntry>> outline() async {
    try {
      final dynamic nodes = await (_doc as dynamic).loadOutline();
      final out = <OutlineEntry>[];
      void walk(dynamic list, int level) {
        if (list == null) return;
        for (final dynamic n in list) {
          final title = (n.title as String?) ?? '';
          int? page;
          try {
            page = n.dest?.pageNumber as int?;
          } catch (_) {}
          out.add(OutlineEntry(title, page, level));
          walk(n.children, level + 1);
        }
      }

      walk(nodes, 1);
      return out;
    } catch (_) {
      return const [];
    }
  }
}
