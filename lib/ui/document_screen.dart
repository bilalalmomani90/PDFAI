import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core/format.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../data/models.dart';
import '../engine/cancel_token.dart';
import '../engine/pdf/pdf_reader.dart';
import '../engine/pdf/text_extraction_service.dart';
import 'services_scope.dart';

enum _Phase { loading, idle, running, done, failed }

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key, required this.documentId});
  final String documentId;

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  _Phase _phase = _Phase.loading;
  PdfRecord? _record;
  ExtractionSummary? _summary;
  bool _canResume = false;
  int _done = 0;
  int _total = 0;
  String? _error;
  bool _passwordError = false;
  CancelToken? _cancel;
  bool _started = false;

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

  Future<void> _load() async {
    final sv = ServicesScope.of(context);
    final rec = await sv.documents.get(widget.documentId);
    final report = await sv.results.get(widget.documentId, TextExtractionService.reportKey);
    final extracted = await sv.documents.extractedPageNumbers(widget.documentId);
    if (!mounted) return;
    if (rec == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _record = rec;
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
      _error = null;
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
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = e.toString();
      });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(rec?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: s.deleteFile,
            icon: const Icon(Icons.delete_outline),
            onPressed: _phase == _Phase.running ? null : _confirmDelete,
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
                          '${formatBytes(rec.sizeBytes)}'
                          '${(rec.pageCount ?? (_total > 0 ? _total : null)) != null ? ' · ${s.pagesLabel(rec.pageCount ?? _total)}' : ''}',
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
                    _buildActions(s, text),
                  ],
                ),
              ),
            ),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: _total > 0 ? _done / _total : null,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.primary,
              backgroundColor: AppColors.secondary,
            ),
            const SizedBox(height: 8),
            Text(s.extracting(_done, _total), style: text.bodySmall),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _cancel?.cancel(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
              ),
              child: Text(s.pauseExtraction),
            ),
          ],
        );

      case _Phase.done:
        final sum = _summary!;
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
                    Text(s.extractionDone, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(s.textPages(sum.directPages), style: text.bodyMedium),
                if (sum.pendingOcrPages > 0)
                  Text(s.scannedPages(sum.pendingOcrPages), style: text.bodyMedium),
                if (sum.failedReads > 0)
                  Text(s.unreadablePages(sum.failedReads), style: text.bodyMedium),
              ],
            ),
          ),
        );

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
    }
  }
}
