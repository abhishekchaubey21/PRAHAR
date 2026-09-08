/// PRAHAR Phase 7B — Domain Models for Contextual Field Assistant
/// Structured domain contracts mirroring packages/shared/src/domain.ts

enum AssistantIntent {
  fieldStatus,
  zoneStatus,
  hazardExplanation,
  recommendationExplanation,
  actionStatus,
  verificationStatus,
  schemeQuery,
  profileQuery,
  generalFarmGuidance,
  unknown,
}

extension AssistantIntentExtension on AssistantIntent {
  String toWireString() {
    switch (this) {
      case AssistantIntent.fieldStatus:
        return 'FIELD_STATUS';
      case AssistantIntent.zoneStatus:
        return 'ZONE_STATUS';
      case AssistantIntent.hazardExplanation:
        return 'HAZARD_EXPLANATION';
      case AssistantIntent.recommendationExplanation:
        return 'RECOMMENDATION_EXPLANATION';
      case AssistantIntent.actionStatus:
        return 'ACTION_STATUS';
      case AssistantIntent.verificationStatus:
        return 'VERIFICATION_STATUS';
      case AssistantIntent.schemeQuery:
        return 'SCHEME_QUERY';
      case AssistantIntent.profileQuery:
        return 'PROFILE_QUERY';
      case AssistantIntent.generalFarmGuidance:
        return 'GENERAL_FARM_GUIDANCE';
      case AssistantIntent.unknown:
        return 'UNKNOWN';
    }
  }

  static AssistantIntent fromWireString(String? wire) {
    switch (wire) {
      case 'FIELD_STATUS':
        return AssistantIntent.fieldStatus;
      case 'ZONE_STATUS':
        return AssistantIntent.zoneStatus;
      case 'HAZARD_EXPLANATION':
        return AssistantIntent.hazardExplanation;
      case 'RECOMMENDATION_EXPLANATION':
        return AssistantIntent.recommendationExplanation;
      case 'ACTION_STATUS':
        return AssistantIntent.actionStatus;
      case 'VERIFICATION_STATUS':
        return AssistantIntent.verificationStatus;
      case 'SCHEME_QUERY':
        return AssistantIntent.schemeQuery;
      case 'PROFILE_QUERY':
        return AssistantIntent.profileQuery;
      case 'GENERAL_FARM_GUIDANCE':
        return AssistantIntent.generalFarmGuidance;
      default:
        return AssistantIntent.unknown;
    }
  }
}

enum AssistantSafetyLevel {
  safeInformational,
  requiresConfirmation,
  prohibitedAutonomous,
}

extension AssistantSafetyLevelExtension on AssistantSafetyLevel {
  String toWireString() {
    switch (this) {
      case AssistantSafetyLevel.safeInformational:
        return 'SAFE_INFORMATIONAL';
      case AssistantSafetyLevel.requiresConfirmation:
        return 'REQUIRES_CONFIRMATION';
      case AssistantSafetyLevel.prohibitedAutonomous:
        return 'PROHIBITED_AUTONOMOUS';
    }
  }

  static AssistantSafetyLevel fromWireString(String? wire) {
    switch (wire) {
      case 'REQUIRES_CONFIRMATION':
        return AssistantSafetyLevel.requiresConfirmation;
      case 'PROHIBITED_AUTONOMOUS':
        return AssistantSafetyLevel.prohibitedAutonomous;
      case 'SAFE_INFORMATIONAL':
      default:
        return AssistantSafetyLevel.safeInformational;
    }
  }
}

enum AssistantActionType {
  irrigate,
  reScan,
  none,
}

extension AssistantActionTypeExtension on AssistantActionType {
  String toWireString() {
    switch (this) {
      case AssistantActionType.irrigate:
        return 'IRRIGATE';
      case AssistantActionType.reScan:
        return 'RE_SCAN';
      case AssistantActionType.none:
        return 'NONE';
    }
  }

