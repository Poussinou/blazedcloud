import 'package:blazedcloud/log.dart';
import 'package:glassfy_flutter/glassfy_flutter.dart';
import 'package:glassfy_flutter/models.dart';

class PurchaseApi {
  static Future<List<GlassfyOffering>> fetchOffers() async {
    try {
      final offerings = await Glassfy.offerings();
      return offerings.all ?? [];
    } catch (e) {
      logger.w("Glassfy failed to fetch offers: $e");
      return [];
    }
  }
}
