import 'package:http/http.dart' as http;

class EncryptedStreamResult {
  final http.ByteStream stream;
  final int totalByteLength;

  EncryptedStreamResult(this.stream, this.totalByteLength);
}
