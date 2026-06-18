import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interactive controls do not contain literal dead callbacks', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final issues = <String>[];
    final emptyCallback = RegExp(
      r'(?:^|[,({])\s*on[A-Z][A-Za-z0-9_]*\s*:\s*\(\s*\)\s*\{\s*\}',
      multiLine: true,
    );
    final explicitNullCallback = RegExp(
      r'(?:^|[,({])\s*on(?:Pressed|Tap|LongPress)\s*:[ \t]*null\b',
      multiLine: true,
    );

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      if (emptyCallback.hasMatch(source)) {
        issues.add('${file.path}: empty interaction callback');
      }
      if (explicitNullCallback.hasMatch(source)) {
        issues.add('${file.path}: permanently disabled interaction callback');
      }
    }

    expect(issues, isEmpty, reason: issues.join('\n'));
  });
}
