/// Frequency-based keywords (no AI model). A better topic name can be produced
/// later by a local LLM on devices that can run one.
class TopicExtractor {
  TopicExtractor._();

  static const _arStop = {
    'في', 'من', 'على', 'إلى', 'الى', 'عن', 'أن', 'إن', 'ان', 'هذا', 'هذه', 'ذلك', 'تلك', 'التي',
    'الذي', 'الذين', 'كان', 'كانت', 'يكون', 'ما', 'لا', 'لم', 'لن', 'قد', 'كل', 'بعد', 'قبل', 'بين',
    'مع', 'او', 'أو', 'ثم', 'حتى', 'عند', 'هو', 'هي', 'هم', 'نحن', 'كما', 'إذا', 'اذا', 'لكن',
    'حيث', 'أي', 'اي', 'بها', 'به', 'له', 'لها', 'لهم', 'فيه', 'فيها', 'منه', 'منها', 'عليه', 'عليها',
    'ايضا', 'أيضا', 'غير', 'دون', 'منذ', 'خلال', 'عبر', 'ضمن', 'كذلك', 'فقط', 'وقد', 'وهو', 'وهي',
  };
  static const _enStop = {
    'the', 'and', 'that', 'for', 'with', 'this', 'are', 'from', 'was', 'were', 'have', 'has', 'had',
    'but', 'which', 'their', 'they', 'can', 'will', 'been', 'not', 'also', 'such', 'than', 'then',
    'there', 'these', 'those', 'into', 'about', 'more', 'other', 'when', 'what', 'where', 'who',
    'its', 'may', 'would', 'could', 'should', 'each', 'some', 'any', 'all', 'one', 'two',
  };

  static final _word = RegExp(r'\p{L}+', unicode: true);
  static final _marks = RegExp('[\u064B-\u065F\u0670\u0640]');

  static String _arKey(String w) {
    var k = w
        .replaceAll(_marks, '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
    if (k.length > 5 && k.startsWith('وال')) k = k.substring(3);
    if (k.length > 4 && k.startsWith('ال')) k = k.substring(2);
    return k;
  }

  static bool _isArabic(String w) {
    final c = w.runes.first;
    return c >= 0x0600 && c <= 0x06FF;
  }

  /// Top [n] keywords, each seen at least twice.
  static List<String> top(String text, {int n = 6}) {
    final counts = <String, int>{};
    final surfaces = <String, Map<String, int>>{};

    for (final m in _word.allMatches(text)) {
      final raw = m.group(0)!;
      final lower = raw.toLowerCase();
      final String key;
      if (_isArabic(raw)) {
        if (_arStop.contains(raw)) continue;
        key = _arKey(raw);
        if (key.length < 3 || _arStop.contains(key)) continue;
      } else {
        if (lower.length < 4 || _enStop.contains(lower)) continue;
        key = lower;
      }
      counts[key] = (counts[key] ?? 0) + 1;
      final s = surfaces.putIfAbsent(key, () => {});
      s[lower] = (s[lower] ?? 0) + 1;
    }

    final ranked = counts.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(n).map((e) {
      final forms = surfaces[e.key]!.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return forms.first.key;
    }).toList();
  }
}
