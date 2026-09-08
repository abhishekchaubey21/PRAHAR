import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/api_client.dart';
import '../../domain/assistant_model.dart';

class DemoScenariosProvider with ChangeNotifier {
  final http.Client _client;
  final String _baseUrl;

  DemoScenarioId _activeScenarioId = DemoScenarioId.waterStress;
  List<DemoScenarioDefinition> _scenarios = _defaultScenarios;
  bool _isLoading = false;
  String? _errorMessage;

  DemoScenariosProvider({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiClient.defaultBaseUrl;

  DemoScenarioId get activeScenarioId => _activeScenarioId;
  List<DemoScenarioDefinition> get scenarios => _scenarios;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  DemoScenarioDefinition get activeScenario {
    return _scenarios.firstWhere(
      (s) => s.id == _activeScenarioId,
      orElse: () => _scenarios.first,
    );
  }

  Future<void> fetchScenarios() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _client.get(Uri.parse('$_baseUrl/api/scenarios'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final payload = data['data'] as Map<String, dynamic>;
          final rawList = payload['scenarios'] as List<dynamic>? ?? [];
          _scenarios = rawList
              .map((s) => DemoScenarioDefinition.fromJson(s as Map<String, dynamic>))
              .toList();
          final activeRaw = payload['active_scenario_id'] as String?;
          if (activeRaw != null) {
            _activeScenarioId = DemoScenarioIdExtension.fromWireString(activeRaw);
          }
        }
      }
    } catch (e) {
      // Graceful local fallback
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectScenario(DemoScenarioId id) async {
    _activeScenarioId = id;
    _isLoading = true;
    notifyListeners();

    try {
      await _client.post(
        Uri.parse('$_baseUrl/api/scenarios/select'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'scenario_id': id.toWireString()}),
      );
    } catch (_) {
      // Local state already updated
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetField() async {
    _activeScenarioId = DemoScenarioId.waterStress;
    _isLoading = true;
    notifyListeners();

    try {
      await _client.post(
        Uri.parse('$_baseUrl/api/scenarios/reset'),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (_) {
      // Local state already reset
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetFieldState() => resetField();

  static final List<DemoScenarioDefinition> _defaultScenarios = [
    const DemoScenarioDefinition(
      id: DemoScenarioId.fullFieldScan,
      name: 'Full Field Comprehensive Scan',
      nameHi: 'पूर्ण खेत व्यापक स्कैन',
      nameMr: 'संपूर्ण शेत सर्वसमावेशक स्कॅन',
      namePa: 'ਪੂਰੇ ਖੇਤ ਦੀ ਵਿਆਪਕ ਜਾਂਚ',
      description: 'Autonomous multi-zone scan across all 4 sectors. Identifies localized water stress in Zone 2 and pest in Zone 3.',
      targetZoneId: 'DEMO-ZONE-02',
      startingStatus: 'EVALUATING',
      recommendation: 'Target Zone 2 micro-irrigation and Zone 3 bio-neem remediation.',
      expectedImprovement: 'Moisture increases from 16.8% to 28.5%; health index improves.',
    ),
    const DemoScenarioDefinition(
      id: DemoScenarioId.waterStress,
      name: 'Zone 2 Acute Water Stress',
      nameHi: 'ज़ोन 2 गंभीर जल तनाव',
      nameMr: 'झोन 2 तीव्र पाण्याचा ताण',
      namePa: 'ਜ਼ੋਨ 2 ਗੰਭੀਰ ਪਾਣੀ ਦੀ ਕਮੀ',
      description: 'East Sector exhibits critical soil moisture drop (16.8%) under elevated heat (31.4°C).',
      targetZoneId: 'DEMO-ZONE-02',
      startingStatus: 'CRITICAL',
      hazardDetected: 'WATER_STRESS',
      recommendation: 'Execute 30-second simulated micro-irrigation (12 Liters).',
      expectedImprovement: 'Soil moisture increases by +11.7% to 28.5%, resolving water stress alert.',
    ),
    const DemoScenarioDefinition(
      id: DemoScenarioId.pestAlert,
      name: 'Zone 3 Early Pest Infestation',
      nameHi: 'ज़ोन 3 प्रारंभिक कीट प्रकोप',
      nameMr: 'झोन 3 कीड प्रादुर्भाव',
      namePa: 'ਜ਼ੋਨ 3 ਕੀੜਿਆਂ ਦਾ ਹਮਲਾ',
      description: 'South Sector leaf scan reveals Spodoptera litura larvae cluster with 89% visual confidence.',
      targetZoneId: 'DEMO-ZONE-03',
      startingStatus: 'WARNING',
      hazardDetected: 'PEST_INFESTATION',
      recommendation: 'Apply localized organic Neem seed kernel extract (1500 ppm). Chemical spraying is prohibited.',
      expectedImprovement: 'Larvae activity suppressed; defoliation risk drops to Low within 48 hours.',
    ),
    const DemoScenarioDefinition(
      id: DemoScenarioId.nutrientDeficiency,
      name: 'Zone 4 Nitrogen Deficiency',
      nameHi: 'ज़ोन 4 नाइट्रोजन की कमी',
      nameMr: 'झोन 4 नायट्रोजन कमतरता',
      namePa: 'ਜ਼ੋਨ 4 ਨਾਈਟ੍ਰੋਜਨ ਦੀ ਘਾਟ',
      description: 'West Sector soil testing shows depleted Nitrogen (NPK: 18-12-14) and chlorosis.',
      targetZoneId: 'DEMO-ZONE-04',
      startingStatus: 'MODERATE',
      hazardDetected: 'NUTRIENT_DEFICIENCY',
      recommendation: 'Apply bio-fertilizer (Azotobacter liquid) and organic compost.',
      expectedImprovement: 'Nitrogen availability increases; NDVI projected to recover to 0.72.',
    ),
    const DemoScenarioDefinition(
      id: DemoScenarioId.healthyZone,
      name: 'Zone 1 Optimal Canopy & Soil',
      nameHi: 'ज़ोन 1 उत्तम फसल और मिट्टी',
      nameMr: 'झोन 1 निरोगी पीक आणि माती',
      namePa: 'ਜ਼ੋਨ 1 ਤੰਦਰੁਸਤ ਫਸਲ ਅਤੇ ਮਿੱਟੀ',
      description: 'North Plot maintains balanced moisture (68.0%), optimal NPK (48-28-38), and NDVI 0.82.',
      targetZoneId: 'DEMO-ZONE-01',
      startingStatus: 'OPTIMAL',
      recommendation: 'Maintain standard observation and conservation practices.',
      expectedImprovement: 'Sustained peak vegetative vigor with zero active hazards.',
    ),
  ];
}
