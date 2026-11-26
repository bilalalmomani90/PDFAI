import 'dart:math';
import '../../data/enums.dart';
import '../../data/models.dart';
import '../../data/repositories/documents_repository.dart';
import '../../data/repositories/pipeline_repository.dart';
import '../../data/repositories/results_repository.dart';
import '../cancel_token.dart';
import '../pdf/pdf_reader.dart';
import '../text/arabic_normalizer.dart';
import '../text/language_detector.dart';
import 'document_classifier.dart';
import 'structure_splitter.dart';
import 'topic_extractor.dart';

class AnalysisSummary {
  const AnalysisSummary({
    required this.languageCode,
    required this.docType,
    required this.keywords,
    required this.chapterCount,
    required this.reversedFixed,
  });

  final String languageCode;
  final String docType;
  final List<String> keywords;
  final int chapterCount;
  final bool reversedFixed;

  Map<String, Object?> toJson() => {
        'language': languageCode,
        'doc_type': docType,
        'keywords': keywords,
        'chapter_count': chapterCount,
        'reversed_fixed': reversedFixed,
      };

  factory AnalysisSummary.fromJson(Map<String, dynamic> j) => AnalysisSummary(
        languageCode: (j['language'] as String?) ?? 'und',
        docType: (j['doc_type'] as String?) ?? 'general',
        keywords: ((j['keywords'] as List?) ?? const []).map((e) => e.toString()).toList(),
        chapterCount: (j['chapter_count'] as num?)?.toInt() ?? 0,
        reversedFixed: (j['reversed_fixed'] as bool?) ?? false,
      );
}

/// Four small stages, each saved separately (finished ones are skipped on re-run):
/// normalize_text -> detect_language -> classify_document -> split_chapters.
class AnalysisService {
  AnalysisService({
    required this.documents,
    required this.pipeline,
    required this.results,
  });

  final DocumentsRepository documents;
  final PipelineRepository pipeline;
  final ResultsRepository results;

  static const stageNormalize = 'normalize_text';
  static const stageLanguage = 'detect_language';
  static const stageClassify = 'classify_document';
  static const stageStructure = 'split_chapters';
  static const _stages = [stageNormalize, stageLanguage, stageClassify, stageStructure];

  static const keyNormalization = 'normalization_report';
  static const keyLanguage = 'language_report';
  static const keyClassification = 'classification';
  static const keyStructure = 'structure';
  static const keySummary = 'analysis_summary';

  static Future<AnalysisSummary?> loadSummary(ResultsRepository results, String documentId) async {
    final v = await results.get(documentId, keySummary);
    return v is Map ? AnalysisSummary.fromJson(Map<String, dynamic>.from(v)) : null;
  }

  /// Returns null if cancelled before finishing.
  Future<AnalysisSummary?> run({
    required String documentId,
    required String filePath,
    CancelToken? cancel,
    void Function(int done, int total)? onProgress,
  }) async {
    await pipeline.initStages(documentId, _stages);
    final status = {
      for (final s in await pipeline.stages(documentId)) s.stageKey: s.status,
    };
    var done = 0;
    onProgress?.call(0, _stages.length);

    Future<bool> step(String key, Future<void> Function() body) async {
      if (cancel != null && cancel.isCancelled) return false;
      if (status[key] != StageStatus.completed) {
        await pipeline.markRunning(documentId, key);
        try {
          await body();
          await pipeline.markCompleted(documentId, key);
        } catch (e) {
          await pipeline.markFailed(documentId, key, e.toString());
          rethrow;
        }
      }
      done++;
      onProgress?.call(done, _stages.length);
      return true;
    }

    if (!await step(stageNormalize, () => _normalize(documentId))) return null;
    if (!await step(stageLanguage, () => _detectLanguage(documentId))) return null;
    if (!await step(stageClassify, () => _classify(documentId))) return null;
    if (!await step(stageStructure, () => _structure(documentId, filePath))) return null;

    final summary = await _buildSummary(documentId);
    await results.save(documentId, keySummary, summary.toJson());
    return summary;
  }

