# Changelog

## 0.5.0+5 - Stage 5 (analysis)
- Offline language detection (ar/fa/ur/en/fr/es/de/it/pt/tr/ru/he/hi/zh/ja/ko/el), no extra libraries.
- Arabic normalization: presentation forms -> base letters, tatweel removal, reversed (visual-order) text fix.
- Document type (rule-based) and main-topic keywords. Chapters/sections from bookmarks, headings, or fixed parts.
- DB migration v2 (pages.raw_text keeps the original text). Analysis card on the document screen.

## 0.4.0+4 - Stage 4 (OCR)
- OCR for scanned pages with Tesseract (ara + eng), page by page, pausable and resumable.
- Pages are rendered with PDFium (200 dpi, grayscale) and recognized on-device, no internet.
- Missing language models are detected and reported. Live page counts on the document screen.

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
