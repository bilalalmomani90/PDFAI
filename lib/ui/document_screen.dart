import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core/format.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../data/app_services.dart';
import '../data/enums.dart';
import '../data/models.dart';
import '../engine/analysis/analysis_service.dart';
import '../engine/cancel_token.dart';
import '../engine/ocr/ocr_engine.dart';
import '../engine/ocr/ocr_service.dart';
import '../engine/ocr/tesseract_ocr_engine.dart';
import '../engine/pdf/pdf_reader.dart';
import '../engine/pdf/text_extraction_service.dart';
import 'services_scope.dart';

enum _Phase { loading, idle, running, done, failed }

enum _OcrPhase { idle, running, failed }

enum _AnPhase { idle, running, failed }

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key, required this.documentId});
  final String documentId;

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  // text extraction
  _Phase _phase = _Phase.loading;
  PdfRecord? _record;
  ExtractionSummary? _summary;
  bool _canResume = false;
  int _done = 0;
  int _total = 0;
  bool _passwordError = false;

  // OCR
  _OcrPhase _ocrPhase = _OcrPhase.idle;
  int _ocrDone = 0;
  int _ocrTotal = 0;
  int _ocrFailedPages = 0;
  List<String> _ocrMissing = const [];

  // analysis
  _AnPhase _anPhase = _AnPhase.idle;
  AnalysisSummary? _analysis;
  int _anDone = 0;
  int _anTotal = 4;

  Map<PageMethod, int> _counts = const {};
  CancelToken? _cancel;
  bool _started = false;

  bool get _busy =>
      _phase == _Phase.running ||
      _ocrPhase == _OcrPhase.running ||
      _anPhase == _AnPhase.running;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void dispose() {
    _cancel?.cancel(); // leaving the screen pauses work; it can be resumed
    super.dispose();
  }

  Future<void> _refreshCounts(AppServices sv) async {
    final c = await sv.documents.pageMethodCounts(widget.documentId);
    if (mounted) setState(() => _counts = c);
  }

  Future<void> _load() async {
    final sv = ServicesScope.of(context);
    final rec = await sv.documents.get(widget.documentId);
    final report = await sv.results.get(widget.documentId, TextExtractionService.reportKey);
    final extracted = await sv.documents.extractedPageNumbers(widget.documentId);
    final counts = await sv.documents.pageMethodCounts(widget.documentId);
    final analysis = await AnalysisService.loadSummary(sv.results, widget.documentId);
    if (!mounted) return;
    if (rec == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _record = rec;
      _counts = counts;
      _analysis = analysis;
      if (report is Map) {
        _summary = ExtractionSummary.fromJson(Map<String, dynamic>.from(report));
        _phase = _Phase.done;
      } else {
        _canResume = extracted.isNotEmpty;
        _done = extracted.length;
        _total = rec.pageCount ?? 0;
        _phase = _Phase.idle;
      }
    });
  }

  Future<void> _start() async {
    final sv = ServicesScope.of(context);
    final service = TextExtractionService(
      documents: sv.documents,
      pipeline: sv.pipeline,
      results: sv.results,
    );
    final cancel = CancelToken();
    setState(() {
      _cancel = cancel;
      _phase = _Phase.running;
      _passwordError = false;
    });
    try {
      final summary = await service.run(
        documentId: widget.documentId,
        filePath: sv.library.pathOf(widget.documentId),
        cancel: cancel,
        onProgress: (d, t) {
          if (mounted) {
            setState(() {
              _done = d;
              _total = t;
            });
          }
        },
      );
      await _refreshCounts(sv);
      if (!mounted) return;
      setState(() {
        if (summary.cancelled) {
          _phase = _Phase.idle;
          _canResume = true;
        } else {
          _summary = summary;
          _phase = _Phase.done;
        }
      });
    } on PdfReadException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _passwordError = e.passwordRequired;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _startOcr() async {
    final sv = ServicesScope.of(context);
    final service = OcrService(
      documents: sv.documents,
      pipeline: sv.pipeline,
      results: sv.results,
      settings: sv.settings,
      engine: TesseractOcrEngine(),
    );
    final cancel = CancelToken();
    setState(() {
      _cancel = cancel;
      _ocrPhase = _OcrPhase.running;
      _ocrMissing = const [];
      _ocrFailedPages = 0;
      _ocrDone = 0;
      _ocrTotal = _counts[PageMethod.pendingOcr] ?? 0;
    });
    try {
      final r = await service.run(
        documentId: widget.documentId,
        filePath: sv.library.pathOf(widget.documentId),
        cancel: cancel,
        onProgress: (d, t) {
          if (mounted) {
            setState(() {
              _ocrDone = d;
              _ocrTotal = t;
            });
          }
        },
      );
      await _refreshCounts(sv);
      if (!mounted) return;
      setState(() {
        _ocrPhase = _OcrPhase.idle;
        _ocrFailedPages = r.failed;
      });
    } on OcrUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _ocrPhase = _OcrPhase.failed;
        _ocrMissing = e.missing;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _ocrPhase = _OcrPhase.failed);
    }
  }

  Future<void> _startAnalysis() async {
    final sv = ServicesScope.of(context);
    final service = AnalysisService(
      documents: sv.documents,
      pipeline: sv.pipeline,
      results: sv.results,
    );
    final cancel = CancelToken();
    setState(() {
      _cancel = cancel;
      _anPhase = _AnPhase.running;
      _anDone = 0;
    });
    try {
      final r = await service.run(
        documentId: widget.documentId,
        filePath: sv.library.pathOf(widget.documentId),
        cancel: cancel,
        onProgress: (d, t) {
          if (mounted) {
            setState(() {
              _anDone = d;
              _anTotal = t;
            });
          }
        },
      );
      await _refreshCounts(sv);
      if (!mounted) return;
      setState(() {
        _anPhase = _AnPhase.idle;
        if (r != null) _analysis = r;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _anPhase = _AnPhase.failed);
    }
  }

  Future<void> _confirmDelete() async {
    final s = AppStrings.of(context);
    final sv = ServicesScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(s.deleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await sv.library.delete(widget.documentId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final rec = _record;
    final sv = ServicesScope.of(context);
    final pages = rec?.pageCount ?? (_total > 0 ? _total : null);

    return Scaffold(
      appBar: AppBar(
        title: Text(rec?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: s.deleteFile,
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _confirmDelete,
          ),
        ],
      ),
      body: rec == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          '${formatBytes(rec.sizeBytes)}${pages != null ? ' · ${s.pagesLabel(pages)}' : ''}',
                          style: text.bodySmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: PdfViewer.file(sv.library.pathOf(widget.documentId)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: SingleChildScrollView(child: _buildActions(s, text)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _progressPanel(TextTheme text, String label, double? value, String pauseLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: value,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: AppColors.primary,
          backgroundColor: AppColors.secondary,
        ),
        const SizedBox(height: 8),
        Text(label, style: text.bodySmall),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _cancel?.cancel(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border),
          ),
          child: Text(pauseLabel),
        ),
      ],
    );
  }

  Widget _buildActions(AppStrings s, TextTheme text) {
    switch (_phase) {
      case _Phase.loading:
        return const SizedBox.shrink();

      case _Phase.idle:
        return FilledButton(
          onPressed: _start,
          child: Text(_canResume ? s.resumeExtraction : s.extractText),
        );

      case _Phase.running:
        return _progressPanel(text, s.extracting(_done, _total),
            _total > 0 ? _done / _total : null, s.pauseExtraction);

      case _Phase.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _passwordError ? s.passwordProtected : s.extractionFailed,
                  style: text.bodyMedium,
                ),
              ),
            ),
            if (!_passwordError) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: _start, child: Text(s.retry)),
            ],
          ],
        );

      case _Phase.done:
        return _buildDone(s, text);
    }
  }

  Widget _buildDone(AppStrings s, TextTheme text) {
    final direct = _counts[PageMethod.direct] ?? 0;
    final ocr = _counts[PageMethod.ocr] ?? 0;
    final pending = _counts[PageMethod.pendingOcr] ?? 0;
    final failedReads = _summary?.failedReads ?? 0;

    if (_ocrPhase == _OcrPhase.running) {
      return _progressPanel(text, s.ocrRunning(_ocrDone, _ocrTotal),
          _ocrTotal > 0 ? _ocrDone / _ocrTotal : null, s.pauseExtraction);
    }

    if (_anPhase == _AnPhase.running) {
      return _progressPanel(text, s.analyzing(_anDone, _anTotal),
          _anTotal > 0 ? _anDone / _anTotal : null, s.pauseExtraction);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(s.extractionDone,
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(s.textPages(direct), style: text.bodyMedium),
                if (ocr > 0) Text(s.ocrPages(ocr), style: text.bodyMedium),
                if (pending > 0) Text(s.scannedPages(pending), style: text.bodyMedium),
                if (failedReads > 0) Text(s.unreadablePages(failedReads), style: text.bodyMedium),
                if (_ocrFailedPages > 0)
                  Text(s.ocrFailedPages(_ocrFailedPages), style: text.bodyMedium),
                if (_ocrPhase == _OcrPhase.failed) ...[
                  const SizedBox(height: 6),
                  Text(
                    _ocrMissing.isNotEmpty ? s.ocrModelsMissing(_ocrMissing) : s.ocrFailed,
                    style: text.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (pending > 0) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _startOcr,
            child: Text(_ocrPhase == _OcrPhase.failed ? s.retry : s.runOcr(pending)),
          ),
        ],
        if (pending == 0 && _analysis == null) ...[
          const SizedBox(height: 12),
          if (_anPhase == _AnPhase.failed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(s.analysisFailed, style: text.bodyMedium),
            ),
          FilledButton(
            onPressed: _startAnalysis,
            child: Text(_anPhase == _AnPhase.failed ? s.retry : s.analyzeDocument),
          ),
        ],
        if (_analysis != null) ...[
          const SizedBox(height: 12),
          _analysisCard(s, text, _analysis!),
        ],
      ],
    );
  }

  Widget _analysisCard(AppStrings s, TextTheme text, AnalysisSummary a) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: 8),
                Text(s.analysisTitle,
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Text(s.languageLine(a.languageCode), style: text.bodyMedium),
            Text(s.typeLine(a.docType), style: text.bodyMedium),
            if (a.keywords.isNotEmpty) Text(s.topicLine(a.keywords), style: text.bodyMedium),
            Text(s.chaptersLine(a.chapterCount), style: text.bodyMedium),
            if (a.reversedFixed) Text(s.reversedFixedLine, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
