import 'package:flutter_test/flutter_test.dart';
import 'package:app/engine/analysis/document_classifier.dart';
import 'package:app/engine/analysis/structure_splitter.dart';
import 'package:app/engine/analysis/topic_extractor.dart';
import 'package:app/engine/text/arabic_normalizer.dart';
import 'package:app/engine/text/language_detector.dart';

String rev(String s) => String.fromCharCodes(s.runes.toList().reversed);

void main() {
  group('LanguageDetector', () {
    test('arabic', () {
      final d = LanguageDetector.detect(
          'هذا النص مكتوب باللغة العربية وهو يحتوي على كلمات كثيرة في هذا المستند');
      expect(d.code, 'ar');
    });
    test('english', () {
      final d = LanguageDetector.detect(
          'This is a simple English sentence that contains many common words for the detector');
      expect(d.code, 'en');
    });
    test('persian', () {
      final d = LanguageDetector.detect(
          'این یک متن فارسی است که شامل حروف پ چ ژ گ و کلمات زیادی می‌باشد و گفتگو');
      expect(d.code, 'fa');
    });
    test('french', () {
      final d = LanguageDetector.detect(
          'Le chat est dans la maison et les enfants sont dans le jardin avec une balle');
      expect(d.code, 'fr');
    });
    test('too short is undetermined', () {
      expect(LanguageDetector.detect('hi').code, 'und');
    });
  });

  group('ArabicNormalizer', () {
    test('expands lam-alef ligature and removes tatweel', () {
      expect(ArabicNormalizer.normalizeForms(String.fromCharCode(0xFEFB)), 'لا');
      expect(ArabicNormalizer.normalizeForms('كتـاب'), 'كتاب');
    });
    test('detects reversed text only when clearly reversed', () {
      const sentence = 'ذهب الولد في الصباح إلى المدرسة من البيت على الطريق هذا كان ';
      final forward = List.filled(10, sentence).join();
      expect(ArabicNormalizer.looksReversed([forward]), isFalse);
      expect(ArabicNormalizer.looksReversed([rev(forward)]), isTrue);
    });
    test('fixes visual order and keeps numbers readable', () {
      expect(ArabicNormalizer.fixVisualOrder('2024 مولاعلاب ابحرم'), 'مرحبا بالعالم 2024');
    });
  });

  group('DocumentClassifier / TopicExtractor', () {
    test('invoice', () {
      final c = DocumentClassifier.classify(
        sampleText: 'Invoice subtotal VAT total due amount',
        pageCount: 1,
        avgCharsPerPage: 500,
      );
      expect(c.type, 'invoice');
    });
    test('general when no signal', () {
      final c = DocumentClassifier.classify(
        sampleText: 'hello world',
        pageCount: 2,
        avgCharsPerPage: 2000,
      );
      expect(c.type, 'general');
    });
    test('top keywords', () {
      final k = TopicExtractor.top('database database database indexing indexing query');
      expect(k.first, 'database');
    });
  });

  group('StructureSplitter', () {
    test('headings', () {
      final pages = [
        const PageLite(1, 'Chapter 1 Introduction\nbody text'),
        const PageLite(2, 'more body'),
        const PageLite(3, 'Chapter 2 Methods\nbody'),
        const PageLite(4, 'more'),
        const PageLite(5, 'Chapter 3 Results\nbody'),
        const PageLite(6, 'end'),
      ];
      final r = StructureSplitter.split(pages: pages, outline: const []);
      expect(r.source, 'headings');
      expect(r.chapters.length, 3);
      expect(r.chapters[0].endPage, 2);
      expect(r.chapters[2].endPage, 6);
    });
    test('outline wins', () {
      final pages = [for (var i = 1; i <= 6; i++) PageLite(i, 'text')];
      final r = StructureSplitter.split(pages: pages, outline: const [
        OutlineEntry('A', 1, 1),
        OutlineEntry('B', 4, 1),
      ]);
      expect(r.source, 'outline');
      expect(r.chapters[0].endPage, 3);
    });
    test('fixed parts fallback', () {
      final pages = [for (var i = 1; i <= 4; i++) PageLite(i, 'x' * 5000)];
      final r = StructureSplitter.split(pages: pages, outline: const []);
      expect(r.source, 'fixed');
      expect(r.chapters.length, 2);
    });
  });
}
