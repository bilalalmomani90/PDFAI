import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/l10n/app_strings.dart';
import '../core/l10n/locale_controller.dart';
import '../core/theme/app_colors.dart';
import '../data/models.dart';
import 'document_screen.dart';
import 'services_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.localeController});
  final LocaleController localeController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PdfRecord>? _docs;
  bool _importing = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final docs = await ServicesScope.of(context).documents.list();
    if (!mounted) return;
    setState(() => _docs = docs);
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DocumentScreen(documentId: id)),
    );
    if (mounted) _load();
  }

  Future<void> _pick() async {
    final s = AppStrings.of(context);
    final services = ServicesScope.of(context);
    setState(() => _error = null);

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final picked = res?.files.single;
    if (picked == null || picked.path == null) return;
    if (!mounted) return;

    setState(() => _importing = true);
    try {
      final rec = await services.library.importPdf(File(picked.path!), name: picked.name);
      if (!mounted) return;
      setState(() => _importing = false);
      await _open(rec.id);
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = s.notValidPdf;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = s.importFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final docs = _docs;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appName),
        actions: [
          TextButton(
            onPressed: widget.localeController.toggle,
            child: Text(s.switchLanguage),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.tagline, style: text.titleLarge),
              const SizedBox(height: 20),
              Expanded(
                child: docs == null
                    ? const Center(child: CircularProgressIndicator())
                    : docs.isEmpty
                        ? _EmptyState(s: s)
                        : ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _DocTile(
                              record: docs[i],
                              s: s,
                              onTap: () => _open(docs[i].id),
                            ),
                          ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: text.bodyMedium),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _importing ? null : _pick,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(_importing ? s.importing : s.pickPdf),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _IconCircle(icon: Icons.picture_as_pdf_outlined),
              const SizedBox(height: 16),
              Text(s.emptyTitle, style: text.titleLarge),
              const SizedBox(height: 8),
              Text(s.emptyBody, textAlign: TextAlign.center, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.record, required this.s, required this.onTap});
  final PdfRecord record;
  final AppStrings s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pages = record.pageCount;
    final subtitle =
        '${formatBytes(record.sizeBytes)}${pages != null ? ' · ${s.pagesLabel(pages)}' : ''}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const _IconCircle(icon: Icons.picture_as_pdf_outlined, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, this.size = 72});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.47, color: AppColors.primary),
    );
  }
}
