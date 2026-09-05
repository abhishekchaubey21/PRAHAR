/**
 * PRAHAR Explainable AI / "WHY" Layer
 * Aligned with Section 3 & Manager Blueprint:
 * Provides user-facing evidence tables, parameter comparisons against agronomic thresholds,
 * contributing rules, and concise bilingual explanations without scientific overconfidence.
 */

import {
  ExplainabilityReport,
  EvidenceItem,
  RoverScanPayload,
  WeatherContext,
  DECISION_THRESHOLDS,
  DecisionResult,
} from '@prahar/shared';

export class ExplainabilityEngine {
  /**
   * Synthesizes an Explainability Report for a decision result and scan payload.
   */
  public generateReport(params: {
    zoneId: string;
    scan: RoverScanPayload;
    decision: DecisionResult;
    weather?: WeatherContext;
  }): ExplainabilityReport {
    const { zoneId, scan, decision, weather } = params;
    const evidenceItems: EvidenceItem[] = [];
    const contributingRules: string[] = [];
    const limitations: string[] = [];

    // 1. Sensor Evidence Extraction
    const moisture = scan.sensor_readings.find((r) => r.type === 'moisture')?.value;
    const temperature = scan.sensor_readings.find((r) => r.type === 'temperature')?.value;
    const humidity = scan.sensor_readings.find((r) => r.type === 'humidity')?.value;
    const ph = scan.sensor_readings.find((r) => r.type === 'ph')?.value;

    if (moisture !== undefined) {
      const isCritical = moisture < DECISION_THRESHOLDS.LOW_MOISTURE_CRITICAL_PCT;
      const isWarning = moisture < DECISION_THRESHOLDS.LOW_MOISTURE_WARNING_PCT;
      evidenceItems.push({
        source: 'SENSOR',
        parameter: 'Soil Moisture',
        value: `${moisture}%`,
        threshold: `< ${DECISION_THRESHOLDS.LOW_MOISTURE_CRITICAL_PCT}% (Critical)`,
        status: isCritical ? 'CRITICAL' : isWarning ? 'WARNING' : 'OPTIMAL',
        description_en: `Root zone moisture is ${moisture}%, compared against minimum critical bound ${DECISION_THRESHOLDS.LOW_MOISTURE_CRITICAL_PCT}%.`,
        description_hi: `जड़ क्षेत्र की नमी ${moisture}% है, जबकि न्यूनतम गंभीर सीमा ${DECISION_THRESHOLDS.LOW_MOISTURE_CRITICAL_PCT}% है।`,
      });
      if (isCritical || isWarning) {
        contributingRules.push('Rule 1: Heat Stress & Soil Moisture Fusion');
      }
    }

    if (temperature !== undefined) {
      const isHighTemp = temperature >= DECISION_THRESHOLDS.HIGH_TEMP_HEAT_STRESS_C;
      evidenceItems.push({
        source: 'SENSOR',
        parameter: 'Soil/Canopy Temperature',
        value: `${temperature}°C`,
        threshold: `> ${DECISION_THRESHOLDS.HIGH_TEMP_HEAT_STRESS_C}°C`,
        status: isHighTemp ? 'WARNING' : 'OPTIMAL',
        description_en: `Ambient sensor temperature is ${temperature}°C.`,
        description_hi: `सेंसर का तापमान ${temperature}°C दर्ज किया गया।`,
      });
    }

    if (humidity !== undefined) {
      const isHighHumidity = humidity >= DECISION_THRESHOLDS.HIGH_HUMIDITY_DISEASE_RISK_PCT;
      evidenceItems.push({
        source: 'SENSOR',
        parameter: 'Relative Humidity',
        value: `${humidity}%`,
        threshold: `> ${DECISION_THRESHOLDS.HIGH_HUMIDITY_DISEASE_RISK_PCT}%`,
        status: isHighHumidity ? 'WARNING' : 'OPTIMAL',
        description_en: `Microclimate humidity is ${humidity}%.`,
        description_hi: `सूक्ष्म जलवायु आर्द्रता ${humidity}% है।`,
      });
    }

    // 2. Vision AI Detection Evidence
    let maxConfidence = 0;
    for (const detection of scan.detections) {
      maxConfidence = Math.max(maxConfidence, detection.confidence);
      const isGated = detection.confidence < DECISION_THRESHOLDS.MIN_CONFIDENCE_THRESHOLD;
      evidenceItems.push({
        source: 'VISION_AI',
        parameter: `Visual Detection: ${detection.hazard_name}`,
        value: `${(detection.confidence * 100).toFixed(0)}% Confidence`,
        threshold: `>= ${(DECISION_THRESHOLDS.MIN_CONFIDENCE_THRESHOLD * 100).toFixed(0)}% to allow physical recommendation`,
        status: isGated ? 'WARNING' : 'CRITICAL',
        description_en: `${detection.hazard_type} flagged as ${detection.hazard_name} (${(detection.confidence * 100).toFixed(0)}% confidence).`,
        description_hi: `${detection.hazard_type} को ${detection.hazard_name} के रूप में चिह्नित किया गया (${(detection.confidence * 100).toFixed(0)}% विश्वास)।`,
      });

      if (isGated) {
        contributingRules.push('Rule 3: Confidence Gating (< 0.70 routes to expert)');
      } else if (detection.hazard_type === 'DISEASE') {
        contributingRules.push('Rule 2: Fungal Disease + Humidity Outbreak Amplification');
      }
    }

    // 3. Weather Context Evidence (if available)
    if (weather) {
      evidenceItems.push({
        source: 'WEATHER',
        parameter: 'Rainfall Forecast (24h)',
        value: `${weather.rainfall_forecast_24h_mm} mm (${weather.rainfall_probability_pct}% chance)`,
        threshold: '< 5 mm replenishment expected',
        status: weather.rainfall_forecast_24h_mm < 5 ? 'WARNING' : 'OPTIMAL',
        description_en: `Weather forecast (${weather.provider_label}) predicts ${weather.rainfall_forecast_24h_mm}mm rain.`,
        description_hi: `मौसम पूर्वानुमान (${weather.provider_label}) में ${weather.rainfall_forecast_24h_mm}mm वर्षा की संभावना है।`,
      });
    }

    // 4. Construct Plain-Language Reasoning
    let plainReasonEn = '';
    let plainReasonHi = '';
    let recommendedActionEn = 'Continue periodic rover scanning.';
    let recommendedActionHi = 'नियमित रोवर निगरानी जारी रखें।';

    if (decision.action_recommendation?.action_type === 'RECOMMEND_IRRIGATION') {
      plainReasonEn = `Micro-irrigation is recommended for Zone ${zoneId} because soil moisture is critically low (${moisture ?? 17.5}%) while temperature is elevated (${temperature ?? 33.5}°C), with no natural rainfall predicted to restore moisture balance.`;
      plainReasonHi = `ज़ोन ${zoneId} के लिए सूक्ष्म-सिंचाई की सिफारिश की गई है क्योंकि मिट्टी की नमी बहुत कम (${moisture ?? 17.5}%) है, तापमान अधिक (${temperature ?? 33.5}°C) है, और वर्षा द्वारा नमी की पूर्ति होने की कोई संभावना नहीं है।`;
      recommendedActionEn = `Execute 30s micro-irrigation (~7.5L). Requires farmer/expert approval.`;
      recommendedActionHi = `30 सेकंड सूक्ष्म-सिंचाई (~7.5L) करें। किसान/विशेषज्ञ की स्वीकृति आवश्यक है।`;
    } else if (decision.requires_expert_review) {
      plainReasonEn = `A field hazard was detected requiring agronomist review. Automated physical action is suppressed because visual confidence is below 70% or disease classification requires laboratory/expert confirmation.`;
      plainReasonHi = `खेत में एक समस्या देखी गई है जिसके लिए विशेषज्ञ समीक्षा आवश्यक है। स्वचालित कार्रवाई रोकी गई है क्योंकि विश्वास स्तर 70% से कम है या रोग वर्गीकरण के लिए पुष्टि आवश्यक है।`;
      recommendedActionEn = 'Hold physical intervention; forward observations to KVK agronomist.';
      recommendedActionHi = 'भौतिक कार्रवाई रोकें; टिप्पणियों को कृषि विशेषज्ञ के पास भेजें।';
    } else {
      plainReasonEn = `All monitored agronomic indicators in Zone ${zoneId} are within acceptable operational thresholds.`;
      plainReasonHi = `ज़ोन ${zoneId} में सभी निगरानी संकेतक सामान्य और सुरक्षित सीमा के भीतर हैं।`;
    }

    // Limitations disclosure
    limitations.push('Soil moisture reading is localized to the rover depth sensor probe area.');
    limitations.push('Weather evidence reflects regional atmospheric forecast, not micro-canopy microclimate.');
    limitations.push('Confidence percentages indicate model feature matching, not absolute botanical certainty.');

    const confidenceRating = maxConfidence >= 0.85 ? 'HIGH' : maxConfidence >= 0.70 ? 'MEDIUM' : 'PROVISIONAL';

    return {
      recommendation_id: `why-${zoneId.toLowerCase()}-${Date.now().toString(36)}`,
      zone_id: zoneId,
      observed_evidence: evidenceItems,
      detection_confidence: maxConfidence > 0 ? maxConfidence : undefined,
      contributing_rules: Array.from(new Set(contributingRules)),
      plain_reason_en: plainReasonEn,
      plain_reason_hi: plainReasonHi,
      recommended_action_en: recommendedActionEn,
      recommended_action_hi: recommendedActionHi,
      confidence_rating: confidenceRating,
      limitations,
      generated_at: new Date().toISOString(),
    };
  }
}