  // ---- stages ----

  Future<void> _normalize(String id) async {
    // Always computed from the ORIGINAL text (raw_text), so re-running is safe.
    final raws = await documents.rawTexts(id);
    final samples = <String>[];
    for (final e in raws) {
      if (samples.length >= 40) break;
      final t = ArabicNormalizer.normalizeForms(e.value);
      if (ArabicNormalizer.hasArabic(t)) samples.add(t);
    }
    final reversed = ArabicNormalizer.looksReversed(samples);

    var changed = 0;
    for (final e in raws) {
      var t = e.value;
      if (reversed) t = ArabicNormalizer.fixVisualOrder(t);
      t = ArabicNormalizer.normalizeForms(t);
      if (t != e.value) {
        await documents.updatePageText(id, e.key, t);
        changed++;
      }
    }
    await results.save(id, keyNormalization, {
      'pages_changed': changed,
      'reversed_applied': reversed,
    });
  }

  String _sample(List<PageText> pages, {int maxChars = 30000}) {
    final step = max(1, pages.length ~/ 30);
    final b = StringBuffer();
    for (var i = 0; i < pages.length && b.length < maxChars; i += step) {
      b.writeln(pages[i].text);
    }
    return b.toString();
  }

  Future<void> _detectLanguage(String id) async {
    final pages = await documents.pages(id);
    final d = LanguageDetector.detect(_sample(pages));
    await documents.updateMetadata(id, detectedLanguage: d.code);
    await results.save(id, keyLanguage, {
      'primary': d.code,
      'confidence': d.confidence,
      'script_shares': d.scriptShares,
    });
  }

  Future<void> _classify(String id) async {
    final pages = await documents.pages(id);
    final totalChars = pages.fold<int>(0, (a, p) => a + p.text.length);
    final avg = pages.isEmpty ? 0.0 : totalChars / pages.length;
    final langReport = await results.get(id, keyLanguage);
    final lang = langReport is Map ? (langReport['primary'] as String? ?? 'en') : 'en';

    final c = DocumentClassifier.classify(
      sampleText: _sample(pages),
      pageCount: pages.length,
      avgCharsPerPage: avg,
      language: lang,
    );

    final full = StringBuffer();
    for (final p in pages) {
      if (full.length > 200000) break;
      full.writeln(p.text);
    }
    final keywords = TopicExtractor.top(full.toString());

    await documents.updateMetadata(id, docType: c.type, topic: keywords.join(', '));
    await results.save(id, keyClassification, {
      'type': c.type,
      'score': c.score,
      'keywords': keywords,
    });
  }

  Future<void> _structure(String id, String filePath) async {
    final pages = await documents.pages(id);
    var outline = <OutlineEntry>[];
    try {
      final reader = await PdfReader.open(filePath);
      try {
        outline = await reader.outline();
      } finally {
        await reader.dispose();
      }
    } on PdfReadException {
      // no bookmarks available; fall back to headings / fixed parts
    }
    final r = StructureSplitter.split(
      pages: [for (final p in pages) PageLite(p.pageNumber, p.text)],
      outline: outline,
    );
    await results.save(id, keyStructure, r.toJson());
  }

  Future<AnalysisSummary> _buildSummary(String id) async {
    final lang = await results.get(id, keyLanguage);
    final cls = await results.get(id, keyClassification);
    final st = await results.get(id, keyStructure);
    final norm = await results.get(id, keyNormalization);
    return AnalysisSummary(
      languageCode: lang is Map ? (lang['primary'] as String? ?? 'und') : 'und',
      docType: cls is Map ? (cls['type'] as String? ?? 'general') : 'general',
      keywords: cls is Map
          ? ((cls['keywords'] as List?) ?? const []).map((e) => e.toString()).toList()
          : const [],
      chapterCount: st is Map ? ((st['chapters'] as List?)?.length ?? 0) : 0,
      reversedFixed: norm is Map ? (norm['reversed_applied'] as bool? ?? false) : false,
    );
  }
}
