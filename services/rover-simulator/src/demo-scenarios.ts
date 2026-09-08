/**
 * PRAHAR Deterministic Demo Scenario Engine
 * Phase 8: Canonical Demo Scenarios & Judge Mode Foundation
 *
 * Guaranteed Deterministic Data Flow:
 * START -> DETECT -> WHY -> RECOMMEND -> ACTION -> RE-SCAN -> VERIFY -> FINAL STATE
 *
 * Zero random values at startup.
 */

import {
  DemoScenarioId,
  DemoScenarioDefinition,
  AssistantContextZone,
  AssistantContextAlert,
  AssistantEvidenceItem,
  AssistantActionType,
} from '@prahar/shared';

export const DEMO_SCENARIOS: Record<DemoScenarioId, DemoScenarioDefinition> = {
  FULL_FIELD_SCAN: {
    id: 'FULL_FIELD_SCAN',
    name: 'Full Field Comprehensive Scan',
    name_hi: 'पूर्ण खेत व्यापक स्कैन',
    name_mr: 'संपूर्ण शेत सर्वसमावेशक स्कॅन',
    name_pa: 'ਪੂਰੇ ਖੇਤ ਦੀ ਵਿਆਪਕ ਜਾਂਚ',
    description: 'Autonomous multi-zone scan across all 4 sectors. Identifies localized water stress in Zone 2 and pest infestation in Zone 3.',
    target_zone_id: 'DEMO-ZONE-02',
    starting_status: 'EVALUATING',
    hazard_detected: 'WATER_STRESS_AND_PEST',
    recommendation: 'Target Zone 2 micro-irrigation and Zone 3 bio-neem remediation.',
    simulation_action: 'IRRIGATE',
    expected_improvement: 'Moisture increases from 16.8% to 28.5%; overall farm health index improves to 82/100.',
  },
  WATER_STRESS: {
    id: 'WATER_STRESS',
    name: 'Zone 2 Acute Water Stress',
    name_hi: 'ज़ोन 2 गंभीर जल तनाव',
    name_mr: 'झोन 2 तीव्र पाण्याचा ताण',
    name_pa: 'ਜ਼ੋਨ 2 ਗੰਭੀਰ ਪਾਣੀ ਦੀ ਕਮੀ',
    description: 'East Sector exhibits critical soil moisture drop (16.8%) under elevated canopy temperature (31.4°C).',
    target_zone_id: 'DEMO-ZONE-02',
    starting_status: 'CRITICAL',
    hazard_detected: 'WATER_STRESS',
    recommendation: 'Execute 30-second simulated micro-irrigation (12 Liters) to restore root moisture above 20%.',
    simulation_action: 'IRRIGATE',
    expected_improvement: 'Soil moisture increases by +11.7% to 28.5%, resolving water stress alert.',
  },
  PEST_ALERT: {
    id: 'PEST_ALERT',
    name: 'Zone 3 Early Pest Infestation',
    name_hi: 'ज़ोन 3 प्रारंभिक कीट प्रकोप',
    name_mr: 'झोन 3 कीड प्रादुर्भाव',
    name_pa: 'ਜ਼ੋਨ 3 ਕੀੜਿਆਂ ਦਾ ਹਮਲਾ',
    description: 'South Sector leaf scan reveals Spodoptera litura (Tobacco Caterpillar) larvae cluster with 89% visual confidence.',
    target_zone_id: 'DEMO-ZONE-03',
    starting_status: 'WARNING',
    hazard_detected: 'PEST_INFESTATION',
    recommendation: 'Apply localized organic Neem seed kernel extract (1500 ppm). Chemical spraying is prohibited.',
    simulation_action: 'NONE',
    expected_improvement: 'Larvae activity suppressed; leaf defoliation risk drops from High to Low within 48 hours.',
  },
  NUTRIENT_DEFICIENCY: {
    id: 'NUTRIENT_DEFICIENCY',
    name: 'Zone 4 Nitrogen Deficiency',
    name_hi: 'ज़ोन 4 नाइट्रोजन की कमी',
    name_mr: 'झोन 4 नायट्रोजन कमतरता',
    name_pa: 'ਜ਼ੋਨ 4 ਨਾਈਟ੍ਰੋਜਨ ਦੀ ਘਾਟ',
    description: 'West Sector soil testing shows depleted Nitrogen (NPK: 18-12-14) with pale leaf chlorosis and NDVI of 0.48.',
    target_zone_id: 'DEMO-ZONE-04',
    starting_status: 'MODERATE',
    hazard_detected: 'NUTRIENT_DEFICIENCY',
    recommendation: 'Apply bio-fertilizer (Azotobacter liquid) and organic compost top-dressing.',
    simulation_action: 'NONE',
    expected_improvement: 'Nitrogen availability increases; NDVI projected to recover from 0.48 to 0.72.',
  },
  HEALTHY_ZONE: {
    id: 'HEALTHY_ZONE',
    name: 'Zone 1 Optimal Canopy & Soil',
    name_hi: 'ज़ोन 1 उत्तम फसल और मिट्टी',
    name_mr: 'झोन 1 निरोगी पीक आणि माती',
    name_pa: 'ਜ਼ੋਨ 1 ਤੰਦਰੁਸਤ ਫਸਲ ਅਤੇ ਮਿੱਟੀ',
    description: 'North Plot maintains balanced moisture (68.0%), optimal NPK (48-28-38), pH 6.8, and NDVI 0.82.',
    target_zone_id: 'DEMO-ZONE-01',
    starting_status: 'OPTIMAL',
    recommendation: 'Maintain standard observation and conservation practices.',
    simulation_action: 'NONE',
    expected_improvement: 'Sustained peak vegetative vigor with zero active hazards.',
  },
};

