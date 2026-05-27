import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class SpotLocation {
  const SpotLocation({
    required this.city,
    required this.country,
    required this.integrityStatus,
    required this.accuracyMeters,
  });

  final String city;
  final String country;
  final String integrityStatus;
  final double accuracyMeters;
}

class SpotLocationService {
  const SpotLocationService();

  Future<SpotLocation?> currentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) {
      return null;
    }

    final place = placemarks.first;
    final city = _firstFilled([
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
    ]);
    final country = _firstFilled([place.country, place.isoCountryCode]);

    if (city == null || country == null) {
      return null;
    }

    final isMocked = position.isMocked;
    final accuracyMeters = position.accuracy;
    final integrityStatus = isMocked
        ? 'mock-location-review'
        : accuracyMeters > 300
        ? 'low-accuracy-review'
        : 'gps-verified';

    return SpotLocation(
      city: city,
      country: country,
      integrityStatus: integrityStatus,
      accuracyMeters: accuracyMeters,
    );
  }
}

String? _firstFilled(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }

  return null;
}
