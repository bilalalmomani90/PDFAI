import 'package:flutter/material.dart';

/// Lightweight localization (ar / en). Can be migrated to ARB later.
class AppStrings {
  AppStrings(this.locale);
  final Locale locale;

  static const supportedLocales = [Locale('ar'), Locale('en')];

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  static const LocalizationsDelegate<AppStrings> delegate = _Delegate();

  bool get _ar => locale.languageCode == 'ar';

  static const _values = <String, Map<String, String>>{
    'ar': {
      'appName': 'PDFAI',
      'tagline': 'معالجة شاملة لملفات PDF بضغطة واحدة',
      'emptyTitle': 'لا توجد ملفات بعد',
      'emptyBody': 'اختر ملف PDF لتبدأ، وستظهر هنا ملفاتك ونتائجها المحفوظة.',
      'switchLanguage': 'English',
      'pickPdf': 'اختيار ملف PDF',
      'importing': 'جارٍ استيراد الملف…',
      'notValidPdf': 'هذا الملف ليس PDF صالحاً.',
      'importFailed': 'تعذّر استيراد الملف.',
      'yourFiles': 'ملفاتك',
      'extractText': 'استخراج النص',
      'resumeExtraction': 'استكمال الاستخراج',
      'pauseExtraction': 'إيقاف مؤقت',
      'extractionDone': 'اكتمل استخراج النص',
      'passwordProtected': 'الملف محمي بكلمة مرور ولا يمكن فتحه حالياً.',
      'extractionFailed': 'تعذّر استخراج النص من هذا الملف.',
      'retry': 'إعادة المحاولة',
      'deleteFile': 'حذف الملف',
      'deleteConfirm': 'سيُحذف الملف وجميع نتائجه المحفوظة. هل أنت متأكد؟',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'ocrFailed': 'تعذّر تشغيل OCR على هذا الملف.',
    },
    'en': {
      'appName': 'PDFAI',
      'tagline': 'Full PDF processing in one tap',
      'emptyTitle': 'No files yet',
      'emptyBody': 'Choose a PDF to start. Your files and saved results will appear here.',
      'switchLanguage': 'العربية',
      'pickPdf': 'Choose a PDF',
      'importing': 'Importing…',
      'notValidPdf': 'This is not a valid PDF file.',
      'importFailed': "Couldn't import the file.",
      'yourFiles': 'Your files',
      'extractText': 'Extract text',
      'resumeExtraction': 'Resume extraction',
      'pauseExtraction': 'Pause',
      'extractionDone': 'Text extraction complete',
      'passwordProtected': 'This file is password-protected and cannot be opened yet.',
      'extractionFailed': "Couldn't extract text from this file.",
      'retry': 'Try again',
      'deleteFile': 'Delete file',
      'deleteConfirm': 'The file and all its saved results will be deleted. Are you sure?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'ocrFailed': "OCR couldn't run on this file.",
    },
  };