export class DemoScenarioEngine {
  private activeScenarioId: DemoScenarioId = 'WATER_STRESS';

  public getActiveScenarioId(): DemoScenarioId {
    return this.activeScenarioId;
  }

  public getActiveScenario(): DemoScenarioDefinition {
    return DEMO_SCENARIOS[this.activeScenarioId];
  }

  public getAllScenarios(): DemoScenarioDefinition[] {
    return Object.values(DEMO_SCENARIOS);
  }

  public setScenario(id: DemoScenarioId): DemoScenarioDefinition {
    if (!DEMO_SCENARIOS[id]) {
      throw new Error(`Unknown demo scenario: ${id}`);
    }
    this.activeScenarioId = id;
    return DEMO_SCENARIOS[id];
  }

  public resetField(): DemoScenarioDefinition {
    this.activeScenarioId = 'WATER_STRESS';
    return DEMO_SCENARIOS['WATER_STRESS'];
  }

  /**
   * Deterministic scenario context data
   */
  public getScenarioContext(id: DemoScenarioId = this.activeScenarioId): {
    zones: AssistantContextZone[];
    alerts: AssistantContextAlert[];
    latest_verification: any;
    evidence_breakdown: AssistantEvidenceItem[];
  } {
    switch (id) {
      case 'FULL_FIELD_SCAN':
      case 'WATER_STRESS':
        return {
          zones: [
            { id: 'DEMO-ZONE-01', name: 'Zone 1 — North Plot', soil_type: 'Clay Loam', moisture_pct: 68.0, temperature_c: 28.5, ph: 6.8, active_hazard: null, severity: 'NONE' },
            { id: 'DEMO-ZONE-02', name: 'Zone 2 — East Sector', soil_type: 'Sandy Loam', moisture_pct: 16.8, temperature_c: 31.4, ph: 6.2, active_hazard: 'WATER_STRESS', severity: 'HIGH' },
            { id: 'DEMO-ZONE-03', name: 'Zone 3 — South Sector', soil_type: 'Silt Loam', moisture_pct: 42.0, temperature_c: 27.8, ph: 6.5, active_hazard: 'PEST_ALERT', severity: 'HIGH' },
            { id: 'DEMO-ZONE-04', name: 'Zone 4 — West Sector', soil_type: 'Clay Loam', moisture_pct: 55.0, temperature_c: 29.0, ph: 7.8, active_hazard: 'NUTRIENT_DEFICIENCY', severity: 'MEDIUM' },
          ],
          alerts: [
            {
              id: 'ALERT-DEMO-01',
              zone_id: 'DEMO-ZONE-02',
              hazard_type: 'WATER_STRESS',
              severity: 'HIGH',
              title: 'Critical Soil Moisture Deficit',
              why_reasoning: 'Moisture 16.8% is below 20% critical threshold with 31.4°C ambient temp.',
            },
            {
              id: 'ALERT-DEMO-02',
              zone_id: 'DEMO-ZONE-03',
              hazard_type: 'PEST_ALERT',
              severity: 'HIGH',
              title: 'Spodoptera litura Infestation',
              why_reasoning: 'Visual edge detection identified larvae cluster with 89% confidence under 74% humidity.',
            },
          ],
          latest_verification: {
            action_id: 'ACT-SIM-001',
            zone_id: 'DEMO-ZONE-02',
            pre_moisture: 16.8,
            post_moisture: 28.5,
            moisture_delta: 11.7,
            summary: 'Pre-intervention: 16.8% -> Post-intervention: 28.5% (+11.7% moisture gain). Water stress resolved.',
          },
          evidence_breakdown: [
            { metric: 'Soil Moisture', observed: '16.8%', threshold: '>= 20.0%', status: 'CRITICAL' },
            { metric: 'Ambient Temperature', observed: '31.4°C', threshold: '<= 30.0°C', status: 'ELEVATED' },
            { metric: 'Soil pH', observed: '6.2', threshold: '6.0 - 7.5', status: 'OPTIMAL' },
            { metric: 'NDVI Index', observed: '0.62', threshold: '>= 0.70', status: 'MILD_STRESS' },
          ],
        };

      case 'PEST_ALERT':
        return {
          zones: [
            { id: 'DEMO-ZONE-01', name: 'Zone 1 — North Plot', moisture_pct: 65.0, active_hazard: null },
            { id: 'DEMO-ZONE-02', name: 'Zone 2 — East Sector', moisture_pct: 35.0, active_hazard: null },
            { id: 'DEMO-ZONE-03', name: 'Zone 3 — South Sector', moisture_pct: 44.0, active_hazard: 'PEST_INFESTATION', severity: 'HIGH' },
            { id: 'DEMO-ZONE-04', name: 'Zone 4 — West Sector', moisture_pct: 52.0, active_hazard: null },
          ],
          alerts: [
            {
              id: 'ALERT-DEMO-02',
              zone_id: 'DEMO-ZONE-03',
              hazard_type: 'PEST_ALERT',
              severity: 'HIGH',
              title: 'Spodoptera litura Detected',
              why_reasoning: 'Leaf defoliation visible; vision model detected 89% confidence.',
            },
          ],
          latest_verification: null,
          evidence_breakdown: [
            { metric: 'Pest Confidence', observed: '89.0%', threshold: '>= 70.0%', status: 'HIGH_ALERT' },
            { metric: 'Relative Humidity', observed: '74.0%', threshold: '>= 70.0%', status: 'INCUBATION_RISK' },
            { metric: 'Canopy Density', observed: 'Moderate', threshold: 'Dense', status: 'OPTIMAL' },
          ],
        };

      case 'NUTRIENT_DEFICIENCY':
        return {
          zones: [
            { id: 'DEMO-ZONE-01', name: 'Zone 1 — North Plot', moisture_pct: 64.0, active_hazard: null },
            { id: 'DEMO-ZONE-02', name: 'Zone 2 — East Sector', moisture_pct: 32.0, active_hazard: null },
            { id: 'DEMO-ZONE-03', name: 'Zone 3 — South Sector', moisture_pct: 45.0, active_hazard: null },
            { id: 'DEMO-ZONE-04', name: 'Zone 4 — West Sector', moisture_pct: 48.0, active_hazard: 'NUTRIENT_DEFICIENCY', severity: 'MEDIUM' },
          ],
          alerts: [
            {
              id: 'ALERT-DEMO-03',
              zone_id: 'DEMO-ZONE-04',
              hazard_type: 'NUTRIENT_DEFICIENCY',
              severity: 'MEDIUM',
              title: 'Depleted Nitrogen Profile',
              why_reasoning: 'NPK 18-12-14 with soil pH 7.8 and chlorosis symptoms.',
            },
          ],
          latest_verification: null,
          evidence_breakdown: [
            { metric: 'Available Nitrogen (N)', observed: '18 mg/kg', threshold: '>= 35 mg/kg', status: 'DEFICIENT' },
            { metric: 'Soil pH', observed: '7.8', threshold: '6.0 - 7.5', status: 'SLIGHTLY_ALKALINE' },
            { metric: 'NDVI Canopy Score', observed: '0.48', threshold: '>= 0.65', status: 'SUB_OPTIMAL' },
          ],
        };

      case 'HEALTHY_ZONE':
        return {
          zones: [
            { id: 'DEMO-ZONE-01', name: 'Zone 1 — North Plot', moisture_pct: 68.0, active_hazard: null, severity: 'NONE' },
            { id: 'DEMO-ZONE-02', name: 'Zone 2 — East Sector', moisture_pct: 42.0, active_hazard: null, severity: 'NONE' },
            { id: 'DEMO-ZONE-03', name: 'Zone 3 — South Sector', moisture_pct: 48.0, active_hazard: null, severity: 'NONE' },
            { id: 'DEMO-ZONE-04', name: 'Zone 4 — West Sector', moisture_pct: 54.0, active_hazard: null, severity: 'NONE' },
          ],
          alerts: [],
          latest_verification: null,
          evidence_breakdown: [
            { metric: 'Soil Moisture', observed: '68.0%', threshold: '40.0 - 70.0%', status: 'OPTIMAL' },
            { metric: 'NPK Ratio', observed: '48-28-38', threshold: 'Balanced', status: 'OPTIMAL' },
            { metric: 'Soil pH', observed: '6.8', threshold: '6.5 - 7.2', status: 'OPTIMAL' },
            { metric: 'NDVI Index', observed: '0.82', threshold: '>= 0.75', status: 'VIGOROUS' },
          ],
        };
    }
  }

