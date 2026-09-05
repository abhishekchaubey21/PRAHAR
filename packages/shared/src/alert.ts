/**
 * PRAHAR Precision Rover — Alert & Scan Ingestion Contracts
 * Aligned with PRAHAR Engineering Specification v1.0 Section 6, 8 & 9.
 */

import { GPSCoordinates, SensorReading } from './telemetry.js';
import { Detection, HazardType, SeverityLevel } from './detection.js';

export type AlertStatus = 'NEW' | 'ACKNOWLEDGED' | 'ACTION_TAKEN' | 'DISMISSED' | 'RESOLVED';

export interface Alert {
  alert_id: string;
  zone_id: string;
  type: HazardType;
  severity: SeverityLevel;
  message: string;
  recommended_action: string;
  status: AlertStatus;
  timestamp: string;
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
