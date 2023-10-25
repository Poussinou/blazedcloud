import 'package:glassfy_flutter/glassfy_flutter.dart';
import 'package:glassfy_flutter/models.dart';
import 'package:logging/logging.dart';

class PurchaseApi {
  static const _apiKey = '821feb96c6024f2b9db92964b6726cda';

  static Future<List<GlassfyOffering>> fetchOffers() async {
    final log = Logger("main");
    try {
      final offerings = await Glassfy.offerings();
      return offerings.all ?? [];
    } catch (e) {
      log.warning("Glassfy failed to fetch offers: $e");
      return [];
    }
  }
}
