import 'package:flutter_test/flutter_test.dart';
import 'package:englishplease/utils/slug.dart';

void main() {
  test('slugify basic cases', () {
    expect(slugify('Hello World!'), 'hello-world');
    expect(slugify('  multi   spaces  '), 'multi-spaces');
    expect(slugify('@@'), 'pattern');
    expect(slugify('MixED-Case_123'), 'mixed-case-123');
  });
}

