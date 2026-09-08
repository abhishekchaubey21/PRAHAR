/// PRAHAR Canonical Deterministic Demo Farm Dataset
/// Aligned with Phase 7A: Realistic Indian Agricultural Scenario (Maharashtra)
/// DO NOT generate random numbers on app launch. All values are deterministic.

import '../../domain/models.dart';
import '../../domain/farmer_profile.dart';

class CanonicalDemoDataset {
  // Canonical Farmer
  static const String farmerId = '00000000-0000-0000-0000-000000000001';
  static const String farmerName = 'Ramesh Patil';
  static const String state = 'Maharashtra';
  static const String district = 'Amravati';
  static const String village = 'Nandgaon Khandeshwar';
  static const String preferredLanguage = 'en';

  // Canonical Farm
  static const String farmId = '00000000-0000-0000-0000-000000000002';
  static const String farmName = 'Patil Krishi Farm (पाटील कृषी फार्म)';
  static const String location = 'Amravati, Maharashtra';
  static const double areaAcres = 4.2;
  static const double totalHectares = 1.7;
  static const String ownershipType = 'OWNED';
  static const String irrigationStatus = 'PARTIAL'; // Borewell + Rainfed
  static const String waterSource = 'BOREWELL';
  static const String soilType = 'Black Cotton Loam';
  static const String cropType = 'Soybean + Wheat';
  static const String season = 'KHARIF';

  static FarmModel get farm => const FarmModel(
        id: farmId,
        name: farmName,
        location: location,
        totalHectares: totalHectares,
        farmerId: farmerId,
        areaAcres: areaAcres,
        cropType: cropType,
        ownershipType: ownershipType,
        irrigationStatus: irrigationStatus,
        waterSource: waterSource,
        soilType: soilType,
        season: season,
      );

  static FarmerOnboardingState get onboardingState => const FarmerOnboardingState(
        profile: FarmerProfileModel(
          name: farmerName,
          state: state,
          district: district,
          village: village,
          preferredLanguage: preferredLanguage,
        ),
        farm: FarmSetupModel(
          areaAcres: areaAcres,
          ownershipType: ownershipType,
          irrigationStatus: irrigationStatus,
          waterSource: waterSource,
          soilType: soilType,
        ),
        crops: CropSetupModel(
          mainCrops: ['Soybean', 'Wheat'],
          season: 'KHARIF',
          variety: 'JS 335 (Kharif) / GW 322 (Rabi)',
          sowingDate: '2026-06-25',
        ),
        isCompleted: true,
        completedAt: '2026-09-08T00:00:00Z',
      );

  static FarmerProfileModel get profile => onboardingState.profile;
  static FarmSetupModel get farmSetup => onboardingState.farm;
  static CropSetupModel get crops => onboardingState.crops;
  static List<AlertModel> get alerts => initialAlerts;

  // Canonical Rover Telemetry (Simulated)
  static RoverStatusModel get roverStatus => const RoverStatusModel(
        roverId: 'ROVER-DEMO-01',
        state: 'IDLE',
        batteryPct: 95.0,
        currentZone: 'Zone 1 — North Plot',
        isOffline: false,
        gpsLat: 20.9374,
        gpsLng: 77.7796,
        fieldCoveragePct: 100.0,
        isSimulated: true,
        dataSource: 'DEMO',
      );

  // 4 Deterministic Zones
  static List<ZoneModel> get zones => [
        ZoneModel(
          id: 'DEMO-ZONE-01',
          name: 'Zone 1 — North Plot (Soybean Healthy)',
          cropType: 'Soybean',
          soilType: 'Black Cotton Loam',
          moisturePct: 32.4,
          temperatureC: 26.2,
          humidityPct: 58.0,
          ph: 6.8,
          lastScanAt: DateTime.parse('2026-09-08T08:00:00Z'),
        ),
        ZoneModel(
          id: 'DEMO-ZONE-02',
          name: 'Zone 2 — East Sector (Soybean Water Stress)',
          cropType: 'Soybean',
          soilType: 'Sandy Loam',
          moisturePct: 16.8,
          temperatureC: 34.5,
          humidityPct: 38.0,
          ph: 6.5,
          lastScanAt: DateTime.parse('2026-09-08T08:30:00Z'),
        ),
        ZoneModel(
          id: 'DEMO-ZONE-03',
          name: 'Zone 3 — South Sector (Wheat Pest Alert)',
          cropType: 'Wheat',
          soilType: 'Silt Loam',
          moisturePct: 28.5,
          temperatureC: 29.1,
          humidityPct: 74.0,
          ph: 6.4,
          lastScanAt: DateTime.parse('2026-09-08T09:00:00Z'),
        ),
        ZoneModel(
          id: 'DEMO-ZONE-04',
          name: 'Zone 4 — West Sector (Wheat Nutrient Deficiency)',
          cropType: 'Wheat',
          soilType: 'Clay Loam',
          moisturePct: 24.2,
          temperatureC: 28.0,
          humidityPct: 52.0,
          ph: 7.8,
          lastScanAt: DateTime.parse('2026-09-08T09:30:00Z'),
        ),
      ];

