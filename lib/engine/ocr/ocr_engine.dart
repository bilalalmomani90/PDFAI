/// Abstraction over the OCR library so it can be replaced without touching the engine.
abstract class OcrEngine {
  /// Language models (e.g. 'ara', 'eng') that are NOT available in the app.
  Future<List<String>> missingModels(String language);

  /// Recognize text in an image file. [language] like 'ara+eng'.
  Future<String> recognize(String imagePath, {required String language});
}

class OcrUnavailableException implements Exception {
  OcrUnavailableException(this.missing);
  final List<String> missing;
  @override
  String toString() => 'Missing OCR models: ${missing.join(', ')}';
}
