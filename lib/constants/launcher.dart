import 'dart:developer';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart' as geo;

class AppLauncher {
  // ---------------------------------------------
  // REVERSE GEOCODING (LAT/LNG → ADDRESS)
  // ---------------------------------------------
  static Future<String> getAddressFromLocation(geo.Location location) async {
    try {
      final double? lat = location.latitude;
      final double? lng = location.longitude;

      if (lat == null || lng == null) {
        log('❌ Invalid coordinates: lat=$lat lng=$lng');
        return 'Address not available';
      }

      final List<geo.Placemark> placemarks =
          await geo.placemarkFromCoordinates(lat, lng);

      if (placemarks.isEmpty) {
        return 'Address not available';
      }

      final geo.Placemark place = placemarks.first;

      final address = [
        place.name,
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.postalCode,
        place.country,
      ].where((e) => e != null && e!.isNotEmpty).join(', ');

      log('✅ Reverse geocoded address: $address');
      return address;
    } catch (e, s) {
      log('❌ Reverse geocoding failed', error: e, stackTrace: s);
      return 'Address not available';
    }
  }

  // ---------------------------------------------
  // PHONE CALL
  // ---------------------------------------------
  static Future<void> phoneCall(String phone) async {
    final uri = Uri(scheme: "tel", path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
