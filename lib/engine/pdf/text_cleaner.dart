/// Basic cleanup of text extracted from a PDF page.
/// (Arabic-specific normalization is added later, after testing real files.)
class TextCleaner {
  TextCleaner._();

  // zero-width space, LRM/RLM, bidi embedding/isolate controls, BOM, NUL, U+FFFD
  static final _invisible = RegExp(
      '[\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF\u0000\uFFFD]');
  static final _spaces = RegExp('[ \t\u00A0]+');
  static final _manyBlankLines = RegExp('\n{3,}');
  static final _whitespace = RegExp(r'\s');

  static String clean(String input) {
    var t = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    t = t.replaceAll(_invisible, '');
    t = t.replaceAll(_spaces, ' ');
    t = t.split('\n').map((l) => l.trim()).join('\n');
    t = t.replaceAll(_manyBlankLines, '\n\n');
    return t.trim();
  }

  /// Characters that are not whitespace.
  static int meaningfulChars(String s) => s.replaceAll(_whitespace, '').length;
}