  String _t(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;

  String get appName => _t('appName');
  String get tagline => _t('tagline');
  String get emptyTitle => _t('emptyTitle');
  String get emptyBody => _t('emptyBody');
  String get switchLanguage => _t('switchLanguage');
  String get pickPdf => _t('pickPdf');
  String get importing => _t('importing');
  String get notValidPdf => _t('notValidPdf');
  String get importFailed => _t('importFailed');
  String get yourFiles => _t('yourFiles');
  String get extractText => _t('extractText');
  String get resumeExtraction => _t('resumeExtraction');
  String get pauseExtraction => _t('pauseExtraction');
  String get extractionDone => _t('extractionDone');
  String get passwordProtected => _t('passwordProtected');
  String get extractionFailed => _t('extractionFailed');
  String get retry => _t('retry');
  String get deleteFile => _t('deleteFile');
  String get deleteConfirm => _t('deleteConfirm');
  String get cancel => _t('cancel');
  String get delete => _t('delete');
  String get ocrFailed => _t('ocrFailed');

  String runOcr(int n) =>
      _ar ? 'تشغيل OCR على ${pagesLabel(n)}' : 'Run OCR on ${pagesLabel(n)}';

  String ocrRunning(int done, int total) => _ar
      ? 'جارٍ التعرّف على النص: $done من $total'
      : 'Recognizing text: $done of $total';

  String ocrPages(int n) => _ar ? 'صفحات تم التعرّف عليها (OCR): $n' : 'OCR pages: $n';

  String ocrFailedPages(int n) =>
      _ar ? 'صفحات فشل OCR فيها: $n' : 'Pages where OCR failed: $n';

  String ocrModelsMissing(List<String> names) => _ar
      ? 'نماذج OCR غير موجودة: ${names.join('، ')}. أضف ملفاتها إلى assets/tessdata ثم أعد بناء التطبيق.'
      : 'OCR models missing: ${names.join(', ')}. Add them to assets/tessdata and rebuild the app.';

  String get analyzeDocument => _ar ? 'تحليل المستند' : 'Analyze document';
  String get analysisFailed =>
      _ar ? 'تعذّر تحليل المستند.' : "Couldn't analyze the document.";
  String analyzing(int done, int total) =>
      _ar ? 'جارٍ التحليل: $done من $total' : 'Analyzing: $done of $total';
  String get analysisTitle => _ar ? 'تحليل المستند' : 'Document analysis';
  String languageLine(String code) =>
      _ar ? 'اللغة: ${languageName(code)}' : 'Language: ${languageName(code)}';
  String typeLine(String type) =>
      _ar ? 'النوع: ${docTypeName(type)}' : 'Type: ${docTypeName(type)}';
  String topicLine(List<String> k) => _ar
      ? 'أبرز الموضوعات: ${k.join('، ')}'
      : 'Main topics: ${k.join(', ')}';
  String chaptersLine(int n) =>
      _ar ? 'الفصول والأقسام: $n' : 'Chapters / parts: $n';
  String get reversedFixedLine => _ar
      ? 'تم تصحيح ترتيب النص العربي المعكوس.'
      : 'Reversed Arabic text order was corrected.';

  String languageName(String code) {
    const ar = {
      'ar': 'العربية', 'fa': 'الفارسية', 'ur': 'الأردية', 'en': 'الإنجليزية',
      'fr': 'الفرنسية', 'es': 'الإسبانية', 'de': 'الألمانية', 'it': 'الإيطالية',
      'pt': 'البرتغالية', 'tr': 'التركية', 'ru': 'الروسية', 'he': 'العبرية',
      'hi': 'الهندية', 'zh': 'الصينية', 'ja': 'اليابانية', 'ko': 'الكورية',
      'el': 'اليونانية',
    };
    const en = {
      'ar': 'Arabic', 'fa': 'Persian', 'ur': 'Urdu', 'en': 'English',
      'fr': 'French', 'es': 'Spanish', 'de': 'German', 'it': 'Italian',
      'pt': 'Portuguese', 'tr': 'Turkish', 'ru': 'Russian', 'he': 'Hebrew',
      'hi': 'Hindi', 'zh': 'Chinese', 'ja': 'Japanese', 'ko': 'Korean',
      'el': 'Greek',
    };
    return (_ar ? ar : en)[code] ?? (_ar ? 'غير محددة' : 'Unknown');
  }

  String docTypeName(String type) {
    const ar = {
      'academic': 'بحث أكاديمي', 'book': 'كتاب', 'report': 'تقرير',
      'invoice': 'فاتورة', 'contract': 'عقد', 'exam': 'اختبار',
      'presentation': 'عرض تقديمي', 'manual': 'دليل استخدام',
    };
    const en = {
      'academic': 'Academic paper', 'book': 'Book', 'report': 'Report',
      'invoice': 'Invoice', 'contract': 'Contract', 'exam': 'Exam',
      'presentation': 'Presentation', 'manual': 'Manual',
    };
    return (_ar ? ar : en)[type] ?? (_ar ? 'مستند عام' : 'General document');
  }

  String pagesLabel(int n) {
    if (!_ar) return n == 1 ? '1 page' : '$n pages';
    if (n == 1) return 'صفحة واحدة';
    if (n == 2) return 'صفحتان';
    if (n >= 3 && n <= 10) return '$n صفحات';
    return '$n صفحة';
  }

  String extracting(int done, int total) => _ar
      ? 'جارٍ الاستخراج: $done من $total'
      : 'Extracting: $done of $total';

  String textPages(int n) => _ar ? 'صفحات نصية: $n' : 'Text pages: $n';

  String scannedPages(int n) =>
      _ar ? 'صفحات مصوّرة تحتاج OCR: $n' : 'Scanned pages needing OCR: $n';

  String unreadablePages(int n) =>
      _ar ? 'صفحات تعذّرت قراءتها: $n' : 'Pages that could not be read: $n';
}

class _Delegate extends LocalizationsDelegate<AppStrings> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) =>
      AppStrings.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