  static AssistantActionType fromWireString(String? wire) {
    switch (wire) {
      case 'IRRIGATE':
        return AssistantActionType.irrigate;
      case 'RE_SCAN':
        return AssistantActionType.reScan;
      default:
        return AssistantActionType.none;
    }
  }
}

class AssistantPendingAction {
  final String actionType;
  final String zoneId;
  final int durationSeconds;
  final double volumeLiters;

  const AssistantPendingAction({
    required this.actionType,
    required this.zoneId,
    this.durationSeconds = 30,
    this.volumeLiters = 7.5,
  });

  String get id => 'pending-${actionType.toLowerCase()}-${zoneId.toLowerCase()}';
  bool get isSimulationOnly => true;

  factory AssistantPendingAction.fromJson(Map<String, dynamic> json) {
    return AssistantPendingAction(
      actionType: json['action_type'] as String? ?? 'IRRIGATE',
      zoneId: json['zone_id'] as String? ?? 'DEMO-ZONE-02',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 30,
      volumeLiters: (json['volume_liters'] as num?)?.toDouble() ?? 7.5,
    );
  }

  Map<String, dynamic> toJson() => {
        'action_type': actionType,
        'zone_id': zoneId,
        'duration_seconds': durationSeconds,
        'volume_liters': volumeLiters,
      };
}

class AssistantStructuredResponse {
  final String answer;
  final AssistantIntent intent;
  final String? referencedZone;
  final String severity; // HIGH, MEDIUM, LOW, NONE
  final String? evidence;
  final String? recommendation;
  final bool actionRequired;
  final AssistantActionType actionType;
  final bool requiresConfirmation;
  final AssistantSafetyLevel safetyLevel;
  final String simulationStatus;
  final String? indicativeDisclaimer;
  final AssistantPendingAction? pendingAction;

  String? get relevantZoneId => referencedZone;
  bool get isSimulationOnly =>
      simulationStatus.contains('SIMULATION') ||
      simulationStatus.contains('Disconnected');

  const AssistantStructuredResponse({
    required this.answer,
    required this.intent,
    this.referencedZone,
    this.severity = 'NONE',
    this.evidence,
    this.recommendation,
    this.actionRequired = false,
    this.actionType = AssistantActionType.none,
    this.requiresConfirmation = false,
    this.safetyLevel = AssistantSafetyLevel.safeInformational,
    this.simulationStatus = 'SIMULATION ONLY • Physical Rover Disconnected',
    this.indicativeDisclaimer,
    this.pendingAction,
  });

