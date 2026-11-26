# Analysis (stage 5)
Stages (each saved; finished ones skipped on re-run): normalize_text -> detect_language -> classify_document -> split_chapters.
- Normalization works from the ORIGINAL text (pages.raw_text), so re-running never double-processes.
  Reversal (visual order) is applied only when reversed common words >= 8 and >= 3x the forward ones.
- Language: script analysis + markers (Persian/Urdu letters) + Latin stop-words. Offline, no library. Mixed documents: primary language + script shares in 'language_report'.
- Type: keyword rules + page statistics. Topic = frequency keywords (not a written title). A local LLM can improve both later.
- Chapters: PDF bookmarks > headings (Chapter/الفصل.., or numbered 1,2,3 sequence; sections 1.1) > fixed ~8000-char parts.
- Known limits: keyword stop-words exist only for ar/en (other languages may get noisy keywords);
  heading detection is heuristic; the analysis button appears only when no page still needs OCR.