  // Deterministic Alerts for Scenarios 2, 3, and 4
  static List<AlertModel> get initialAlerts => [
        AlertModel(
          id: 'ALERT-DEMO-02',
          zoneId: 'DEMO-ZONE-02',
          zoneName: 'Zone 2 — East Sector',
          type: HazardType.waterStress,
          severity: AlertSeverity.high,
          message:
              'Zone 2 root-zone soil moisture dropped to 16.8% (Critical Deficit below 20%). Risk of crop wilting.',
          messageHi:
              'ज़ोन 2 में मिट्टी की नमी घटकर 16.8% रह गई है (20% से नीचे गंभीर कमी)। फसल सूखने का जोखिम।',
          recommendedAction:
              'Discharge targeted micro-irrigation (30 seconds) via rover nozzle to restore root-zone hydration.',
          recommendedActionHi:
              'जड़ क्षेत्र में नमी बहाल करने के लिए रोवर नोजल द्वारा लक्षित सूक्ष्म-सिंचाई (30 सेकंड) चलाएं।',
          status: AlertStatus.newAlert,
          timestamp: DateTime.parse('2026-09-08T08:32:00Z'),
          isApproved: false,
        ),
        AlertModel(
          id: 'ALERT-DEMO-03',
          zoneId: 'DEMO-ZONE-03',
          zoneName: 'Zone 3 — South Sector',
          type: HazardType.pest,
          severity: AlertSeverity.high,
          message:
              'Pest Infestation detected: Fall Armyworm (Spodoptera frugiperda) foliage damage. [Demo AI Detection • YOLOv8-compatible scenario, 89% confidence]',
          messageHi:
              'कीट प्रकोप का पता चला: फॉल आर्मीवर्म (स्पोडोप्टेरा फ्रूगीपर्डा) पत्तियों का नुकसान। [डेमो एआई पहचान • YOLOv8-संगत परिदृश्य, 89% विश्वास]',
          recommendedAction:
              'Install pheromone lure traps and apply neem biopesticide; schedule expert inspection.',
          recommendedActionHi:
              'फेरोमोन ल्यूर ट्रैप लगाएं और नीम आधारित बायोपेस्टीसाइड का छिड़काव करें; विशेषज्ञ निरीक्षण तय करें।',
          status: AlertStatus.newAlert,
          timestamp: DateTime.parse('2026-09-08T09:05:00Z'),
          isApproved: false,
        ),
        AlertModel(
          id: 'ALERT-DEMO-04',
          zoneId: 'DEMO-ZONE-04',
          zoneName: 'Zone 4 — West Sector',
          type: HazardType.nutrientDeficiency,
          severity: AlertSeverity.medium,
          message:
              'Nutrient Deficiency observed: Nitrogen chlorosis (Leaf yellowing), soil pH 7.8 elevated. [Demo AI Detection, 82% confidence]',
          messageHi:
              'पोषक तत्व की कमी देखी गई: नाइट्रोजन क्लोरोसिस (पत्तियों का पीलापन), मिट्टी का पीएच 7.8 बढ़ा हुआ। [डेमो एआई पहचान, 82% विश्वास]',
          recommendedAction:
              'Apply split-dose urea foliar spray (2%) and gypsum soil amendment to normalize pH.',
          recommendedActionHi:
              'पीएच सामान्य करने के लिए 2% यूरिया पर्णीय छिड़काव और जिप्सम मिट्टी सुधारक डालें।',
          status: AlertStatus.newAlert,
          timestamp: DateTime.parse('2026-09-08T09:35:00Z'),
          isApproved: false,
        ),
      ];

  // Closed-Loop Verification Record for Zone 2
  static RemediationVerificationModel get zone2Verification =>
      RemediationVerificationModel(
        zoneId: 'DEMO-ZONE-02',
        preMoisture: 16.8,
        postMoisture: 28.2,
        moistureDelta: 11.4,
        resolved: true,
        summaryEn:
            'Zone 2 Simulated Remediation Verified: Soil moisture restored from 16.8% to 28.2% (+11.4% delta). Water stress resolved.',
        summaryHi:
            'ज़ोन 2 सिमुलेटेड उपचार सत्यापित: मिट्टी की नमी 16.8% से बढ़कर 28.2% (+11.4% वृद्धि) हो गई। जल तनाव हल हुआ।',
      );
}

typedef CanonicalDemoFarmDataset = CanonicalDemoDataset;
