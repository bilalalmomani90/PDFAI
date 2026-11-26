# OCR (stage 4)
- Engine: Tesseract 4 (LSTM) via flutter_tesseract_ocr, offline. Wrapped by `OcrEngine` (lib/engine/ocr) so it can be swapped.
- Models: assets/tessdata/ara.traineddata + eng.traineddata (not included; see README). Default languages 'ara+eng' (setting `ocr_languages`).
- Flow: pages marked `pendingOcr` -> render with PDFium (200 dpi, long side <= 3000 px, grayscale PNG in temp) -> recognize -> clean -> save as `ocr`.
- Blank pages are saved as `ocr` with empty text (not retried). Pages that error stay `pendingOcr` and are retried next run.
- If every page fails, the run fails (engine problem) instead of reporting success.
- Limits: no per-page confidence (plugin does not expose it); Arabic accuracy depends on scan quality; image encoding runs on the main isolate (a short UI hitch per page on weak devices).
