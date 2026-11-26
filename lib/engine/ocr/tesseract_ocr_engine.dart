import 'package:flutter/services.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'ocr_engine.dart';

/// Tesseract 4 (LSTM) through flutter_tesseract_ocr. Fully offline.
/// Models are bundled in assets/tessdata/<lang>.traineddata.
class TesseractOcrEngine implements OcrEngine {
  static const _dir = 'assets/tessdata';

  @override
  Future<List<String>> missingModels(String language) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();
    return [
      for (final lang in language.split('+'))
        if (!assets.contains('$_dir/$lang.traineddata')) lang,
    ];
  }

  @override
  Future<String> recognize(String imagePath, {required String language}) {
    return FlutterTesseractOcr.extractText(
      imagePath,
      language: language,
      args: const {
        'psm': '3', // fully automatic page segmentation
        'preserve_interword_spaces': '1',
      },
    );
  }
}
