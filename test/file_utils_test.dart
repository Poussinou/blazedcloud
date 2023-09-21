// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:blazedcloud/utils/files_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('File Utilites', () {
    test('fuzzySearch returns correct results', () {
      const query = 'abc';
      final list = ['abc', 'def', 'abcd', 'efg'];

      final result = fuzzySearch(query, list);

      expect(result, ['abc', 'abcd']);
    });
  });
}
