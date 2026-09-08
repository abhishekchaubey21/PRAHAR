/// PRAHAR Telemetry Abstraction Layer
/// Aligned with Phase 7A:
/// Provides clean telemetry contracts separating DEMO and future LIVE telemetry.
/// Architecture:
/// Current: DemoFieldDataProvider -> Data Contracts -> Farmer App
/// Future:  LiveRoverTelemetryProvider -> Same Data Contracts -> Farmer App

import '../../domain/models.dart';
import 'demo_farm_dataset.dart';

enum DataSource { demo, live }

abstract class ITelemetryProvider {
  Future<RoverStatusModel> getRoverStatus();
  Future<List<ZoneModel>> getZones(String farmId);
  Future<List<AlertModel>> getAlerts();
  Future<RemediationVerificationModel?> executeSimulatedRemediation(
      String alertId, String zoneId);
  bool get isSimulated;
  DataSource get dataSource;
}

class DemoFieldDataProvider implements ITelemetryProvider {
  final List<AlertModel> _alerts = [];
  final List<ZoneModel> _zones = [];
  RoverStatusModel _rover = CanonicalDemoDataset.roverStatus;
  RemediationVerificationModel? _latestVerification;

  DemoFieldDataProvider() {
    reset();
  }

  void reset() {
    _alerts.clear();
    _alerts.addAll(CanonicalDemoDataset.initialAlerts);
    _zones.clear();
    _zones.addAll(CanonicalDemoDataset.zones);
    _rover = CanonicalDemoDataset.roverStatus;
    _latestVerification = null;
  }

  @override
  bool get isSimulated => true;

  @override
  DataSource get dataSource => DataSource.demo;

  @override
  Future<RoverStatusModel> getRoverStatus() async {
    return _rover;
  }

  @override
  Future<List<ZoneModel>> getZones(String farmId) async {
    return List.unmodifiable(_zones);
  }

  @override
  Future<List<AlertModel>> getAlerts() async {
    return List.unmodifiable(_alerts);
  }

  @override
  Future<RemediationVerificationModel?> executeSimulatedRemediation(
      String alertId, String zoneId) async {
    // 1. Mark alert as resolved/action taken
    final alertIndex = _alerts.indexWhere((a) => a.id == alertId);
    if (alertIndex != -1) {
      final alert = _alerts[alertIndex];
      alert.isApproved = true;
      alert.status = AlertStatus.resolved;
    }

    // 2. Update Zone 2 moisture deterministically (16.8% -> 28.2%)
    final zoneIndex = _zones.indexWhere((z) => z.id == zoneId);
    if (zoneIndex != -1) {
      final oldZone = _zones[zoneIndex];
      _zones[zoneIndex] = ZoneModel(
        id: oldZone.id,
        name: oldZone.name,
        soilType: oldZone.soilType,
        moisturePct: 28.2, // Remediated moisture
        temperatureC: 30.5,
        humidityPct: 48.0,
        ph: oldZone.ph,
        lastScanAt: DateTime.now(),
      );
    }

    // 3. Return verified closed-loop comparison record
    _latestVerification = CanonicalDemoDataset.zone2Verification;
    return _latestVerification;
  }

  RemediationVerificationModel? get latestVerification => _latestVerification;
}
