/**
 * PRAHAR AI Decision Layer — Rule-Based Fusion Engine
 * Aligned with PRAHAR Engineering Specification v1.0 Section 7, 8, 12 & Manager Blueprint.
 */

import {
  RoverScanPayload,
  Detection,
  SensorReading,
  Alert,
  SeverityLevel,
  HazardType,
  DECISION_THRESHOLDS,
  DecisionResult,
  ActionRecommendation,
  renderBilingualAlert,
} from '@prahar/shared';
import { IAlertStore } from './alert-store.js';

export class DecisionEngine {
  private alertStore: IAlertStore;

  constructor(alertStore: IAlertStore) {
    this.alertStore = alertStore;
  }

  /**
   * Evaluates a completed rover scan cycle payload through rule-based sensor & vision fusion.
   */
  public async evaluateScan(scanPayload: RoverScanPayload): Promise<DecisionResult> {
    const { zone_id, sensor_readings, detections } = scanPayload;

    // Extract sensor metrics
    const moisture = this.getSensorValue(sensor_readings, 'moisture');
    const temperature = this.getSensorValue(sensor_readings, 'temperature');
    const humidity = this.getSensorValue(sensor_readings, 'humidity');
    const ph = this.getSensorValue(sensor_readings, 'ph');

    const alertsToCreate: Alert[] = [];
    const alertsUpdated: Alert[] = [];
    const reasons: string[] = [];
    let overallSeverity: SeverityLevel = 'LOW';
    let requiresExpertReview = false;
    let actionRecommendation: ActionRecommendation | undefined;

    // ------------------------------------------------------------------------
    // Rule 1: Heat Stress & Low Soil Moisture Fusion (Water Stress)
    // ------------------------------------------------------------------------
    const isCriticalMoisture = moisture !== undefined && moisture < DECISION_THRESHOLDS.LOW_MOISTURE_CRITICAL_PCT;
    const isHeatStressMoisture =
      moisture !== undefined &&
      temperature !== undefined &&
      moisture < DECISION_THRESHOLDS.LOW_MOISTURE_WARNING_PCT &&
      temperature > DECISION_THRESHOLDS.HIGH_TEMP_HEAT_STRESS_C;

    const hasVisionWaterStress = detections.some(
      (d) => d.hazard_type === 'WATER_STRESS' && d.confidence >= DECISION_THRESHOLDS.MIN_CONFIDENCE_THRESHOLD
    );

    if (isCriticalMoisture || isHeatStressMoisture || hasVisionWaterStress) {
      const severity: SeverityLevel = isCriticalMoisture || isHeatStressMoisture ? 'HIGH' : 'MEDIUM';
      overallSeverity = this.maxSeverity(overallSeverity, severity);

      reasons.push(
        `Water stress flag: moisture=${moisture?.toFixed(1)}%, temp=${temperature?.toFixed(1)}°C (sensor agreement: ${isCriticalMoisture || isHeatStressMoisture})`
      );

      // Prepare Bilingual Alert
      const bilingual = renderBilingualAlert({
        zoneId: zone_id,
        hazardType: 'WATER_STRESS',
        hazardName: 'Severe Soil Moisture Depletion',
        severity,
        moisturePct: moisture,
        tempC: temperature,
        humidityPct: humidity,
      });

      const alert = await this.createOrDeduplicateAlert({
        zoneId: zone_id,
        hazardType: 'WATER_STRESS',
        severity,
        messageEn: bilingual.message_en,
        messageHi: bilingual.message_hi,
        actionEn: bilingual.recommended_action_en,
        actionHi: bilingual.recommended_action_hi,
      });

      if (alert.isNew) {
        alertsToCreate.push(alert.alert);
      } else {
        alertsUpdated.push(alert.alert);
      }

      // Safety Gate (Requirement 1): Recommend irrigation with explicit mandatory approval
      actionRecommendation = {
        action_type: 'RECOMMEND_IRRIGATION',
        description_en: `Micro-irrigation advised for ${zone_id} (${DECISION_THRESHOLDS.DEFAULT_IRRIGATION_DURATION_SEC}s, ~${DECISION_THRESHOLDS.DEFAULT_IRRIGATION_VOLUME_L}L). Requires farmer or expert approval.`,
        description_hi: `${zone_id} के लिए सूक्ष्म-सिंचाई की सलाह (${DECISION_THRESHOLDS.DEFAULT_IRRIGATION_DURATION_SEC} सेकंड, ~${DECISION_THRESHOLDS.DEFAULT_IRRIGATION_VOLUME_L}L)। किसान या विशेषज्ञ की स्वीकृति अनिवार्य है।`,
        suggested_params: {
          target_zone_id: zone_id,
          duration_seconds: DECISION_THRESHOLDS.DEFAULT_IRRIGATION_DURATION_SEC,
          volume_liters: DECISION_THRESHOLDS.DEFAULT_IRRIGATION_VOLUME_L,
        },
        requires_approval: true,
        approval_status: 'PENDING_APPROVAL',
      };
    }

    // ------------------------------------------------------------------------
    // Vision Detections Evaluation: Confidence Gating & Disease/Pest Fusion
    // ------------------------------------------------------------------------
    for (const detection of detections) {
      // Rule 3: Confidence Gating (Requirement 2)
      // If confidence < 0.70, strictly route to expert review and suppress autonomous/assisted action
      if (detection.confidence < DECISION_THRESHOLDS.MIN_CONFIDENCE_THRESHOLD) {
        requiresExpertReview = true;
        reasons.push(
          `Low confidence detection (${(detection.confidence * 100).toFixed(1)}% < 70%) for ${detection.hazard_name}. Gated: physical action suppressed, routed to expert review.`
        );

        const bilingual = renderBilingualAlert({
          zoneId: zone_id,
          hazardType: detection.hazard_type,
          hazardName: detection.hazard_name,
          severity: 'LOW',
          confidence: detection.confidence,
        });

        const alert = await this.createOrDeduplicateAlert({
          zoneId: zone_id,
          hazardType: detection.hazard_type,
          severity: 'LOW',
          messageEn: `[Needs Expert Review] ${bilingual.message_en}`,
          messageHi: `[विशेषज्ञ समीक्षा आवश्यक] ${bilingual.message_hi}`,
          actionEn: 'Expert agronomist review requested before taking action.',
          actionHi: 'कार्रवाई करने से पहले कृषि विशेषज्ञ समीक्षा आवश्यक है।',
        });

        if (alert.isNew) alertsToCreate.push(alert.alert);
        else alertsUpdated.push(alert.alert);
        continue;
      }

      // Rule 2: Fungal Disease + High Humidity Microclimate Fusion
      if (detection.hazard_type === 'DISEASE') {
        const isHighHumidity = humidity !== undefined && humidity >= DECISION_THRESHOLDS.HIGH_HUMIDITY_DISEASE_RISK_PCT;
        const diseaseSeverity: SeverityLevel = isHighHumidity ? 'HIGH' : detection.severity_hint || 'MEDIUM';
        overallSeverity = this.maxSeverity(overallSeverity, diseaseSeverity);
        requiresExpertReview = true; // All diseases require expert verification

        reasons.push(
          `Disease detection ${detection.hazard_name} (${(detection.confidence * 100).toFixed(0)}% conf). Humidity=${humidity?.toFixed(1)}% (amplified: ${isHighHumidity}).`
        );

        const bilingual = renderBilingualAlert({
          zoneId: zone_id,
          hazardType: 'DISEASE',
          hazardName: detection.hazard_name,
          severity: diseaseSeverity,
          humidityPct: humidity,
          confidence: detection.confidence,
        });

        const alert = await this.createOrDeduplicateAlert({
          zoneId: zone_id,
          hazardType: 'DISEASE',
          severity: diseaseSeverity,
          messageEn: bilingual.message_en,
          messageHi: bilingual.message_hi,
          actionEn: bilingual.recommended_action_en,
          actionHi: bilingual.recommended_action_hi,
        });

        if (alert.isNew) alertsToCreate.push(alert.alert);
        else alertsUpdated.push(alert.alert);
      }

      // Pest Infestation Rule
      if (detection.hazard_type === 'PEST') {
        const pestSeverity = detection.severity_hint || 'MEDIUM';
        overallSeverity = this.maxSeverity(overallSeverity, pestSeverity);
        requiresExpertReview = true;

        reasons.push(`Pest detection: ${detection.hazard_name} (${(detection.confidence * 100).toFixed(0)}% conf).`);

        const bilingual = renderBilingualAlert({
          zoneId: zone_id,
          hazardType: 'PEST',
          hazardName: detection.hazard_name,
          severity: pestSeverity,
          confidence: detection.confidence,
        });

        const alert = await this.createOrDeduplicateAlert({
          zoneId: zone_id,
          hazardType: 'PEST',
          severity: pestSeverity,
          messageEn: bilingual.message_en,
          messageHi: bilingual.message_hi,
          actionEn: bilingual.recommended_action_en,
          actionHi: bilingual.recommended_action_hi,
        });

        if (alert.isNew) alertsToCreate.push(alert.alert);
        else alertsUpdated.push(alert.alert);
      }
    }

    return {
      zone_id,
      overall_severity: overallSeverity,
      requires_expert_review: requiresExpertReview,
      action_recommendation: actionRecommendation,
      alerts_to_create: alertsToCreate,
      alerts_updated: alertsUpdated,
      reasons,
      evaluated_at: new Date().toISOString(),
    };
  }

