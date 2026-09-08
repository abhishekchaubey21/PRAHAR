import 'package:flutter_test/flutter_test.dart';
import 'package:farmer_app/domain/models.dart';
import 'package:farmer_app/data/providers/demo_farm_dataset.dart';
import 'package:farmer_app/data/providers/telemetry_provider.dart';

void main() {
  group('Phase 7A: Canonical Demo Dataset & Determinism Tests', () {
    test('Canonical Profile: Ramesh Patil • Amravati, Maharashtra • 4.2 Acres • Owned', () {
      final demo = CanonicalDemoFarmDataset.profile;

      expect(demo.name, 'Ramesh Patil');
      expect(demo.state, 'Maharashtra');
      expect(demo.district, 'Amravati');
      expect(demo.village, 'Nandgaon Khandeshwar');
      expect(demo.preferredLanguage, 'en');

      final farm = CanonicalDemoFarmDataset.farmSetup;
      expect(farm.areaAcres, 4.2);
      expect(farm.landAcres, 4.2);
      expect(farm.ownershipType, 'OWNED');
      expect(farm.irrigationStatus, 'PARTIAL');
      expect(farm.waterSource, 'BOREWELL');
      expect(farm.soilType, 'Black Cotton Loam');

      final crops = CanonicalDemoFarmDataset.crops;
      expect(crops.mainCrops, containsAll(['Soybean', 'Wheat']));
      expect(crops.season, 'KHARIF');
    });

    test('Canonical 4 Zones: Deterministic values matching specification exactly', () {
      final zones = CanonicalDemoFarmDataset.zones;
      expect(zones.length, 4);

      // Zone 1 — North Plot (Soybean Healthy)
      final z1 = zones[0];
      expect(z1.name, contains('Zone 1 — North Plot'));
      expect(z1.cropType, 'Soybean');
      expect(z1.moisturePct, 32.4);
      expect(z1.temperatureC, 26.2);
      expect(z1.humidityPct, 58.0);
      expect(z1.ph, 6.8);
      expect(z1.soilType, 'Black Cotton Loam');

      // Zone 2 — East Sector (Soybean Water Stress)
      final z2 = zones[1];
      expect(z2.name, contains('Zone 2 — East Sector'));
      expect(z2.cropType, 'Soybean');
      expect(z2.moisturePct, 16.8);
      expect(z2.temperatureC, 34.5);
      expect(z2.humidityPct, 38.0);
      expect(z2.ph, 6.5);

      // Zone 3 — South Sector (Wheat Pest Infestation)
      final z3 = zones[2];
      expect(z3.name, contains('Zone 3 — South Sector'));
      expect(z3.cropType, 'Wheat');
      expect(z3.moisturePct, 28.5);
      expect(z3.temperatureC, 29.1);
      expect(z3.humidityPct, 74.0);
      expect(z3.ph, 6.4);

      // Zone 4 — West Sector (Wheat Nutrient Deficiency)
      final z4 = zones[3];
      expect(z4.name, contains('Zone 4 — West Sector'));
      expect(z4.cropType, 'Wheat');
      expect(z4.moisturePct, 24.2);
      expect(z4.temperatureC, 28.0);
      expect(z4.humidityPct, 52.0);
      expect(z4.ph, 7.8);
    });

    test('Canonical Alerts: All 4 scenarios with honest AI detection label', () {
      final alerts = CanonicalDemoFarmDataset.alerts;
      expect(alerts.length, 3); // Zones 2, 3, 4 generate alerts; Zone 1 has no alert

      // Water Stress Alert (Zone 2)
      final waterAlert = alerts.firstWhere((a) => a.zoneId == 'DEMO-ZONE-02');
      expect(waterAlert.type, HazardType.waterStress);
      expect(waterAlert.severity, AlertSeverity.high);
      expect(waterAlert.message, contains('16.8%'));
      expect(waterAlert.recommendedAction, contains('micro-irrigation'));

      // Pest Infestation Alert (Zone 3)
      final pestAlert = alerts.firstWhere((a) => a.zoneId == 'DEMO-ZONE-03');
      expect(pestAlert.type, HazardType.pest);
      expect(pestAlert.severity, AlertSeverity.high);
      expect(pestAlert.message, contains('Fall Armyworm'));
      expect(pestAlert.message, contains('Demo AI Detection • YOLOv8-compatible scenario'));
      expect(pestAlert.recommendedAction, contains('pheromone'));

      // Nutrient Deficiency Alert (Zone 4)
      final nutrientAlert = alerts.firstWhere((a) => a.zoneId == 'DEMO-ZONE-04');
      expect(nutrientAlert.type, HazardType.nutrientDeficiency);
      expect(nutrientAlert.severity, AlertSeverity.medium);
      expect(nutrientAlert.message, contains('Nitrogen chlorosis'));
      expect(nutrientAlert.message, contains('Demo AI Detection'));
      expect(nutrientAlert.recommendedAction, contains('urea foliar spray'));
    });
  });

  group('Phase 7A: ITelemetryProvider & Closed-Loop Simulation Lifecycle', () {
    late ITelemetryProvider telemetryProvider;

    setUp(() {
      telemetryProvider = DemoFieldDataProvider();
    });

    test('Provider Contract: Explicitly declares DataSource.demo and isSimulated == true', () {
      expect(telemetryProvider.dataSource, DataSource.demo);
      expect(telemetryProvider.isSimulated, isTrue);
    });

    test('Rover Status Contract: Provides simulated telemetry without claiming live connection', () async {
      final rover = await telemetryProvider.getRoverStatus();
      expect(rover.roverId, 'ROVER-DEMO-01');
      expect(rover.state, 'IDLE');
      expect(rover.batteryPct, 95.0);
      expect(rover.isOffline, isFalse);
    });

    test('Closed-Loop Lifecycle on Zone 2: SCAN → ACTION → RE-SCAN → VERIFIED', () async {
      // 1. Initial Scan: Zone 2 has moisture 16.8%
      final initialZones = await telemetryProvider.getZones('farm-canonical-demo');
      final z2Initial = initialZones.firstWhere((z) => z.id == 'DEMO-ZONE-02');
      expect(z2Initial.moisturePct, 16.8);

      // 2. Alert generated
      final alerts = await telemetryProvider.getAlerts();
      final alertZ2 = alerts.firstWhere((a) => a.zoneId == 'DEMO-ZONE-02');
      expect(alertZ2.isApproved, isFalse);

      // 3. Execute Simulated Remediation (30s micro-irrigation)
      final verification = await telemetryProvider.executeSimulatedRemediation(
        alertZ2.id,
        alertZ2.zoneId,
      );

      // 4. Closed-loop verification asserts exact numbers from specification:
      // Pre: 16.8%, Post: 28.2%, Delta: +11.4%, Status: RESOLVED
      expect(verification, isNotNull);
      expect(verification!.zoneId, 'DEMO-ZONE-02');
      expect(verification.preMoisture, 16.8);
      expect(verification.postMoisture, 28.2);
      expect(verification.moistureDelta, 11.4);
      expect(verification.resolved, isTrue);
      expect(verification.summaryEn, contains('Simulated Remediation'));
      expect(verification.summaryEn, contains('16.8% to 28.2% (+11.4% delta)'));

      // 5. Re-scan: Zone 2 moisture is updated to post-remediation moisture
      final rescanZones = await telemetryProvider.getZones('farm-canonical-demo');
      final z2Post = rescanZones.firstWhere((z) => z.id == 'DEMO-ZONE-02');
      expect(z2Post.moisturePct, 28.2);
    });
  });
}
