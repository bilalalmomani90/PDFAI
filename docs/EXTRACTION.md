# Text extraction (stage 3)
- Engine: PDFium via pdfrx. All pdfrx calls live in lib/engine/pdf/pdf_reader.dart only.
- Per page: read text -> clean -> if >= 20 non-space chars => `direct`, else `pendingOcr` (scanned page, OCR stage later).
- Each page is saved immediately (resume = skip saved pages). Progress is stored in `stages`.
- Report saved as result 'extraction_report' (total / direct / pendingOcr / failedReads).
- Known limits (to verify with real files): Arabic text may come back with presentation forms or reversed order;
  password-protected PDFs are reported but not opened yet; `failedReads` counts only the current run.
