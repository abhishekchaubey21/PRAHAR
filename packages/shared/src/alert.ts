/**
 * PRAHAR Precision Rover — Alert & Scan Ingestion Contracts
 * Aligned with PRAHAR Engineering Specification v1.0 Section 6, 8 & 12.
 */

import { GPSCoordinates, SensorReading } from './telemetry.js';
import { Detection, HazardType, SeverityLevel } from './detection.js';

export type AlertStatus = 'NEW' | 'ACKNOWLEDGED' | 'ACTION_TAKEN' | 'DISMISSED' | 'RESOLVED';

export interface BilingualText {
  en: string;
  hi: string;
}

export interface Alert {
  alert_id: string;
  zone_id: string;
  type: HazardType;
  severity: SeverityLevel;
  message: string; // Default / English
  message_hi?: string; // Hindi localized message
  recommended_action: string; // Default / English
  recommended_action_hi?: string; // Hindi localized recommendation
  status: AlertStatus;
  timestamp: string;
  deduplication_key?: string; // Format: `${zone_id}:${hazard_type}`
  last_occurrence_at?: string;
  occurrence_count?: number;
}

/**
 * Full scan cycle payload ingested from Rover into Cloud/Backend Gateway.
 * Specified in Section 6 (P0).
 */
export interface RoverScanPayload {
  scan_id: string;
  rover_id: string;
  zone_id: string;
  gps: GPSCoordinates;
  sensor_readings: SensorReading[];
  detections: Detection[];
  battery_pct: number;
  timestamp: string;
}

/**
 * Multilingual alert template engine (Requirement 8 & Section 12).
 * Formats advisory messages and recommended actions in English and Hindi.
 */
export function renderBilingualAlert(params: {
  zoneId: string;
  hazardType: HazardType;
  hazardName: string;
  severity: SeverityLevel;
  moisturePct?: number;
  tempC?: number;
  humidityPct?: number;
  confidence?: number;
}): {
  message_en: string;
  message_hi: string;
  recommended_action_en: string;
  recommended_action_hi: string;
} {
  const { zoneId, hazardType, hazardName, severity, moisturePct, tempC, humidityPct, confidence } = params;

  if (hazardType === 'WATER_STRESS') {
    const moistureText = moisturePct !== undefined ? `${moisturePct}%` : 'low';
    return {
      message_en: `High Water Stress detected in ${zoneId}: Soil moisture is ${moistureText} (below critical threshold).`,
      message_hi: `${zoneId} में गंभीर जल तनाव: मिट्टी की नमी ${moistureText} है (गंभीर सीमा से नीचे)।`,
      recommended_action_en: 'Micro-irrigation recommended for 30s. Awaiting farmer/expert approval.',
      recommended_action_hi: '30 सेकंड सूक्ष्म-सिंचाई की सिफारिश। किसान/विशेषज्ञ की स्वीकृति आवश्यक है।',
    };
  }

  if (hazardType === 'DISEASE') {
    const confPct = confidence !== undefined ? ` (${(confidence * 100).toFixed(0)}% confidence)` : '';
    const humidityNote = humidityPct && humidityPct > 70 ? ` under high humidity (${humidityPct}%)` : '';
    return {
      message_en: `Suspected ${hazardName}${confPct} in ${zoneId}${humidityNote}. Outbreak risk: ${severity}.`,
      message_hi: `${zoneId} में संदिग्ध ${hazardName}${confPct} पाया गया। प्रकोप जोखिम: ${severity}।`,
      recommended_action_en: 'Isolate affected plot and request expert agronomist review.',
      recommended_action_hi: 'प्रभावित क्षेत्र को अलग करें और कृषि विशेषज्ञ की समीक्षा का अनुरोध करें।',
    };
  }

  if (hazardType === 'PEST') {
    return {
      message_en: `Pest alert in ${zoneId}: ${hazardName} detected. Severity: ${severity}.`,
      message_hi: `${zoneId} में कीट चेतावनी: ${hazardName} देखा गया। गंभीरता: ${severity}।`,
      recommended_action_en: 'Field inspection recommended before targeted remediation.',
      recommended_action_hi: 'लक्षित उपचार से पहले खेत के निरीक्षण की सिफारिश की जाती है।',
    };
  }

  // Generic fallback
  return {
    message_en: `${hazardType} alert in ${zoneId}: ${hazardName}. Severity: ${severity}.`,
    message_hi: `${zoneId} में ${hazardType} चेतावनी: ${hazardName}। गंभीरता: ${severity}।`,
    recommended_action_en: 'Review zone health and inspect field.',
    recommended_action_hi: 'ज़ोन के स्वास्थ्य की समीक्षा करें और खेत का निरीक्षण करें।',
  };
}

/**
 * Validates a scan payload.
 */
export function validateScanPayload(payload: Partial<RoverScanPayload>): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!payload.scan_id) errors.push('Missing scan_id.');
  if (!payload.rover_id) errors.push('Missing rover_id.');
  if (!payload.zone_id) errors.push('Missing zone_id.');
  if (!payload.gps) errors.push('Missing GPS.');
  if (!Array.isArray(payload.sensor_readings)) errors.push('sensor_readings must be an array.');
  if (!Array.isArray(payload.detections)) errors.push('detections must be an array.');

  return {
    valid: errors.length === 0,
    errors,
  };
}
