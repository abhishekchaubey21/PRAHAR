/// PRAHAR Farmer App — Domain Models
/// Aligned with PRAHAR Engineering Specification v1.0 Section 6, 8 & 9.

class ZoneModel {
  final String id;
  final String name;
  final String soilType;
  final double moisturePct;
  final double temperatureC;
  final double humidityPct;
  final double ph;
  final DateTime? lastScanAt;

  const ZoneModel({
    required this.id,
    required this.name,
    required this.soilType,
    required this.moisturePct,
    required this.temperatureC,
    required this.humidityPct,
    required this.ph,
    this.lastScanAt,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      id: json['id'] as String,
      name: json['name'] as String,
      soilType: json['soil_type'] as String? ?? 'Loam',
      moisturePct: (json['moisture_pct'] as num).toDouble(),
      temperatureC: (json['temperature_c'] as num).toDouble(),
      humidityPct: (json['humidity_pct'] as num).toDouble(),
      ph: (json['ph'] as num).toDouble(),
      lastScanAt: json['last_scan_at'] != null ? DateTime.parse(json['last_scan_at']) : null,
    );
  }
}

enum HazardType { disease, pest, weed, waterStress, nutrientDeficiency }
enum AlertSeverity { low, medium, high, critical }
enum AlertStatus { newAlert, acknowledged, actionTaken, dismissed, resolved }

class AlertModel {
  final String id;
  final String zoneId;
  final String zoneName;
  final HazardType type;
  final AlertSeverity severity;
  final String message;
  final String recommendedAction;
  final AlertStatus status;
  final DateTime timestamp;

  const AlertModel({
    required this.id,
    required this.zoneId,
    required this.zoneName,
    required this.type,
    required this.severity,
    required this.message,
    required this.recommendedAction,
    required this.status,
    required this.timestamp,
  });
}

class RoverStatusModel {
  final String roverId;
  final String state;
  final double batteryPct;
  final String currentZone;
  final bool isOffline;

  const RoverStatusModel({
    required this.roverId,
    required this.state,
    required this.batteryPct,
    required this.currentZone,
    required this.isOffline,
  });
}
