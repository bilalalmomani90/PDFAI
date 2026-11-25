import '../../data/enums.dart';
import '../../data/models.dart';
import '../../data/repositories/documents_repository.dart';
import '../../data/repositories/pipeline_repository.dart';
import '../../data/repositories/results_repository.dart';
import '../cancel_token.dart';
import 'pdf_reader.dart';
import 'text_cleaner.dart';

class ExtractionSummary {
  ExtractionSummary({
    required this.totalPages,
    required this.directPages,
    required this.pendingOcrPages,
    required this.failedReads,
    this.cancelled = false,
  });

  final int totalPages;
  final int directPages; // pages whose text was read directly
  final int pendingOcrPages; // scanned / image-only pages that need OCR
  final int failedReads; // pages that threw an error while reading (this run)
  final bool cancelled;

  Map<String, Object?> toJson() => {
        'total_pages': totalPages,
        'direct_pages': directPages,
        'pending_ocr_pages': pendingOcrPages,
        'failed_reads': failedReads,
      };

  factory ExtractionSummary.fromJson(Map<String, dynamic> j) => ExtractionSummary(
        totalPages: (j['total_pages'] as num?)?.toInt() ?? 0,
        directPages: (j['direct_pages'] as num?)?.toInt() ?? 0,
        pendingOcrPages: (j['pending_ocr_pages'] as num?)?.toInt() ?? 0,
        failedReads: (j['failed_reads'] as num?)?.toInt() ?? 0,
      );
}

/// Reads a PDF page by page, saves each page as soon as it is done, and can
/// be stopped and resumed (already-saved pages are skipped).
class TextExtractionService {
  TextExtractionService({
    required this.documents,
    required this.pipeline,
    required this.results,
  });

  final DocumentsRepository documents;
  final PipelineRepository pipeline;
  final ResultsRepository results;

  static const stageKey = 'extract_text';
  static const reportKey = 'extraction_report';

  /// A page with fewer non-whitespace characters is treated as image-only.
  static const minMeaningfulChars = 20;

  Future<ExtractionSummary> run({
    required String documentId,
    required String filePath,
    CancelToken? cancel,
    void Function(int done, int total)? onProgress,
  }) async {
    await pipeline.initStages(documentId, [stageKey]);
    await pipeline.markRunning(documentId, stageKey);

    final PdfReader reader;
    try {
      reader = await PdfReader.open(filePath);
    } on PdfReadException catch (e) {
      await pipeline.markFailed(documentId, stageKey, e.message);
      rethrow;
    }

    var failedReads = 0;
    try {
      final total = reader.pageCount;
      await documents.updateMetadata(documentId, pageCount: total);
      final done = await documents.extractedPageNumbers(documentId);
      var processed = done.length;
      onProgress?.call(processed, total);

      for (var n = 1; n <= total; n++) {
        if (done.contains(n)) continue;

        if (cancel != null && cancel.isCancelled) {
          await pipeline.markPaused(documentId);
          return _summary(documentId, total, failedReads, cancelled: true);
        }

        var raw = '';
        try {
          raw = await reader.pageText(n);
        } catch (_) {
          failedReads++;
        }
        final cleaned = TextCleaner.clean(raw);
        final method = TextCleaner.meaningfulChars(cleaned) >= minMeaningfulChars
            ? PageMethod.direct
            : PageMethod.pendingOcr;

        await documents.savePage(PageText(
          documentId: documentId,
          pageNumber: n,
          text: cleaned,
          method: method,
        ));

        processed++;
        await pipeline.updateProgress(
            documentId, stageKey, total == 0 ? 1.0 : processed / total);
        onProgress?.call(processed, total);
        await Future<void>.delayed(Duration.zero); // keep the UI responsive
      }

      final summary = await _summary(documentId, total, failedReads);
      await results.save(documentId, reportKey, summary.toJson());
      await pipeline.markCompleted(documentId, stageKey);
      return summary;
    } catch (e) {
      await pipeline.markFailed(documentId, stageKey, e.toString());
      rethrow;
    } finally {
      await reader.dispose();
    }
  }

  Future<ExtractionSummary> _summary(String documentId, int total, int failedReads,
      {bool cancelled = false}) async {
    final counts = await documents.pageMethodCounts(documentId);
    return ExtractionSummary(
      totalPages: total,
      directPages: counts[PageMethod.direct] ?? 0,
      pendingOcrPages: counts[PageMethod.pendingOcr] ?? 0,
      failedReads: failedReads,
      cancelled: cancelled,
    );
  }
}
