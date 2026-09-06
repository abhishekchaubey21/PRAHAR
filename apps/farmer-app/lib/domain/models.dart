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
      name: (json['name'] ?? json['zone_name'] ?? '') as String,
      soilType: json['soil_type'] as String? ?? 'Loam',
      moisturePct: (json['moisture_pct'] as num?)?.toDouble() ?? 0.0,
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 25.0,
      humidityPct: (json['humidity_pct'] as num?)?.toDouble() ?? 50.0,
      ph: (json['ph'] as num?)?.toDouble() ?? 7.0,
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
