import 'package:flutter_test/flutter_test.dart';
import 'package:app/engine/pdf/text_cleaner.dart';

void main() {
  test('removes invisible characters and collapses spaces', () {
    final out = TextCleaner.clean('a\u200Bb   c\u00A0d\r\n\r\n\r\n\r\ne');
    expect(out, 'ab c d\n\ne');
  });

  test('keeps Arabic text intact', () {
    expect(TextCleaner.clean('  مرحبا   بالعالم '), 'مرحبا بالعالم');
  });

  test('meaningfulChars ignores whitespace', () {
    expect(TextCleaner.meaningfulChars(' a b\n c '), 3);
  });
}
