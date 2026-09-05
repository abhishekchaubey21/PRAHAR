/// PRAHAR Farmer App — Domain Models
/// Aligned with PRAHAR Engineering Specification v1.0 Section 6, 8, 9 & 12.

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

class FarmModel {
  final String id;
  final String name;
  final String location;
  final double totalHectares;
  final String farmerId;

  const FarmModel({
    required this.id,
    required this.name,
    required this.location,
    required this.totalHectares,
    required this.farmerId,
  });

  factory FarmModel.fromJson(Map<String, dynamic> json) {
    return FarmModel(
      id: (json['farm_id'] ?? json['id'] ?? 'FARM-DEMO-01') as String,
      name: (json['name'] ?? 'Demo Farm Alpha') as String,
      location: (json['location'] ?? 'Indore, MP') as String,
      totalHectares: (json['total_hectares'] as num?)?.toDouble() ?? 4.2,
      farmerId: (json['farmer_id'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'total_hectares': totalHectares,
        'farmer_id': farmerId,
      };
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
  final String messageHi;
  final String recommendedAction;
  final String recommendedActionHi;
  AlertStatus status;
  final DateTime timestamp;
  bool isApproved;

  AlertModel({
    required this.id,
    required this.zoneId,
    required this.zoneName,
    required this.type,
    required this.severity,
    required this.message,
    required this.messageHi,
    required this.recommendedAction,
    required this.recommendedActionHi,
    required this.status,
    required this.timestamp,
    this.isApproved = false,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? 'WATER_STRESS').toUpperCase();
    HazardType type = HazardType.waterStress;
    if (typeStr == 'DISEASE') type = HazardType.disease;
    if (typeStr == 'PEST') type = HazardType.pest;
    if (typeStr == 'WEED') type = HazardType.weed;
    if (typeStr == 'NUTRIENT_DEFICIENCY') type = HazardType.nutrientDeficiency;

    final sevStr = (json['severity'] as String? ?? 'LOW').toUpperCase();
    AlertSeverity severity = AlertSeverity.low;
    if (sevStr == 'MEDIUM') severity = AlertSeverity.medium;
    if (sevStr == 'HIGH') severity = AlertSeverity.high;
    if (sevStr == 'CRITICAL') severity = AlertSeverity.critical;

    final statStr = (json['status'] as String? ?? 'NEW').toUpperCase();
    AlertStatus status = AlertStatus.newAlert;
    if (statStr == 'ACKNOWLEDGED') status = AlertStatus.acknowledged;
    if (statStr == 'ACTION_TAKEN') status = AlertStatus.actionTaken;
    if (statStr == 'DISMISSED') status = AlertStatus.dismissed;
    if (statStr == 'RESOLVED') status = AlertStatus.resolved;

    return AlertModel(
      id: (json['alert_id'] ?? json['id'] ?? '') as String,
      zoneId: (json['zone_id'] ?? '') as String,
      zoneName: (json['zone_name'] ?? json['zone_id'] ?? 'Zone') as String,
      type: type,
      severity: severity,
      message: (json['message'] ?? '') as String,
      messageHi: (json['message_hi'] ?? json['message'] ?? '') as String,
      recommendedAction: (json['recommended_action'] ?? '') as String,
      recommendedActionHi: (json['recommended_action_hi'] ?? json['recommended_action'] ?? '') as String,
      status: status,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isApproved: status == AlertStatus.actionTaken || status == AlertStatus.resolved,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'zone_id': zoneId,
        'zone_name': zoneName,
        'type': type.name,
        'severity': severity.name,
        'message': message,
        'message_hi': messageHi,
        'recommended_action': recommendedAction,
        'recommended_action_hi': recommendedActionHi,
        'status': status.name,
        'timestamp': timestamp.toIso8601String(),
        'is_approved': isApproved,
      };
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

class RemediationVerificationModel {
  final String zoneId;
  final double preMoisture;
  final double postMoisture;
  final double moistureDelta;
  final bool resolved;
  final String summaryEn;
  final String summaryHi;

  const RemediationVerificationModel({
    required this.zoneId,
    required this.preMoisture,
    required this.postMoisture,
    required this.moistureDelta,
    required this.resolved,
    required this.summaryEn,
    required this.summaryHi,
  });

  factory RemediationVerificationModel.fromJson(Map<String, dynamic> json) {
    return RemediationVerificationModel(
      zoneId: (json['zone_id'] ?? '') as String,
      preMoisture: (json['pre_moisture'] as num?)?.toDouble() ?? 17.5,
      postMoisture: (json['post_moisture'] as num?)?.toDouble() ?? 28.2,
      moistureDelta: (json['moisture_delta'] as num?)?.toDouble() ?? 10.7,
      resolved: (json['resolved'] as bool?) ?? true,
      summaryEn: (json['summary_en'] ?? json['summary'] ?? 'Remediation verified.') as String,
      summaryHi: (json['summary_hi'] ?? 'उपचार का सत्यापन सफल।') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'zone_id': zoneId,
        'pre_moisture': preMoisture,
        'post_moisture': postMoisture,
        'moisture_delta': moistureDelta,
        'resolved': resolved,
        'summary_en': summaryEn,
        'summary_hi': summaryHi,
      };
}