  /**
   * Deterministic scenario estimate / prediction
   */
  public getScenarioPrediction(
    id: DemoScenarioId = this.activeScenarioId,
    lang: 'en' | 'hi' | 'mr' | 'pa' = 'en'
  ): { text: string; label: string; confidence: string } {
    const labelMap = {
      en: 'PRAHAR Scenario Estimate (Simulation Demo)',
      hi: 'प्रहार परिदृश्य अनुमान (सिम्युलेशन डेमो)',
      mr: 'प्रहार परिस्थिती अंदाज (सिम्युलेशन डेमो)',
      pa: 'ਪ੍ਰਹਾਰ ਸਥਿਤੀ ਅੰਦਾਜ਼ਾ (ਸਿਮੂਲੇਸ਼ਨ ਡੈਮੋ)',
    };

    const predictions: Record<DemoScenarioId, Record<string, string>> = {
      FULL_FIELD_SCAN: {
        en: 'Field analysis indicates that targeted 30-second irrigation on Zone 2 combined with bio-remediation on Zone 3 will recover full field health from 68% to 85% within 36 hours.',
        hi: 'खेत विश्लेषण इंगित करता है कि ज़ोन 2 पर 30 सेकंड की लक्षित सिंचाई और ज़ोन 3 पर जैविक उपचार से 36 घंटों के भीतर खेत का स्वास्थ्य 68% से बढ़कर 85% हो जाएगा।',
        mr: 'शेत विश्लेषण दर्शवते की झोन 2 वरील 30 सेकंदांचे सिंचन आणि झोन 3 वरील जैविक उपाययोजना यामुळे 36 तासांत शेताचे आरोग्य 68% वरून 85% पर्यंत सुधारेल.',
        pa: 'ਖੇਤ ਵਿਸ਼ਲੇਸ਼ਣ ਦਰਸਾਉਂਦਾ ਹੈ ਕਿ ਜ਼ੋਨ 2 ਤੇ 30 ਸਕਿੰਟ ਦੀ ਸਿੰਚਾਈ ਅਤੇ ਜ਼ੋਨ 3 ਤੇ ਜੈਵਿਕ ਉਪਚਾਰ ਨਾਲ 36 ਘੰਟਿਆਂ ਵਿੱਚ ਖੇਤ ਦੀ ਸਿਹਤ 68% ਤੋਂ 85% ਹੋ ਜਾਵੇਗੀ।',
      },
      WATER_STRESS: {
        en: 'If irrigation is delayed beyond 6 hours under current 31.4°C heat, Zone 2 soil moisture will drop to 14.2%, causing irreversible crop wilting. Immediate 30s micro-irrigation is projected to raise moisture to 28.5%.',
        hi: 'यदि 31.4°C तापमान में सिंचाई 6 घंटे से अधिक देर की गई, तो ज़ोन 2 की नमी घटकर 14.2% हो जाएगी जिससे फसल मुरझा सकती है। 30 सेकंड की सिंचाई से नमी 28.5% होने का अनुमान है।',
        mr: 'सध्याच्या 31.4°C तापमानात 6 तासांपेक्षा जास्त उशीर झाल्यास झोन 2 चा ओलावा 14.2% पर्यंत घसरेल. तात्काळ 30 सेकंद सिंचनामुळे ओलावा 28.5% पर्यंत वाढेल.',
        pa: 'ਜੇਕਰ ਮੌਜੂਦਾ ਗਰਮੀ ਵਿੱਚ ਸਿੰਚਾਈ ਵਿੱਚ ਦੇਰੀ ਹੋਈ ਤਾਂ ਜ਼ੋਨ 2 ਦੀ ਨਮੀ 14.2% ਤੱਕ ਡਿੱਗ ਜਾਵੇਗੀ। 30 ਸਕਿੰਟ ਦੀ ਸਿੰਚਾਈ ਨਾਲ ਨਮੀ 28.5% ਹੋਣ ਦਾ ਅਨੁਮਾਨ ਹੈ।',
      },
      PEST_ALERT: {
        en: 'Under 74% humidity, Spodoptera litura egg clusters in Zone 3 are estimated to hatch within 24 hours without intervention. Timely application of Neem seed extract will prevent canopy defoliation.',
        hi: '74% आर्द्रता में, ज़ोन 3 में स्पोडोप्टेरा लिटुरा कीट 24 घंटों में फैलने का अनुमान है। नीम अर्क के सामयिक छिड़काव से फसल के नुकसान को रोका जा सकता है।',
        mr: '74% आर्द्रतेमध्ये, झोन 3 मधील कीड 24 तासांत वाढण्याचा अंदाज आहे. वेळेवर कडुनिंब अर्क वापरल्यास नुकसान टळेल.',
        pa: '74% ਨਮੀ ਵਿੱਚ ਜ਼ੋਨ 3 ਵਿੱਚ ਕੀੜੇ 24 ਘੰਟਿਆਂ ਵਿੱਚ ਵੱਧ ਸਕਦੇ ਹਨ। ਨਿੰਮ ਦੇ ਅਰਕ ਨਾਲ ਨੁਕਸਾਨ ਤੋਂ ਬਚਿਆ ਜਾ ਸਕਦਾ ਹੈ।',
      },
      NUTRIENT_DEFICIENCY: {
        en: 'Zone 4 Nitrogen deficiency will lower soybean yield by an estimated 18% if uncorrected. Applying organic Azotobacter will restore soil microbial nitrogen fixing within 5-7 days.',
        hi: 'ज़ोन 4 में नाइट्रोजन की कमी को पूरा न करने पर सोयाबीन की पैदावार में 18% की कमी आने का अनुमान है। एज़ोटोबैक्टर जैविक खाद से 5-7 दिनों में सुधार होगा।',
        mr: 'झोन 4 मधील नायट्रोजनची कमतरता भरून न काढल्यास उत्पादनात 18% घट होण्याची शक्यता आहे. जैविक खतामुळे 5-7 दिवसांत सुधारणा होईल.',
        pa: 'ਜ਼ੋਨ 4 ਵਿੱਚ ਨਾਈਟ੍ਰੋਜਨ ਦੀ ਕਮੀ ਨਾਲ ਝਾੜ 18% ਘਟਣ ਦਾ ਅੰਦਾਜ਼ਾ ਹੈ। ਜੈਵਿਕ ਖਾਦ ਨਾਲ 5-7 ਦਿਨਾਂ ਵਿੱਚ ਸੁਧਾਰ ਹੋਵੇਗਾ।',
      },
      HEALTHY_ZONE: {
        en: 'Zone 1 exhibits high vegetative vigor (NDVI 0.82) and balanced soil conditions. Under current moisture retention, no supplemental intervention is required for the next 72 hours.',
        hi: 'ज़ोन 1 में उत्कृष्ट फसल वृद्धि (NDVI 0.82) और संतुलित मिट्टी है। अगले 72 घंटों तक किसी अतिरिक्त हस्तक्षेप की आवश्यकता नहीं है।',
        mr: 'झोन 1 ची स्थिती उत्कृष्ट आहे (NDVI 0.82). पुढील 72 तास कोणत्याही हस्तक्षेपाची गरज नाही.',
        pa: 'ਜ਼ੋਨ 1 ਵਿੱਚ ਫਸਲ ਦੀ ਸਿਹਤ ਬਹੁਤ ਵਧੀਆ ਹੈ (NDVI 0.82)। ਅਗਲੇ 72 ਘੰਟਿਆਂ ਲਈ ਕਿਸੇ ਕਾਰਵਾਈ ਦੀ ਲੋੜ ਨਹੀਂ।',
      },
    };

    return {
      text: predictions[id]?.[lang] || predictions[id]?.en || predictions.WATER_STRESS.en,
      label: labelMap[lang] || labelMap.en,
      confidence: '88% (Deterministic Agronomic Model)',
    };
  }
}
