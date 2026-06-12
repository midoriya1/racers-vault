import '../models/car_spot.dart';

const estimatedRegistryVehicleCount = 1381;
const estimatedCardSetCount = 570;

class RegistryProgress {
  const RegistryProgress({
    required this.uniqueVehicles,
    required this.totalVehicles,
    required this.uniqueCards,
    required this.totalCards,
  });

  final int uniqueVehicles;
  final int totalVehicles;
  final int uniqueCards;
  final int totalCards;

  int get vehiclePercent {
    if (totalVehicles <= 0) {
      return 0;
    }
    return ((uniqueVehicles / totalVehicles) * 100).round().clamp(0, 100);
  }

  int get cardPercent {
    if (totalCards <= 0) {
      return 0;
    }
    return ((uniqueCards / totalCards) * 100).round().clamp(0, 100);
  }

  factory RegistryProgress.fromSpots(List<CarSpot> spots) {
    final vehicleKeys = <String>{};
    final cardKeys = <String>{};

    for (final spot in spots) {
      final vehicleKey = _vehicleRegistryKey(spot);
      if (vehicleKey.isNotEmpty) {
        vehicleKeys.add(vehicleKey);
      }

      final cardKey =
          '${vehicleKey.isEmpty ? spot.carName : vehicleKey}|'
          '${spot.rarity}|${spot.category}';
      cardKeys.add(cardKey.toLowerCase());
    }

    return RegistryProgress(
      uniqueVehicles: vehicleKeys.length,
      totalVehicles: estimatedRegistryVehicleCount,
      uniqueCards: cardKeys.length,
      totalCards: estimatedCardSetCount,
    );
  }
}

String _vehicleRegistryKey(CarSpot spot) {
  final structured = [
    spot.vehicleMake,
    spot.vehicleModel,
    spot.vehicleGeneration,
    spot.yearRange,
  ].where((value) => value.trim().isNotEmpty).join('|');
  if (structured.isNotEmpty) {
    return structured.toLowerCase();
  }
  return spot.carName.trim().toLowerCase();
}
