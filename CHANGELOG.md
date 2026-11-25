# Changelog

## 0.3.0+3 - Stage 3 (PDF reading and text extraction)
- Import a PDF (file picker, header check, private copy) and list files on the home screen.
- Document screen: file info, preview (PDFium), resumable page-by-page text extraction with progress and pause.
- Scanned pages detected (pendingOcr) and reported. Added text cleaner and tests.

## 0.2.0+2 - Stage 2 (data layer)
- SQLite (sqflite) with append-only migrations; tables: documents, pages, stages, chunks, results, settings.
- Repositories, private PDF file store, import/delete service, interrupted-work recovery.
- Language choice is now saved and restored. Added data-layer tests (test/data).

## 0.1.0+1 - Stage 1 (project skeleton)
- Folder structure, pubspec, approved color palette and theme.
- Arabic (RTL) / English (LTR) switching with a placeholder home screen.
- Empty Start.io config (no IDs). No engine, ads or storage logic yet.
