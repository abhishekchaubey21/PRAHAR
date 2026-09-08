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
  final String cropType;

  const ZoneModel({
    required this.id,
    required this.name,
    required this.soilType,
    required this.moisturePct,
    required this.temperatureC,
    required this.humidityPct,
    required this.ph,
    this.lastScanAt,
    this.cropType = '',
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      id: json['id'] as String,
      name: (json['name'] ?? json['zone_name'] ?? '') as String,
      soilType: json['soil_type'] as String? ?? 'Loam',
      moisturePct: (json['moisture_pct'] as num?)?.toDouble() ?? 0.0,
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 25.0,
      humidityPct: (json['humidity_pct'] as num?)?.toDouble() ?? 50.0,
      ph: (json['ph'] as num?)?.toDouble() ?? 7.0,
      lastScanAt: json['last_scan_at'] != null ? DateTime.parse(json['last_scan_at']) : null,
      cropType: (json['crop_type'] ?? json['crop'] ?? '') as String,
    );
  }
}

class FarmModel {
  final String id;
  final String name;
  final String location;
  final double totalHectares;
  final String farmerId;
  final double areaAcres;
  final String cropType;
  final String ownershipType;
  final String irrigationStatus;
  final String waterSource;
  final String soilType;
  final String season;

  const FarmModel({
    required this.id,
    required this.name,
    required this.location,
    required this.totalHectares,
    required this.farmerId,
    this.areaAcres = 4.2,
    this.cropType = 'Soybean + Wheat',
    this.ownershipType = 'OWNED',
    this.irrigationStatus = 'PARTIAL',
    this.waterSource = 'BOREWELL',
    this.soilType = 'Black Cotton Loam',
    this.season = 'KHARIF',
  });