  /**
   * Creates a new alert or deduplicates against an existing active alert in the 24-hour window.
   * Requirement 4: 24-hour same-zone/same-hazard deduplication.
   */
  private async createOrDeduplicateAlert(params: {
    zoneId: string;
    hazardType: HazardType;
    severity: SeverityLevel;
    messageEn: string;
    messageHi: string;
    actionEn: string;
    actionHi: string;
  }): Promise<{ alert: Alert; isNew: boolean }> {
    const deduplicationKey = `${params.zoneId}:${params.hazardType}`;
    const existing = await this.alertStore.findActiveAlertByDeduplicationKey(
      deduplicationKey,
      DECISION_THRESHOLDS.ALERT_DEDUPLICATION_WINDOW_MS
    );

    const nowIso = new Date().toISOString();

    if (existing) {
      // Deduplicate: update existing active alert rather than creating spam
      existing.last_occurrence_at = nowIso;
      existing.occurrence_count = (existing.occurrence_count || 1) + 1;
      existing.severity = this.maxSeverity(existing.severity, params.severity);
      existing.message = params.messageEn;
      existing.message_hi = params.messageHi;
      existing.recommended_action = params.actionEn;
      existing.recommended_action_hi = params.actionHi;

      await this.alertStore.updateAlert(existing);
      return { alert: existing, isNew: false };
    }

    // Create new alert
    const newAlert: Alert = {
      alert_id: `alert-${params.zoneId.toLowerCase()}-${Date.now().toString(36)}-${Math.random().toString(36).substring(2, 6)}`,
      zone_id: params.zoneId,
      type: params.hazardType,
      severity: params.severity,
      message: params.messageEn,
      message_hi: params.messageHi,
      recommended_action: params.actionEn,
      recommended_action_hi: params.actionHi,
      status: 'NEW',
      timestamp: nowIso,
      deduplication_key: deduplicationKey,
      last_occurrence_at: nowIso,
      occurrence_count: 1,
    };

    await this.alertStore.saveAlert(newAlert);
    return { alert: newAlert, isNew: true };
  }

  private getSensorValue(readings: SensorReading[], type: string): number | undefined {
    const reading = readings.find((r) => r.type === type);
    return reading ? reading.value : undefined;
  }

  private maxSeverity(a: SeverityLevel, b: SeverityLevel): SeverityLevel {
    const order: Record<SeverityLevel, number> = {
      LOW: 1,
      MEDIUM: 2,
      HIGH: 3,
      CRITICAL: 4,
    };
    return order[a] >= order[b] ? a : b;
  }
}
