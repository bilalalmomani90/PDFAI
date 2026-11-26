import 'arabic_presentation_map.dart';

/// Fixes common problems in Arabic text extracted from PDFs:
/// 1) presentation-form glyphs (e.g. isolated/initial letter shapes) -> base letters
/// 2) tatweel removal
/// 3) text stored in VISUAL order (words/letters reversed) -> logical order
class ArabicNormalizer {
  ArabicNormalizer._();

  static bool _isArabic(int c) =>
      (c >= 0x0600 && c <= 0x06FF) ||
      (c >= 0x0750 && c <= 0x077F) ||
      (c >= 0xFB50 && c <= 0xFDFF) ||
      (c >= 0xFE70 && c <= 0xFEFF);

  static bool hasArabic(String s) {
    for (final r in s.runes) {
      if (_isArabic(r)) return true;
    }
    return false;
  }

  /// Presentation forms -> base letters, and removes tatweel (U+0640).
  static String normalizeForms(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r == 0x0640) continue;
      final m = kArabicPresentationMap[r];
      if (m != null) {
        b.write(m);
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  static String _reverse(String w) => String.fromCharCodes(w.runes.toList().reversed);

  // Frequent, unambiguous words. In visual-order text they appear reversed.
  static const _common = [
    'في', 'من', 'على', 'إلى', 'الى', 'أن', 'هذا', 'هذه', 'التي', 'الذي', 'كان', 'عن',
  ];
  static final _splitter = RegExp(r'[\s\.,;:!\?\(\)\[\]"«»،؛؟\-]+');

  /// Decides, from sample pages, whether the document is stored reversed.
  /// Conservative on purpose: wrong reversal would damage good text.
  static bool looksReversed(Iterable<String> samples) {
    final forward = _common.toSet();
    final backward = _common.map(_reverse).toSet();
    var fwd = 0, rev = 0;
    for (final text in samples) {
      for (final w in text.split(_splitter)) {
        if (w.isEmpty) continue;
        if (forward.contains(w)) fwd++;
        if (backward.contains(w)) rev++;
      }
    }
    return rev >= 8 && rev >= fwd * 3;
  }

  static final _ltrRun = RegExp(r'[A-Za-z0-9][A-Za-z0-9\.,:/\-_%]*');

  /// Visual order -> logical order, line by line. Latin words and numbers
  /// keep their own direction.
  static String fixVisualOrder(String text) =>
      text.split('\n').map(_fixLine).join('\n');

  static String _fixLine(String line) {
    if (!hasArabic(line)) return line;
    return _reverse(line)
        .replaceAllMapped(_ltrRun, (m) => _reverse(m.group(0)!));
  }
}
