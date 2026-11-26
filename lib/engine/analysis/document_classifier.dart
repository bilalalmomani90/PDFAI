class Classification {
  const Classification(this.type, this.score);
  final String type; // academic, book, report, invoice, contract, exam, presentation, manual, general
  final int score;
}

/// Rule-based document type detection (keywords + simple page statistics).
class DocumentClassifier {
  DocumentClassifier._();

  static const _keywords = <String, List<String>>{
    'academic': ['abstract', 'references', 'bibliography', 'doi', 'keywords', 'methodology', 'conclusion', 'et al', 'ملخص', 'المراجع', 'مراجع', 'الكلمات المفتاحية', 'منهجية', 'خاتمة', 'دراسة', 'بحث'],
    'book': ['table of contents', 'contents', 'chapter', 'preface', 'foreword', 'isbn', 'الفهرس', 'المحتويات', 'فهرس', 'الفصل', 'مقدمة', 'الباب'],
    'report': ['executive summary', 'report', 'findings', 'recommendations', 'analysis', 'quarter', 'التقرير', 'تقرير', 'ملخص تنفيذي', 'التوصيات', 'النتائج', 'تحليل'],
    'invoice': ['invoice', 'bill to', 'subtotal', 'total due', 'vat', 'tax', 'amount', 'qty', 'unit price', 'فاتورة', 'المجموع', 'الضريبة', 'الكمية', 'سعر الوحدة', 'المبلغ'],
    'contract': ['agreement', 'hereinafter', 'party', 'parties', 'whereas', 'termination', 'governing law', 'عقد', 'اتفاقية', 'الطرف الأول', 'الطرف الثاني', 'البند', 'يلتزم', 'شروط'],
    'exam': ['question', 'answer', 'marks', 'choose the correct', 'true or false', 'exam', 'quiz', 'سؤال', 'اختر', 'الإجابة', 'درجة', 'امتحان', 'اختبار', 'صح أو خطأ'],
    'presentation': ['agenda', 'slide', 'thank you', 'جدول الأعمال', 'شكرا'],
    'manual': ['user manual', 'installation', 'troubleshooting', 'warning', 'step', 'دليل', 'تعليمات', 'تركيب', 'تحذير'],
  };

  static final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static Classification classify({
    required String sampleText,
    required int pageCount,
    required double avgCharsPerPage,
    String language = 'en',
  }) {
    final padded = ' ${sampleText.toLowerCase().replaceAll(_nonWord, ' ')} ';
    final scores = <String, int>{};
    _keywords.forEach((type, words) {
      scores[type] = words.where((w) => padded.contains(' $w ')).length;
    });

    if (pageCount >= 5 && avgCharsPerPage > 0 && avgCharsPerPage < 700) {
      scores['presentation'] = (scores['presentation'] ?? 0) + 3;
    }
    if (pageCount >= 60) scores['book'] = (scores['book'] ?? 0) + 2;

    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value < 2) return const Classification('general', 0);
    return Classification(best.key, best.value);
  }
}
