import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/enums.dart';
import '../../data/models.dart';
import '../../data/repositories/documents_repository.dart';
import '../../data/repositories/pipeline_repository.dart';
import '../../data/repositories/results_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../cancel_token.dart';
import '../pdf/pdf_reader.dart';
import '../pdf/text_cleaner.dart';
import 'ocr_engine.dart';

class OcrSummary {
  OcrSummary({
    required this.attempted,
    required this.recognized,
    required this.blank,
    required this.failed,
    this.cancelled = false,
  });

  final int attempted; // pages that were pending when the run started
  final int recognized; // pages with recognized text
  final int blank; // pages where no text was found
  final int failed; // pages that errored (stay pending, retried next run)
  final bool cancelled;

  Map<String, Object?> toJson() => {
        'attempted': attempted,
        'recognized': recognized,
        'blank': blank,
        'failed': failed,
      };
}

/// OCR for pages marked `pendingOcr`. Each page is saved as soon as it is
/// done, so pause/resume just continues with the pages still pending.
class OcrService {
  OcrService({
    required this.documents,
    required this.pipeline,
    required this.results,
    required this.settings,
    required this.engine,
  });

  final DocumentsRepository documents;
  final PipelineRepository pipeline;
  final ResultsRepository results;
  final SettingsRepository settings;
  final OcrEngine engine;

  static const stageKey = 'ocr';
  static const reportKey = 'ocr_report';
  static const defaultLanguages = 'ara+eng';

  Future<OcrSummary> run({
    required String documentId,
    required String filePath,
    CancelToken? cancel,
    void Function(int done, int total)? onProgress,
  }) async {
    final pending = await documents.pendingOcrPageNumbers(documentId);
    await pipeline.initStages(documentId, [stageKey]);

    if (pending.isEmpty) {
      await pipeline.markSkipped(documentId, stageKey);
      return OcrSummary(attempted: 0, recognized: 0, blank: 0, failed: 0);
    }

    final language = await settings.get(SettingsKeys.ocrLanguages) ?? defaultLanguages;
    final missing = await engine.missingModels(language);
    if (missing.isNotEmpty) throw OcrUnavailableException(missing);

    await pipeline.markRunning(documentId, stageKey);

    final PdfReader reader;
    try {
      reader = await PdfReader.open(filePath);
    } on PdfReadException catch (e) {
      await pipeline.markFailed(documentId, stageKey, e.message);
      rethrow;
    }

    var recognized = 0, blank = 0, failed = 0, processed = 0;
    Object? lastError;

    try {
      final tmp = await getTemporaryDirectory();
      onProgress?.call(0, pending.length);

      for (final n in pending) {
        if (cancel != null && cancel.isCancelled) {
          await pipeline.markPaused(documentId);
          return OcrSummary(
            attempted: pending.length,
            recognized: recognized,
            blank: blank,
            failed: failed,
            cancelled: true,
          );
        }

        final file = File(p.join(tmp.path, 'ocr_${documentId}_$n.png'));
        try {
          final png = await reader.renderPagePng(n);
          await file.writeAsBytes(png, flush: true);
          final raw = await engine.recognize(file.path, language: language);
          final cleaned = TextCleaner.clean(raw.replaceAll('\f', ''));
          // Saved as `ocr` even when empty (a blank page) so it is not retried forever.
          await documents.savePage(PageText(
            documentId: documentId,
            pageNumber: n,
            text: cleaned,
            method: PageMethod.ocr,
          ));
          if (TextCleaner.meaningfulChars(cleaned) > 0) {
            recognized++;
          } else {
            blank++;
          }
        } catch (e) {
          failed++;
          lastError = e; // page stays pendingOcr and is retried on the next run
        } finally {
          if (await file.exists()) await file.delete();
        }

        processed++;
        await pipeline.updateProgress(documentId, stageKey, processed / pending.length);
        onProgress?.call(processed, pending.length);
        await Future<void>.delayed(Duration.zero);
      }

      // Every page failed -> something is wrong with the engine, not the pages.
      if (failed == pending.length && lastError != null) throw lastError!;

      final summary = OcrSummary(
        attempted: pending.length,
        recognized: recognized,
        blank: blank,
        failed: failed,
      );
      await results.save(documentId, reportKey, summary.toJson());
      if (failed == 0) {
        await pipeline.markCompleted(documentId, stageKey);
      } else {
        await pipeline.markFailed(documentId, stageKey, '$failed page(s) failed');
      }
      return summary;
    } catch (e) {
      await pipeline.markFailed(documentId, stageKey, e.toString());
      rethrow;
    } finally {
      await reader.dispose();
    }
  }
}