  factory FarmModel.fromJson(Map<String, dynamic> json) {
    final rawAcres = (json['area_acres'] as num?)?.toDouble();
    final rawHectares = (json['total_hectares'] as num?)?.toDouble();
    final acres = rawAcres ?? (rawHectares != null ? rawHectares * 2.47105 : 4.2);
    final hectares = rawHectares ?? (rawAcres != null ? rawAcres / 2.47105 : 1.7);

    return FarmModel(
      id: (json['farm_id'] ?? json['id'] ?? 'FARM-DEMO-01') as String,
      name: (json['name'] ?? 'Patil Krishi Farm (पाटील कृषी फार्म)') as String,
      location: (json['location'] ?? 'Amravati, Maharashtra') as String,
      totalHectares: hectares,
      farmerId: (json['farmer_id'] ?? '') as String,
      areaAcres: acres,
      cropType: (json['crop_type'] ?? 'Soybean + Wheat') as String,
      ownershipType: (json['ownership_type'] ?? 'OWNED') as String,
      irrigationStatus: (json['irrigation_status'] ?? 'PARTIAL') as String,
      waterSource: (json['water_source'] ?? 'BOREWELL') as String,
      soilType: (json['soil_type'] ?? 'Black Cotton Loam') as String,
      season: (json['season'] ?? 'KHARIF') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'total_hectares': totalHectares,
        'farmer_id': farmerId,
        'area_acres': areaAcres,
        'crop_type': cropType,
        'ownership_type': ownershipType,
        'irrigation_status': irrigationStatus,
        'water_source': waterSource,
        'soil_type': soilType,
        'season': season,
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
  final double gpsLat;
  final double gpsLng;
  final double fieldCoveragePct;
  final bool isSimulated;
  final String dataSource; // 'DEMO' | 'LIVE'

  const RoverStatusModel({
    required this.roverId,
    required this.state,
    required this.batteryPct,
    required this.currentZone,
    required this.isOffline,
    this.gpsLat = 20.9374,
    this.gpsLng = 77.7796,
    this.fieldCoveragePct = 100.0,
    this.isSimulated = true,
    this.dataSource = 'DEMO',
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

class NotificationModel {
  final String id;
  final String notificationId;
  final String userId;
  final String farmId;
  final String? zoneId;
  final String? alertId;
  final String? actionId;
  final String type;
  final String severity;
  final String title;
  final String? titleHi;
  final String message;
  final String? messageHi;
  bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata;
  final String? deduplicationKey;

  NotificationModel({
    required this.id,
    required this.notificationId,
    required this.userId,
    required this.farmId,
    this.zoneId,
    this.alertId,
    this.actionId,
    required this.type,
    required this.severity,
    required this.title,
    this.titleHi,
    required this.message,
    this.messageHi,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.metadata,
    this.deduplicationKey,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] ?? '') as String,
      notificationId: (json['notification_id'] ?? json['id'] ?? '') as String,
      userId: (json['user_id'] ?? '') as String,
      farmId: (json['farm_id'] ?? '') as String,
      zoneId: json['zone_id'] as String?,
      alertId: json['alert_id'] as String?,
      actionId: json['action_id'] as String?,
      type: (json['type'] ?? 'SYSTEM') as String,
      severity: (json['severity'] ?? 'INFO') as String,
      title: (json['title'] ?? '') as String,
      titleHi: json['title_hi'] as String?,
      message: (json['message'] ?? '') as String,
      messageHi: json['message_hi'] as String?,
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      deduplicationKey: json['deduplication_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notification_id': notificationId,
        'user_id': userId,
        'farm_id': farmId,
        'zone_id': zoneId,
        'alert_id': alertId,
        'action_id': actionId,
        'type': type,
        'severity': severity,
        'title': title,
        'title_hi': titleHi,
        'message': message,
        'message_hi': messageHi,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
        'read_at': readAt?.toIso8601String(),
        'metadata': metadata,
        'deduplication_key': deduplicationKey,
      };
}

// ============================================================================
// Phase 6B-2: Farmer Analytics Models
// ============================================================================

class LatestSensorMetricsModel {
  final double? moisturePct;
  final double? temperatureC;
  final double? humidityPct;
  final double? ph;
  final String? lastRecordedAt;

  LatestSensorMetricsModel({
    this.moisturePct,
    this.temperatureC,
    this.humidityPct,
    this.ph,
    this.lastRecordedAt,
  });

  factory LatestSensorMetricsModel.fromJson(Map<String, dynamic> json) {
    return LatestSensorMetricsModel(
      moisturePct: (json['moisture_pct'] as num?)?.toDouble(),
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      humidityPct: (json['humidity_pct'] as num?)?.toDouble(),
      ph: (json['ph'] as num?)?.toDouble(),
      lastRecordedAt: json['last_recorded_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'moisture_pct': moisturePct,
        'temperature_c': temperatureC,
        'humidity_pct': humidityPct,
        'ph': ph,
        'last_recorded_at': lastRecordedAt,
      };
}

class ZoneHealthSummaryModel {
  final String zoneId;
  final String zoneName;
  final String farmId;
  final String soilType;
  final String healthStatus; // 'OPTIMAL' | 'ATTENTION_REQUIRED' | 'CRITICAL'
  final String healthLabel;
  final String summaryEn;
  final String summaryHi;
  final LatestSensorMetricsModel latestMetrics;
  final int activeAlertsCount;
  final int recentHazardCount;
  final String? lastScanAt;
  final String evaluatedAt;

  ZoneHealthSummaryModel({
    required this.zoneId,
    required this.zoneName,
    required this.farmId,
    required this.soilType,
    required this.healthStatus,
    required this.healthLabel,
    required this.summaryEn,
    required this.summaryHi,
    required this.latestMetrics,
    required this.activeAlertsCount,
    required this.recentHazardCount,
    this.lastScanAt,
    required this.evaluatedAt,
  });

  factory ZoneHealthSummaryModel.fromJson(Map<String, dynamic> json) {
    return ZoneHealthSummaryModel(
      zoneId: (json['zone_id'] ?? '') as String,
      zoneName: (json['zone_name'] ?? json['zone_id'] ?? '') as String,
      farmId: (json['farm_id'] ?? '') as String,
      soilType: (json['soil_type'] ?? 'Loam') as String,
      healthStatus: (json['health_status'] ?? 'OPTIMAL') as String,
      healthLabel: (json['health_label'] ?? 'PRAHAR Field-Health & Risk Summary') as String,
      summaryEn: (json['summary_en'] ?? '') as String,
      summaryHi: (json['summary_hi'] ?? '') as String,
      latestMetrics: LatestSensorMetricsModel.fromJson(
        (json['latest_metrics'] as Map<String, dynamic>?) ?? {},
      ),
      activeAlertsCount: (json['active_alerts_count'] as num?)?.toInt() ?? 0,
      recentHazardCount: (json['recent_hazard_count'] as num?)?.toInt() ?? 0,
      lastScanAt: json['last_scan_at'] as String?,
      evaluatedAt: (json['evaluated_at'] ?? DateTime.now().toIso8601String()) as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'zone_id': zoneId,
        'zone_name': zoneName,
        'farm_id': farmId,
        'soil_type': soilType,
        'health_status': healthStatus,
        'health_label': healthLabel,
        'summary_en': summaryEn,
        'summary_hi': summaryHi,
        'latest_metrics': latestMetrics.toJson(),
        'active_alerts_count': activeAlertsCount,
        'recent_hazard_count': recentHazardCount,
        'last_scan_at': lastScanAt,
        'evaluated_at': evaluatedAt,
      };
}

class FarmAnalyticsSummaryModel {
  final String farmId;
  final String farmName;
  final int totalZones;
  final String overallStatus;
  final String healthLabel;
  final String summaryEn;
  final String summaryHi;
  final int activeAlertsCount;
  final List<ZoneHealthSummaryModel> zones;
  final String evaluatedAt;

  FarmAnalyticsSummaryModel({
    required this.farmId,
    required this.farmName,
    required this.totalZones,
    required this.overallStatus,
    required this.healthLabel,
    required this.summaryEn,
    required this.summaryHi,
    required this.activeAlertsCount,
    required this.zones,
    required this.evaluatedAt,
  });

  factory FarmAnalyticsSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawZones = (json['zones'] as List?) ?? [];
    return FarmAnalyticsSummaryModel(
      farmId: (json['farm_id'] ?? '') as String,
      farmName: (json['farm_name'] ?? '') as String,
      totalZones: (json['total_zones'] as num?)?.toInt() ?? rawZones.length,
      overallStatus: (json['overall_status'] ?? 'OPTIMAL') as String,
      healthLabel: (json['health_label'] ?? 'PRAHAR Field-Health & Risk Summary') as String,
      summaryEn: (json['summary_en'] ?? '') as String,
      summaryHi: (json['summary_hi'] ?? '') as String,
      activeAlertsCount: (json['active_alerts_count'] as num?)?.toInt() ?? 0,
      zones: rawZones.map((z) => ZoneHealthSummaryModel.fromJson(z as Map<String, dynamic>)).toList(),
      evaluatedAt: (json['evaluated_at'] ?? DateTime.now().toIso8601String()) as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'farm_id': farmId,
        'farm_name': farmName,
        'total_zones': totalZones,
        'overall_status': overallStatus,
        'health_label': healthLabel,
        'summary_en': summaryEn,
        'summary_hi': summaryHi,
        'active_alerts_count': activeAlertsCount,
        'zones': zones.map((z) => z.toJson()).toList(),
        'evaluated_at': evaluatedAt,
      };
}

class SensorTrendPointModel {
  final DateTime timestamp;
  final double? moisturePct;
  final double? temperatureC;
  final double? humidityPct;
  final double? ph;

  SensorTrendPointModel({
    required this.timestamp,
    this.moisturePct,
    this.temperatureC,
    this.humidityPct,
    this.ph,
  });

  factory SensorTrendPointModel.fromJson(Map<String, dynamic> json) {
    return SensorTrendPointModel(
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : DateTime.now(),
      moisturePct: (json['moisture_pct'] as num?)?.toDouble(),
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      humidityPct: (json['humidity_pct'] as num?)?.toDouble(),
      ph: (json['ph'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'moisture_pct': moisturePct,
        'temperature_c': temperatureC,
        'humidity_pct': humidityPct,
        'ph': ph,
      };
}

class HazardTrendItemModel {
  final String hazardType;
  final String hazardName;
  final String highestSeverity;
  final int occurrenceCount;
  final DateTime latestRecordedAt;
  final double latestConfidence;

  HazardTrendItemModel({
    required this.hazardType,
    required this.hazardName,
    required this.highestSeverity,
    required this.occurrenceCount,
    required this.latestRecordedAt,
    required this.latestConfidence,
  });

  factory HazardTrendItemModel.fromJson(Map<String, dynamic> json) {
    return HazardTrendItemModel(
      hazardType: (json['hazard_type'] ?? '') as String,
      hazardName: (json['hazard_name'] ?? json['hazard_type'] ?? '') as String,
      highestSeverity: (json['highest_severity'] ?? 'LOW') as String,
      occurrenceCount: (json['occurrence_count'] as num?)?.toInt() ?? 1,
      latestRecordedAt: json['latest_recorded_at'] != null ? DateTime.parse(json['latest_recorded_at'] as String) : DateTime.now(),
      latestConfidence: (json['latest_confidence'] as num?)?.toDouble() ?? 0.8,
    );
  }

  Map<String, dynamic> toJson() => {
        'hazard_type': hazardType,
        'hazard_name': hazardName,
        'highest_severity': highestSeverity,
        'occurrence_count': occurrenceCount,
        'latest_recorded_at': latestRecordedAt.toIso8601String(),
        'latest_confidence': latestConfidence,
      };
}

class AnalyticsTrendsModel {
  final String zoneId;
  final String? zoneName;
  final String? from;
  final String? to;
  final bool hasSufficientData;
  final List<SensorTrendPointModel> sensorTrends;
  final List<HazardTrendItemModel> hazardBreakdown;
  final String evaluatedAt;

  AnalyticsTrendsModel({
    required this.zoneId,
    this.zoneName,
    this.from,
    this.to,
    required this.hasSufficientData,
    required this.sensorTrends,
    required this.hazardBreakdown,
    required this.evaluatedAt,
  });

  factory AnalyticsTrendsModel.fromJson(Map<String, dynamic> json) {
    final rawSensors = (json['sensor_trends'] as List?) ?? [];
    final rawHazards = (json['hazard_breakdown'] as List?) ?? [];
    return AnalyticsTrendsModel(
      zoneId: (json['zone_id'] ?? '') as String,
      zoneName: json['zone_name'] as String?,
      from: json['from'] as String?,
      to: json['to'] as String?,
      hasSufficientData: (json['has_sufficient_data'] as bool?) ?? false,
      sensorTrends: rawSensors.map((s) => SensorTrendPointModel.fromJson(s as Map<String, dynamic>)).toList(),
      hazardBreakdown: rawHazards.map((h) => HazardTrendItemModel.fromJson(h as Map<String, dynamic>)).toList(),
      evaluatedAt: (json['evaluated_at'] ?? DateTime.now().toIso8601String()) as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'zone_id': zoneId,
        'zone_name': zoneName,
        'from': from,
        'to': to,
        'has_sufficient_data': hasSufficientData,
        'sensor_trends': sensorTrends.map((s) => s.toJson()).toList(),
        'hazard_breakdown': hazardBreakdown.map((h) => h.toJson()).toList(),
        'evaluated_at': evaluatedAt,
      };
}

class InterventionHistoryItemModel {
  final String actionId;
  final String zoneId;
  final String actionType;
  final int durationSeconds;
  final double volumeLiters;
  final String approvedBy;
  final String approvedAt;
  final String status;
  final String? expertNote;
  final DateTime createdAt;
  final RemediationVerificationModel? verification;

  InterventionHistoryItemModel({
    required this.actionId,
    required this.zoneId,
    required this.actionType,
    required this.durationSeconds,
    required this.volumeLiters,
    required this.approvedBy,
    required this.approvedAt,
    required this.status,
    this.expertNote,
    required this.createdAt,
    this.verification,
  });

  factory InterventionHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return InterventionHistoryItemModel(
      actionId: (json['action_id'] ?? '') as String,
      zoneId: (json['zone_id'] ?? '') as String,
      actionType: (json['action_type'] ?? 'IRRIGATE') as String,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 30,
      volumeLiters: (json['volume_liters'] as num?)?.toDouble() ?? 7.5,
      approvedBy: (json['approved_by'] ?? '') as String,
      approvedAt: (json['approved_at'] ?? '') as String,
      status: (json['status'] ?? 'APPROVED') as String,
      expertNote: json['expert_note'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      verification: json['verification'] != null
          ? RemediationVerificationModel.fromJson(json['verification'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'action_id': actionId,
        'zone_id': zoneId,
        'action_type': actionType,
        'duration_seconds': durationSeconds,
        'volume_liters': volumeLiters,
        'approved_by': approvedBy,
        'approved_at': approvedAt,
        'status': status,
        'expert_note': expertNote,
        'created_at': createdAt.toIso8601String(),
        'verification': verification?.toJson(),
      };
}

class AnalyticsInterventionsModel {
  final String? farmId;
  final String? zoneId;
  final int totalCount;
  final List<InterventionHistoryItemModel> interventions;
  final String evaluatedAt;

  AnalyticsInterventionsModel({
    this.farmId,
    this.zoneId,
    required this.totalCount,
    required this.interventions,
    required this.evaluatedAt,
  });

  factory AnalyticsInterventionsModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['interventions'] as List?) ?? [];
    return AnalyticsInterventionsModel(
      farmId: json['farm_id'] as String?,
      zoneId: json['zone_id'] as String?,
      totalCount: (json['total_count'] as num?)?.toInt() ?? raw.length,
      interventions: raw.map((i) => InterventionHistoryItemModel.fromJson(i as Map<String, dynamic>)).toList(),
      evaluatedAt: (json['evaluated_at'] ?? DateTime.now().toIso8601String()) as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'farm_id': farmId,
        'zone_id': zoneId,
        'total_count': totalCount,
        'interventions': interventions.map((i) => i.toJson()).toList(),
        'evaluated_at': evaluatedAt,
      };
}

class ReportPeriodModel {
  final String from;
  final String to;

  const ReportPeriodModel({required this.from, required this.to});

  factory ReportPeriodModel.fromJson(Map<String, dynamic> json) {
    return ReportPeriodModel(
      from: (json['from'] ?? '') as String,
      to: (json['to'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {'from': from, 'to': to};
}

class ReportHazardItemModel {
  final String timestamp;
  final String hazardType;
  final String hazardName;
  final String severity;
  final double confidence;

  const ReportHazardItemModel({
    required this.timestamp,
    required this.hazardType,
    required this.hazardName,
    required this.severity,
    required this.confidence,
  });

  factory ReportHazardItemModel.fromJson(Map<String, dynamic> json) {
    return ReportHazardItemModel(
      timestamp: (json['timestamp'] ?? '') as String,
      hazardType: (json['hazard_type'] ?? '') as String,
      hazardName: (json['hazard_name'] ?? json['hazard_type'] ?? '') as String,
      severity: (json['severity'] ?? 'MEDIUM') as String,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'hazard_type': hazardType,
        'hazard_name': hazardName,
        'severity': severity,
        'confidence': confidence,
      };
}

class ReportAlertItemModel {
  final String id;
  final String title;
  final String severity;
  final String status;
  final String createdAt;

  const ReportAlertItemModel({
    required this.id,
    required this.title,
    required this.severity,
    required this.status,
    required this.createdAt,
  });

  factory ReportAlertItemModel.fromJson(Map<String, dynamic> json) {
    return ReportAlertItemModel(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      severity: (json['severity'] ?? 'LOW') as String,
      status: (json['status'] ?? 'OPEN') as String,
      createdAt: (json['created_at'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'severity': severity,
        'status': status,
        'created_at': createdAt,
      };
}

class FieldEvidenceReportModel {
  final String reportId;
  final String reportTitle;
  final String farmId;
  final String farmName;
  final String? location;
  final String? cropType;
  final String zoneId;
  final String? zoneName;
  final String? soilType;
  final String generatedAt;
  final String scanTime;
  final ReportPeriodModel? period;
  final String healthStatus;
  final String healthLabel;
  final String summaryEn;
  final String summaryHi;
  final double moisture;
  final double temperature;
  final double humidity;
  final double ph;
  final List<ReportHazardItemModel> hazardHistory;
  final List<ReportAlertItemModel> alertsHistory;
  final List<InterventionHistoryItemModel> interventionsHistory;
  final String recommendationMade;
  final List<String> recommendations;
  final String actionExecuted;
  final String? actionApprovedBy;
  final Map<String, dynamic>? beforeAfterMetrics;
  final String verificationOutcome;
  final String disclaimer;
  final String? pdfBase64;

  const FieldEvidenceReportModel({
    required this.reportId,
    required this.reportTitle,
    required this.farmId,
    required this.farmName,
    this.location,
    this.cropType,
    required this.zoneId,
    this.zoneName,
    this.soilType,
    required this.generatedAt,
    required this.scanTime,
    this.period,
    required this.healthStatus,
    required this.healthLabel,
    required this.summaryEn,
    required this.summaryHi,
    required this.moisture,
    required this.temperature,
    required this.humidity,
    required this.ph,
    required this.hazardHistory,
    required this.alertsHistory,
    required this.interventionsHistory,
    required this.recommendationMade,
    required this.recommendations,
    required this.actionExecuted,
    this.actionApprovedBy,
    this.beforeAfterMetrics,
    required this.verificationOutcome,
    required this.disclaimer,
    this.pdfBase64,
  });

  factory FieldEvidenceReportModel.fromJson(Map<String, dynamic> json) {
    final periodMap = json['period'] as Map<String, dynamic>?;
    final healthMap = json['field_health_summary'] as Map<String, dynamic>?;
    final sensorMap = (json['sensor_evidence'] as Map<String, dynamic>?) ?? {};
    final rawHazards = (json['hazard_history'] as List?) ?? [];
    final rawAlerts = (json['alerts_history'] as List?) ?? [];
    final rawInterventions = (json['interventions_history'] as List?) ?? [];
    final rawRecs = (json['recommendations'] as List?) ?? [];

    return FieldEvidenceReportModel(
      reportId: (json['report_id'] ?? '') as String,
      reportTitle: (json['report_title'] ?? 'PRAHAR Field Evidence Report') as String,
      farmId: (json['farm_id'] ?? '') as String,
      farmName: (json['farm_name'] ?? '') as String,
      location: json['location'] as String?,
      cropType: json['crop_type'] as String?,
      zoneId: (json['zone_id'] ?? '') as String,
      zoneName: json['zone_name'] as String?,
      soilType: json['soil_type'] as String?,
      generatedAt: (json['generated_at'] ?? '') as String,
      scanTime: (json['scan_time'] ?? '') as String,
      period: periodMap != null ? ReportPeriodModel.fromJson(periodMap) : null,
      healthStatus: (healthMap?['status'] ?? 'OPTIMAL') as String,
      healthLabel: (healthMap?['health_label'] ?? 'PRAHAR Field-Health & Risk Summary') as String,
      summaryEn: (healthMap?['summary_en'] ?? '') as String,
      summaryHi: (healthMap?['summary_hi'] ?? '') as String,
      moisture: (sensorMap['moisture'] as num?)?.toDouble() ?? 0.0,
      temperature: (sensorMap['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (sensorMap['humidity'] as num?)?.toDouble() ?? 0.0,
      ph: (sensorMap['ph'] as num?)?.toDouble() ?? 7.0,
      hazardHistory: rawHazards.map((h) => ReportHazardItemModel.fromJson(h as Map<String, dynamic>)).toList(),
      alertsHistory: rawAlerts.map((a) => ReportAlertItemModel.fromJson(a as Map<String, dynamic>)).toList(),
      interventionsHistory: rawInterventions.map((i) => InterventionHistoryItemModel.fromJson(i as Map<String, dynamic>)).toList(),
      recommendationMade: (json['recommendation_made'] ?? '') as String,
      recommendations: rawRecs.map((r) => r.toString()).toList(),
      actionExecuted: (json['action_executed'] ?? 'Routine Agronomic Observation') as String,
      actionApprovedBy: json['action_approved_by'] as String?,
      beforeAfterMetrics: json['before_after_metrics'] as Map<String, dynamic>?,
      verificationOutcome: (json['verification_outcome'] ?? '') as String,
      disclaimer: (json['disclaimer'] ?? '') as String,
      pdfBase64: json['pdf_base64'] as String?,
    );
  }
}

// ============================================================================
// Phase 6B-4: Opportunity & Scheme Center Models
// ============================================================================

enum OpportunityType {
  scheme,
  subsidy,
  loan,
  insurance,
  support;

  static OpportunityType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'SUBSIDY':
        return OpportunityType.subsidy;
      case 'LOAN':
        return OpportunityType.loan;
      case 'INSURANCE':
        return OpportunityType.insurance;
      case 'SUPPORT':
        return OpportunityType.support;
      case 'SCHEME':
      default:
        return OpportunityType.scheme;
    }
  }

  String toDbString() {
    switch (this) {
      case OpportunityType.subsidy:
        return 'SUBSIDY';
      case OpportunityType.loan:
        return 'LOAN';
      case OpportunityType.insurance:
        return 'INSURANCE';
      case OpportunityType.support:
        return 'SUPPORT';
      case OpportunityType.scheme:
        return 'SCHEME';
    }
  }
}

enum OpportunityVerificationStatus {
  verified,
  needsVerification;

  static OpportunityVerificationStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'NEEDS_VERIFICATION':
        return OpportunityVerificationStatus.needsVerification;
      case 'VERIFIED':
      default:
        return OpportunityVerificationStatus.verified;
    }
  }

  String toDbString() => this == OpportunityVerificationStatus.verified ? 'VERIFIED' : 'NEEDS_VERIFICATION';
}

enum ApplicationTrackingStatus {
  notStarted,
  preparing,
  readyToApply,
  userSubmitted,
  completed;

  static ApplicationTrackingStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'PREPARING':
        return ApplicationTrackingStatus.preparing;
      case 'READY_TO_APPLY':
        return ApplicationTrackingStatus.readyToApply;
      case 'USER_SUBMITTED':
        return ApplicationTrackingStatus.userSubmitted;
      case 'COMPLETED':
        return ApplicationTrackingStatus.completed;
      case 'NOT_STARTED':
      default:
        return ApplicationTrackingStatus.notStarted;
    }
  }

  String toDbString() {
    switch (this) {
      case ApplicationTrackingStatus.preparing:
        return 'PREPARING';
      case ApplicationTrackingStatus.readyToApply:
        return 'READY_TO_APPLY';
      case ApplicationTrackingStatus.userSubmitted:
        return 'USER_SUBMITTED';
      case ApplicationTrackingStatus.completed:
        return 'COMPLETED';
      case ApplicationTrackingStatus.notStarted:
        return 'NOT_STARTED';
    }
  }

  String labelEn() {
    switch (this) {
      case ApplicationTrackingStatus.preparing:
        return 'Preparing Documents';
      case ApplicationTrackingStatus.readyToApply:
        return 'Ready to Apply';
      case ApplicationTrackingStatus.userSubmitted:
        return 'Application Submitted (Self-Reported)';
      case ApplicationTrackingStatus.completed:
        return 'Completed';
      case ApplicationTrackingStatus.notStarted:
        return 'Not Started';
    }
  }

  String labelHi() {
    switch (this) {
      case ApplicationTrackingStatus.preparing:
        return 'दस्तावेज तैयार हो रहे हैं';
      case ApplicationTrackingStatus.readyToApply:
        return 'आवेदन के लिए तैयार';
      case ApplicationTrackingStatus.userSubmitted:
        return 'आवेदन जमा किया गया (स्वयं सूचित)';
      case ApplicationTrackingStatus.completed:
        return 'पूर्ण हुआ';
      case ApplicationTrackingStatus.notStarted:
        return 'प्रारंभ नहीं हुआ';
    }
  }
}

enum EligibilityResultStatus {
  likelyEligible,
  mayBeEligible,
  insufficientInformation,
  likelyNotEligible;

  static EligibilityResultStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'MAY_BE_ELIGIBLE':
        return EligibilityResultStatus.mayBeEligible;
      case 'INSUFFICIENT_INFORMATION':
        return EligibilityResultStatus.insufficientInformation;
      case 'LIKELY_NOT_ELIGIBLE':
        return EligibilityResultStatus.likelyNotEligible;
      case 'LIKELY_ELIGIBLE':
      default:
        return EligibilityResultStatus.likelyEligible;
    }
  }

  String toDbString() {
    switch (this) {
      case EligibilityResultStatus.mayBeEligible:
        return 'MAY_BE_ELIGIBLE';
      case EligibilityResultStatus.insufficientInformation:
        return 'INSUFFICIENT_INFORMATION';
      case EligibilityResultStatus.likelyNotEligible:
        return 'LIKELY_NOT_ELIGIBLE';
      case EligibilityResultStatus.likelyEligible:
        return 'LIKELY_ELIGIBLE';
    }
  }

  String labelEn() {
    switch (this) {
      case EligibilityResultStatus.likelyEligible:
        return 'Likely Eligible';
      case EligibilityResultStatus.mayBeEligible:
        return 'May Be Eligible';
      case EligibilityResultStatus.insufficientInformation:
        return 'Insufficient Profile Information';
      case EligibilityResultStatus.likelyNotEligible:
        return 'Likely Not Eligible';
    }
  }

  String labelHi() {
    switch (this) {
      case EligibilityResultStatus.likelyEligible:
        return 'संभावित रूप से पात्र';
      case EligibilityResultStatus.mayBeEligible:
        return 'शायद पात्र';
      case EligibilityResultStatus.insufficientInformation:
        return 'अधूरी प्रोफाइल जानकारी';
      case EligibilityResultStatus.likelyNotEligible:
        return 'संभावित रूप से अपात्र';
    }
  }
}

class OpportunityApplicationStepModel {
  final int stepNumber;
  final String titleEn;
  final String titleHi;
  final String descriptionEn;
  final String descriptionHi;
  final bool isOnline;
  final String? portalUrl;

  const OpportunityApplicationStepModel({
    required this.stepNumber,
    required this.titleEn,
    required this.titleHi,
    required this.descriptionEn,
    required this.descriptionHi,
    required this.isOnline,
    this.portalUrl,
  });

  factory OpportunityApplicationStepModel.fromJson(Map<String, dynamic> json) {
    return OpportunityApplicationStepModel(
      stepNumber: (json['step_number'] as num?)?.toInt() ?? 1,
      titleEn: (json['title_en'] ?? '') as String,
      titleHi: (json['title_hi'] ?? '') as String,
      descriptionEn: (json['description_en'] ?? '') as String,
      descriptionHi: (json['description_hi'] ?? '') as String,
      isOnline: json['is_online'] == true,
      portalUrl: json['portal_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'step_number': stepNumber,
    'title_en': titleEn,
    'title_hi': titleHi,
    'description_en': descriptionEn,
    'description_hi': descriptionHi,
    'is_online': isOnline,
    if (portalUrl != null) 'portal_url': portalUrl,
  };
}

class OpportunityModel {
  final String id;
  final String schemeId;
  final String titleEn;
  final String titleHi;
  final OpportunityType type;
  final String category;
  final String departmentAuthority;
  final String descriptionEn;
  final String descriptionHi;
  final String benefitsSummaryEn;
  final String benefitsSummaryHi;
  final String targetProfileEn;
  final String targetProfileHi;
  final List<String> eligibilityCriteriaEn;
  final List<String> eligibilityCriteriaHi;
  final List<String> requiredDocuments;
  final String officialPortalUrl;
  final String applicationProcedureSummaryEn;
  final String applicationProcedureSummaryHi;
  final List<OpportunityApplicationStepModel> applicationSteps;
  final String praharAssistanceNoteEn;
  final String praharAssistanceNoteHi;
  final String lastVerifiedAt;
  final OpportunityVerificationStatus status;
  final String disclaimer;

  const OpportunityModel({
    required this.id,
    required this.schemeId,
    required this.titleEn,
    required this.titleHi,
    required this.type,
    required this.category,
    required this.departmentAuthority,
    required this.descriptionEn,
    required this.descriptionHi,
    required this.benefitsSummaryEn,
    required this.benefitsSummaryHi,
    required this.targetProfileEn,
    required this.targetProfileHi,
    required this.eligibilityCriteriaEn,
    required this.eligibilityCriteriaHi,
    required this.requiredDocuments,
    required this.officialPortalUrl,
    required this.applicationProcedureSummaryEn,
    required this.applicationProcedureSummaryHi,
    required this.applicationSteps,
    required this.praharAssistanceNoteEn,
    required this.praharAssistanceNoteHi,
    required this.lastVerifiedAt,
    required this.status,
    required this.disclaimer,
  });

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    final rawSteps = (json['application_steps'] as List?) ?? [];
    final rawDocs = (json['required_documents'] as List?) ?? [];
    final rawCritEn = (json['eligibility_criteria_en'] as List?) ?? [];
    final rawCritHi = (json['eligibility_criteria_hi'] as List?) ?? [];

    return OpportunityModel(
      id: (json['id'] ?? json['scheme_id'] ?? '') as String,
      schemeId: (json['scheme_id'] ?? json['id'] ?? '') as String,
      titleEn: (json['title_en'] ?? '') as String,
      titleHi: (json['title_hi'] ?? '') as String,
      type: OpportunityType.fromString(json['type'] as String?),
      category: (json['category'] ?? '') as String,
      departmentAuthority: (json['department_authority'] ?? json['sponsoring_agency'] ?? '') as String,
      descriptionEn: (json['description_en'] ?? '') as String,
      descriptionHi: (json['description_hi'] ?? '') as String,
      benefitsSummaryEn: (json['benefits_summary_en'] ?? '') as String,
      benefitsSummaryHi: (json['benefits_summary_hi'] ?? '') as String,
      targetProfileEn: (json['target_profile_en'] ?? '') as String,
      targetProfileHi: (json['target_profile_hi'] ?? '') as String,
      eligibilityCriteriaEn: rawCritEn.map((e) => e.toString()).toList(),
      eligibilityCriteriaHi: rawCritHi.map((e) => e.toString()).toList(),
      requiredDocuments: rawDocs.map((e) => e.toString()).toList(),
      officialPortalUrl: (json['official_portal_url'] ?? '') as String,
      applicationProcedureSummaryEn: (json['application_procedure_summary_en'] ?? '') as String,
      applicationProcedureSummaryHi: (json['application_procedure_summary_hi'] ?? '') as String,
      applicationSteps: rawSteps.map((s) => OpportunityApplicationStepModel.fromJson(s as Map<String, dynamic>)).toList(),
      praharAssistanceNoteEn: (json['prahar_assistance_note_en'] ?? '') as String,
      praharAssistanceNoteHi: (json['prahar_assistance_note_hi'] ?? '') as String,
      lastVerifiedAt: (json['last_verified_at'] ?? '') as String,
      status: OpportunityVerificationStatus.fromString(json['status'] as String?),
      disclaimer: (json['disclaimer'] ?? 'Eligibility shown by PRAHAR is guidance only. Final eligibility is determined by the concerned government department/bank/authority.') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'scheme_id': schemeId,
    'title_en': titleEn,
    'title_hi': titleHi,
    'type': type.toDbString(),
    'category': category,
    'department_authority': departmentAuthority,
    'description_en': descriptionEn,
    'description_hi': descriptionHi,
    'benefits_summary_en': benefitsSummaryEn,
    'benefits_summary_hi': benefitsSummaryHi,
    'target_profile_en': targetProfileEn,
    'target_profile_hi': targetProfileHi,
    'eligibility_criteria_en': eligibilityCriteriaEn,
    'eligibility_criteria_hi': eligibilityCriteriaHi,
    'required_documents': requiredDocuments,
    'official_portal_url': officialPortalUrl,
    'application_procedure_summary_en': applicationProcedureSummaryEn,
    'application_procedure_summary_hi': applicationProcedureSummaryHi,
    'application_steps': applicationSteps.map((s) => s.toJson()).toList(),
    'prahar_assistance_note_en': praharAssistanceNoteEn,
    'prahar_assistance_note_hi': praharAssistanceNoteHi,
    'last_verified_at': lastVerifiedAt,
    'status': status.toDbString(),
    'disclaimer': disclaimer,
  };
}

class EligibilityEvaluationModel {
  final String opportunityId;
  final EligibilityResultStatus status;
  final List<String> matchedCriteriaEn;
  final List<String> matchedCriteriaHi;
  final List<String> unmatchedCriteriaEn;
  final List<String> unmatchedCriteriaHi;
  final List<String> missingInformationEn;
  final List<String> missingInformationHi;
  final String disclaimer;
  final String evaluatedAt;

  const EligibilityEvaluationModel({
    required this.opportunityId,
    required this.status,
    required this.matchedCriteriaEn,
    required this.matchedCriteriaHi,
    required this.unmatchedCriteriaEn,
    required this.unmatchedCriteriaHi,
    required this.missingInformationEn,
    required this.missingInformationHi,
    required this.disclaimer,
    required this.evaluatedAt,
  });

  factory EligibilityEvaluationModel.fromJson(Map<String, dynamic> json) {
    final rawMatchedEn = (json['matched_criteria_en'] as List?) ?? [];
    final rawMatchedHi = (json['matched_criteria_hi'] as List?) ?? [];
    final rawUnmatchedEn = (json['unmatched_criteria_en'] as List?) ?? [];
    final rawUnmatchedHi = (json['unmatched_criteria_hi'] as List?) ?? [];
    final rawMissingEn = (json['missing_information_en'] as List?) ?? [];
    final rawMissingHi = (json['missing_information_hi'] as List?) ?? [];

    return EligibilityEvaluationModel(
      opportunityId: (json['opportunity_id'] ?? '') as String,
      status: EligibilityResultStatus.fromString(json['status'] as String?),
      matchedCriteriaEn: rawMatchedEn.map((e) => e.toString()).toList(),
      matchedCriteriaHi: rawMatchedHi.map((e) => e.toString()).toList(),
      unmatchedCriteriaEn: rawUnmatchedEn.map((e) => e.toString()).toList(),
      unmatchedCriteriaHi: rawUnmatchedHi.map((e) => e.toString()).toList(),
      missingInformationEn: rawMissingEn.map((e) => e.toString()).toList(),
      missingInformationHi: rawMissingHi.map((e) => e.toString()).toList(),
      disclaimer: (json['disclaimer'] ?? 'Eligibility shown by PRAHAR is guidance only. Final eligibility is determined by the concerned government department/bank/authority.') as String,
      evaluatedAt: (json['evaluated_at'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'opportunity_id': opportunityId,
    'status': status.toDbString(),
    'matched_criteria_en': matchedCriteriaEn,
    'matched_criteria_hi': matchedCriteriaHi,
    'unmatched_criteria_en': unmatchedCriteriaEn,
    'unmatched_criteria_hi': unmatchedCriteriaHi,
    'missing_information_en': missingInformationEn,
    'missing_information_hi': missingInformationHi,
    'disclaimer': disclaimer,
    'evaluated_at': evaluatedAt,
  };
}

class OpportunityTrackingModel {
  final String id;
  final String userId;
  final String opportunityId;
  final ApplicationTrackingStatus status;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  const OpportunityTrackingModel({
    required this.id,
    required this.userId,
    required this.opportunityId,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OpportunityTrackingModel.fromJson(Map<String, dynamic> json) {
    return OpportunityTrackingModel(
      id: (json['id'] ?? '') as String,
      userId: (json['user_id'] ?? '') as String,
      opportunityId: (json['opportunity_id'] ?? '') as String,
      status: ApplicationTrackingStatus.fromString(json['status'] as String?),
      notes: json['notes'] as String?,
      createdAt: (json['created_at'] ?? '') as String,
      updatedAt: (json['updated_at'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'opportunity_id': opportunityId,
    'status': status.toDbString(),
    if (notes != null) 'notes': notes,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

class ApplicationGuideModel {
  final String opportunityId;
  final String titleEn;
  final String titleHi;
  final String departmentAuthority;
  final String officialPortalUrl;
  final List<String> requiredDocuments;
  final List<OpportunityApplicationStepModel> applicationSteps;
  final String praharAssistanceNoteEn;
  final String praharAssistanceNoteHi;
  final String disclaimer;

  const ApplicationGuideModel({
    required this.opportunityId,
    required this.titleEn,
    required this.titleHi,
    required this.departmentAuthority,
    required this.officialPortalUrl,
    required this.requiredDocuments,
    required this.applicationSteps,
    required this.praharAssistanceNoteEn,
    required this.praharAssistanceNoteHi,
    required this.disclaimer,
  });

  factory ApplicationGuideModel.fromJson(Map<String, dynamic> json) {
    final rawDocs = (json['required_documents'] as List?) ?? [];
    final rawSteps = (json['application_steps'] as List?) ?? [];

    return ApplicationGuideModel(
      opportunityId: (json['opportunity_id'] ?? '') as String,
      titleEn: (json['title_en'] ?? '') as String,
      titleHi: (json['title_hi'] ?? '') as String,
      departmentAuthority: (json['department_authority'] ?? '') as String,
      officialPortalUrl: (json['official_portal_url'] ?? '') as String,
      requiredDocuments: rawDocs.map((e) => e.toString()).toList(),
      applicationSteps: rawSteps.map((s) => OpportunityApplicationStepModel.fromJson(s as Map<String, dynamic>)).toList(),
      praharAssistanceNoteEn: (json['prahar_assistance_note_en'] ?? '') as String,
      praharAssistanceNoteHi: (json['prahar_assistance_note_hi'] ?? '') as String,
      disclaimer: (json['disclaimer'] ?? 'Eligibility shown by PRAHAR is guidance only. Final eligibility is determined by the concerned government department/bank/authority.') as String,
    );
  }
}
