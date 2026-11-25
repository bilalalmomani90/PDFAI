/// Statuses are stored in SQLite as their `name` (text).
enum DocStatus { imported, processing, paused, completed, failed }

enum StageStatus { pending, running, completed, failed, paused, skipped }

/// direct = text read from the PDF; ocr = text produced by OCR;
/// pendingOcr = page has (almost) no text and still needs OCR.
enum PageMethod { direct, ocr, pendingOcr }

T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
