/// PRAHAR Phase 7B — Assistant Context Builder
/// Aggregates current farmer, farm, zone, telemetry, alert, and scheme state

import '../../domain/assistant_model.dart';
import '../../domain/farmer_profile.dart';
import '../../domain/models.dart';
import '../providers/demo_farm_dataset.dart';

class AssistantContextBuilder {
  static FarmerAssistantContext buildContext({
    dynamic profile,
    dynamic farm,
    List<ZoneModel>? zones,
    List<AlertModel>? alerts,
    List<RemediationVerificationModel>? verifications,
    List<Map<String, dynamic>>? opportunities,
    List<Map<String, dynamic>>? eligibleSchemes,
    String? language,
  }) {
    final effectiveProfile = profile ?? CanonicalDemoDataset.profile;
    final effectiveFarmSetup = CanonicalDemoDataset.farmSetup;

    String farmerName = CanonicalDemoDataset.farmerName;
    String farmerPhone = '9876543210';
    String farmerState = CanonicalDemoDataset.state;
    String farmerDistrict = CanonicalDemoDataset.district;
    String farmerVillage = CanonicalDemoDataset.village;
    String farmerLang = language ?? CanonicalDemoDataset.preferredLanguage;
    double landAcres = CanonicalDemoDataset.areaAcres;
    String ownership = CanonicalDemoDataset.ownershipType;
    String irrigation = CanonicalDemoDataset.irrigationStatus;
    String waterSrc = CanonicalDemoDataset.waterSource;
    String soil = CanonicalDemoDataset.soilType;

    if (effectiveProfile is FarmerProfileModel) {
      farmerName = effectiveProfile.name;
      farmerState = effectiveProfile.state;
      farmerDistrict = effectiveProfile.district;
      farmerVillage = effectiveProfile.village;
      farmerLang = language ?? effectiveProfile.preferredLanguage;
      landAcres = effectiveFarmSetup.areaAcres;
      ownership = effectiveFarmSetup.ownershipType;
      irrigation = effectiveFarmSetup.irrigationStatus;
      waterSrc = effectiveFarmSetup.waterSource;
      soil = effectiveFarmSetup.soilType;
    }

    String farmId = CanonicalDemoDataset.farmId;
    String farmName = CanonicalDemoDataset.farmName;
    double farmArea = landAcres;
    String farmCrop = CanonicalDemoDataset.cropType;

    if (farm is FarmModel) {
      farmId = farm.id;
      farmName = farm.name;
      farmArea = farm.areaAcres;
      farmCrop = farm.cropType;
      ownership = farm.ownershipType;
      irrigation = farm.irrigationStatus;
      waterSrc = farm.waterSource;
      soil = farm.soilType;
    } else if (farm is FarmSetupModel) {
      farmArea = farm.areaAcres;
      ownership = farm.ownershipType;
      irrigation = farm.irrigationStatus;
      waterSrc = farm.waterSource;
      soil = farm.soilType;
    }

    final effectiveZones = zones ?? CanonicalDemoDataset.zones;
    final effectiveAlerts = alerts ?? CanonicalDemoDataset.alerts;

    return FarmerAssistantContext(
      dataSource: 'DEMO',
      roverStatus: 'DISCONNECTED',
      farmer: {
        'id': CanonicalDemoDataset.farmerId,
        'name': farmerName,
        'phone': farmerPhone,
        'state': farmerState,
        'district': farmerDistrict,
        'village': farmerVillage,
        'language': farmerLang,
      },
      farm: {
        'id': farmId,
        'name': farmName,
        'area_acres': farmArea,
        'ownership_type': ownership,
        'irrigation_status': irrigation,
        'water_source': waterSrc,
        'soil_type': soil,
        'season': CanonicalDemoDataset.season,
        'crop_type': farmCrop,
      },
      zones: effectiveZones.map((z) {
        final zoneAlerts = effectiveAlerts.where((a) => a.zoneId == z.id).toList();
        return {
          'id': z.id,
          'name': z.name,
          'soil_type': z.soilType,
          'moisture_pct': z.moisturePct,
          'crop_type': z.cropType,
          'temperature_c': z.temperatureC,
          'humidity_pct': z.humidityPct,
          'ph': z.ph,
          'active_alert_count': zoneAlerts.length,
          'active_hazard': zoneAlerts.isNotEmpty ? zoneAlerts.first.message : null,
          'severity': zoneAlerts.any((a) => a.severity == AlertSeverity.high)
              ? 'HIGH'
              : 'LOW',
        };
      }).toList(),
      activeAlerts: effectiveAlerts.map((a) {
        return {
          'id': a.id,
          'zone_id': a.zoneId,
          'type': a.type.name,
          'severity': a.severity == AlertSeverity.high ? 'high' : 'medium',
          'message': a.message,
          'hazard': a.message,
          'recommended_action': a.recommendedAction,
        };
      }).toList(),
      latestVerification: (verifications != null && verifications.isNotEmpty)
          ? {
              'zone_id': verifications.first.zoneId,
              'pre_moisture': verifications.first.preMoisture,
              'post_moisture': verifications.first.postMoisture,
              'moisture_delta': verifications.first.moistureDelta,
              'resolved': verifications.first.resolved,
              'summary': verifications.first.summaryEn,
            }
          : {
              'zone_id': CanonicalDemoDataset.zone2Verification.zoneId,
              'pre_moisture': CanonicalDemoDataset.zone2Verification.preMoisture,
              'post_moisture': CanonicalDemoDataset.zone2Verification.postMoisture,
              'moisture_delta': CanonicalDemoDataset.zone2Verification.moistureDelta,
              'resolved': CanonicalDemoDataset.zone2Verification.resolved,
              'summary': CanonicalDemoDataset.zone2Verification.summaryEn,
            },
      eligibleSchemes: eligibleSchemes ??
          opportunities ??
          [
            {
              'scheme_id': 'pm-kisan',
              'title': 'PM-KISAN Samman Nidhi',
              'category': 'Direct Income Support',
              'official_url': 'https://pmkisan.gov.in',
            },
            {
              'scheme_id': 'pmfby',
              'title': 'Pradhan Mantri Fasal Bima Yojana',
              'category': 'Crop Insurance',
              'official_url': 'https://pmfby.gov.in',
            },
            {
              'scheme_id': 'smam',
              'title': 'Sub-Mission on Agricultural Mechanization',
              'category': 'Farm Equipment Subsidy',
              'official_url': 'https://agrimachinery.nic.in',
            },
          ],
    );
  }
}
