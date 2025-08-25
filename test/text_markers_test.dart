import 'package:flutter_test/flutter_test.dart';
import 'package:englishplease/core/text_markers.dart';

void main() {
  group('TextMarkers', () {
    test('extractCurly returns inner text', () {
      const s = 'hello {{ pattern here }} world';
      expect(TextMarkers.extractCurly(s), 'pattern here');
    });

    test('extractParen returns inner text', () {
      const s = 'foo (( an english sentence. )) bar';
      expect(TextMarkers.extractParen(s), 'an english sentence.');
    });

    test('stripCurly removes markers and keeps newlines', () {
      const s = 'a\n{{ remove me }}\nb';
      expect(TextMarkers.stripCurly(s), 'a\nb');
    });

    test('stripParen removes markers and keeps newlines', () {
      const s = 'a\n(( remove me ))\nb';
      expect(TextMarkers.stripParen(s), 'a\nb');
    });
  });
}

