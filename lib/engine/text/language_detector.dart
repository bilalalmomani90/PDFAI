class DetectedLanguage {
  const DetectedLanguage(this.code, this.confidence, this.scriptShares);
  final String code; // 'ar', 'en', ... or 'und'
  final double confidence; // 0..1 (rough)
  final Map<String, double> scriptShares;
}

/// Offline, dependency-free detector: script analysis + marker letters
/// (ar / fa / ur) + stop-word scoring for Latin-script languages.
/// Can be replaced by ML Kit behind the same call if more languages are needed.
class LanguageDetector {
  LanguageDetector._();

  static const _persianMarkers = {0x06CC, 0x06A9, 0x067E, 0x0686, 0x0698, 0x06AF};
  static const _urduMarkers = {0x0679, 0x0688, 0x0691, 0x06BA, 0x06D2, 0x06BE, 0x06C1};

  static const _stopwords = <String, List<String>>{
    'en': ['the', 'and', 'of', 'to', 'in', 'is', 'that', 'for', 'with', 'as', 'on', 'by', 'this', 'are', 'from', 'or', 'an', 'at', 'be', 'was', 'it'],
    'fr': ['le', 'la', 'les', 'de', 'des', 'du', 'et', 'en', 'un', 'une', 'est', 'que', 'pour', 'dans', 'qui', 'pas', 'sur', 'avec', 'au', 'aux', 'par'],
    'es': ['el', 'la', 'los', 'las', 'de', 'del', 'y', 'en', 'un', 'una', 'es', 'que', 'por', 'con', 'para', 'se', 'su', 'al', 'como', 'más'],
    'de': ['der', 'die', 'das', 'und', 'ist', 'nicht', 'ein', 'eine', 'zu', 'von', 'mit', 'den', 'dem', 'auf', 'für', 'auch', 'sich'],
    'it': ['il', 'lo', 'gli', 'di', 'che', 'un', 'una', 'è', 'per', 'con', 'non', 'in', 'da', 'sono', 'come', 'della', 'del'],
    'pt': ['os', 'as', 'de', 'do', 'da', 'dos', 'das', 'em', 'um', 'uma', 'que', 'para', 'com', 'não', 'por', 'mais'],
    'tr': ['ve', 'bir', 'bu', 'için', 'ile', 'de', 'da', 'çok', 'daha', 'gibi', 'olarak', 'ise', 'ne', 'en'],
  };

  static String? _script(int r) {
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A) || (r >= 0xC0 && r <= 0x24F)) {
      return 'latin';
    }
    if ((r >= 0x621 && r <= 0x64A) ||
        (r >= 0x671 && r <= 0x6D3) ||
        (r >= 0x6FA && r <= 0x6FF) ||
        (r >= 0x750 && r <= 0x77F) ||
        (r >= 0xFB50 && r <= 0xFDFF) ||
        (r >= 0xFE70 && r <= 0xFEFF)) {
      return 'arabic';
    }
    if (r >= 0x400 && r <= 0x4FF) return 'cyrillic';
    if (r >= 0x5D0 && r <= 0x5EA) return 'hebrew';
    if (r >= 0x370 && r <= 0x3FF) return 'greek';
    if (r >= 0x900 && r <= 0x97F) return 'devanagari';
    if (r >= 0xAC00 && r <= 0xD7AF) return 'hangul';
    if (r >= 0x3040 && r <= 0x30FF) return 'kana';
    if (r >= 0x4E00 && r <= 0x9FFF) return 'han';
    return null;
  }

  static DetectedLanguage detect(String text) {
    final counts = <String, int>{};
    var total = 0, persian = 0, arabicSpecific = 0, urdu = 0;

    final sample = text.length > 30000 ? text.substring(0, 30000) : text;
    for (final r in sample.runes) {
      final script = _script(r);
      if (script == null) continue;
      counts[script] = (counts[script] ?? 0) + 1;
      total++;
      if (script == 'arabic') {
        if (_persianMarkers.contains(r)) persian++;
        if (_urduMarkers.contains(r)) urdu++;
        if (r == 0x064A || r == 0x0643) arabicSpecific++;
      }
    }
    if (total < 20) return const DetectedLanguage('und', 0, {});

    final shares = {for (final e in counts.entries) e.key: e.value / total};
    final primary = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final share = shares[primary]!;

    switch (primary) {
      case 'arabic':
        if (urdu >= 5 && urdu * 4 >= persian) return DetectedLanguage('ur', share, shares);
        if (persian >= 5 && persian > arabicSpecific * 2) {
          return DetectedLanguage('fa', share, shares);
        }
        return DetectedLanguage('ar', share, shares);
      case 'cyrillic':
        return DetectedLanguage('ru', share, shares);
      case 'hebrew':
        return DetectedLanguage('he', share, shares);
      case 'greek':
        return DetectedLanguage('el', share, shares);
      case 'devanagari':
        return DetectedLanguage('hi', share, shares);
      case 'hangul':
        return DetectedLanguage('ko', share, shares);
      case 'kana':
        return DetectedLanguage('ja', share, shares);
      case 'han':
        return DetectedLanguage((shares['kana'] ?? 0) > 0.05 ? 'ja' : 'zh', share, shares);
      default:
        return _latin(sample, share, shares);
    }
  }

  static DetectedLanguage _latin(String text, double share, Map<String, double> shares) {
    final words = text.toLowerCase().split(RegExp(r'[^a-zà-ÿ]+'));
    final scores = <String, int>{};
    _stopwords.forEach((lang, list) {
      final set = list.toSet();
      scores[lang] = words.where(set.contains).length;
    });
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final sum = scores.values.fold<int>(0, (a, b) => a + b);
    if (best.value < 3) return DetectedLanguage('en', 0.3 * share, shares);
    return DetectedLanguage(best.key, share * best.value / (sum + 1), shares);
  }
}