  factory AssistantStructuredResponse.fromJson(Map<String, dynamic> json) {
    return AssistantStructuredResponse(
      answer: json['answer'] as String? ?? '',
      intent: AssistantIntentExtension.fromWireString(json['intent'] as String?),
      referencedZone: json['referenced_zone'] as String?,
      severity: json['severity'] as String? ?? 'NONE',
      evidence: json['evidence'] as String?,
      recommendation: json['recommendation'] as String?,
      actionRequired: json['action_required'] as bool? ?? false,
      actionType: AssistantActionTypeExtension.fromWireString(json['action_type'] as String?),
      requiresConfirmation: json['requires_confirmation'] as bool? ?? false,
      safetyLevel: AssistantSafetyLevelExtension.fromWireString(json['safety_level'] as String?),
      simulationStatus: json['simulation_status'] as String? ?? 'SIMULATION ONLY • Physical Rover Disconnected',
      indicativeDisclaimer: json['indicative_disclaimer'] as String?,
      pendingAction: json['pending_action'] != null
          ? AssistantPendingAction.fromJson(json['pending_action'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'answer': answer,
        'intent': intent.toWireString(),
        'referenced_zone': referencedZone,
        'severity': severity,
        'evidence': evidence,
        'recommendation': recommendation,
        'action_required': actionRequired,
        'action_type': actionType.toWireString(),
        'requires_confirmation': requiresConfirmation,
        'safety_level': safetyLevel.toWireString(),
        'simulation_status': simulationStatus,
        'indicative_disclaimer': indicativeDisclaimer,
        'pending_action': pendingAction?.toJson(),
      };
}

class FarmerAssistantContext {
  final String dataSource; // strictly "DEMO"
  final String roverStatus; // strictly "DISCONNECTED"
  final Map<String, dynamic>? farmer;
  final Map<String, dynamic>? farm;
  final List<Map<String, dynamic>> zones;
  final List<Map<String, dynamic>> activeAlerts;
  final Map<String, dynamic>? latestVerification;
  final List<Map<String, dynamic>> eligibleSchemes;

  const FarmerAssistantContext({
    this.dataSource = 'DEMO',
    this.roverStatus = 'DISCONNECTED',
    this.farmer,
    this.farm,
    this.zones = const [],
    this.activeAlerts = const [],
    this.latestVerification,
    this.eligibleSchemes = const [],
  });

  factory FarmerAssistantContext.fromJson(Map<String, dynamic> json) {
    return FarmerAssistantContext(
      dataSource: json['data_source'] as String? ?? 'DEMO',
      roverStatus: json['rover_status'] as String? ?? 'DISCONNECTED',
      farmer: json['farmer'] as Map<String, dynamic>?,
      farm: json['farm'] as Map<String, dynamic>?,
      zones: (json['zones'] as List<dynamic>?)
              ?.map((z) => Map<String, dynamic>.from(z as Map))
              .toList() ??
          const [],
      activeAlerts: (json['active_alerts'] as List<dynamic>?)
              ?.map((a) => Map<String, dynamic>.from(a as Map))
              .toList() ??
          const [],
      latestVerification: json['latest_verification'] as Map<String, dynamic>?,
      eligibleSchemes: (json['eligible_schemes'] as List<dynamic>?)
              ?.map((s) => Map<String, dynamic>.from(s as Map))
              .toList() ??
          const [],
    );
  }

  String get farmerName => farmer?['name'] as String? ?? 'Ramesh Patil';
  String get farmName => farm?['name'] as String? ?? 'Patil Krishi Farm';
  double get landAcres => (farm?['area_acres'] as num?)?.toDouble() ?? 4.2;
  String get district => farmer?['district'] as String? ?? 'Amravati';
  String get state => farmer?['state'] as String? ?? 'Maharashtra';
  String get soilType => farm?['soil_type'] as String? ?? 'Black Cotton Loam';
  String get irrigationStatus => farm?['irrigation_status'] as String? ?? 'PARTIAL';
  bool get isSimulation => dataSource == 'DEMO' || roverStatus == 'DISCONNECTED';
  String get language => farmer?['language'] as String? ?? 'en';
  List<Map<String, dynamic>> get alerts => activeAlerts;

  Map<String, dynamic> toJson() => {
        'data_source': dataSource,
        'rover_status': roverStatus,
        if (farmer != null) 'farmer': farmer,
        if (farm != null) 'farm': farm,
        'zones': zones,
        'active_alerts': activeAlerts,
        if (latestVerification != null) 'latest_verification': latestVerification,
        'eligible_schemes': eligibleSchemes,
      };
}

class AssistantQueryRequest {
  final String query;
  final String language;
  final String? sessionId;
  final FarmerAssistantContext? context;
  final bool? confirmAction;
  final String? pendingActionId;

  const AssistantQueryRequest({
    required this.query,
    this.language = 'en',
    this.sessionId,
    this.context,
    this.confirmAction,
    this.pendingActionId,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'language': language,
        if (sessionId != null) 'session_id': sessionId,
        if (context != null) 'context': context!.toJson(),
        if (confirmAction != null) 'confirm_action': confirmAction,
        if (pendingActionId != null) 'pending_action_id': pendingActionId,
      };
}
