// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:blazedcloud/services/files_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('Server Operations', () {
    const uid = 'o6ahuuyukowd5dp';
    const token =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjb2xsZWN0aW9uSWQiOiJfcGJfdXNlcnNfYXV0aF8iLCJleHAiOjE2OTU2OTAxNDgsImlkIjoibzZhaHV1eXVrb3dkNWRwIiwidHlwZSI6ImF1dGhSZWNvcmQifQ.Uq_9cpGiO8x5cV81ocYrXHU-f1tVPeGaTZmdZM0SXQA';
    test('Delete File', () async {
      const filename = 'file_to_delete.txt';
      final result = await deleteFile(uid, filename, token);

      // Assert that the file was deleted successfully
      expect(result, true);
    });

    test('Get File', () async {
      const filename = 'file_to_get.txt';
      final fileStream = await getFile(uid, filename, token);

      // Assert that the file stream is not null
      expect(fileStream, isNotNull);
    });

    test('Get Filelist', () async {
      final list = await getFilelist(uid, "", token);

      // Assert that the file list is not null
      expect(list, isNotNull);
    });

    test('Upload File', () async {
      const filename = 'file_to_upload.txt';
      final bytes = http.ByteStream.fromBytes(
          [1, 2, 3, 4, 5]); // Replace with your file bytes

      final result = await getUploadUrl(uid, filename, bytes, 5, token);

      // Assert that the file was uploaded successfully
      expect(result, true);
    });
  });
}
