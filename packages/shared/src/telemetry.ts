/**
 * PRAHAR Precision Rover — Telemetry & Sensor Contracts
 * Aligned with PRAHAR Engineering Specification v1.0 Section 6 & 9.
 */

export type RoverState =
  | 'IDLE'
  | 'SCANNING'
  | 'IRRIGATING'
  | 'RE_SCANNING'
  | 'STOPPED'
  | 'ERROR'
  | 'CHARGING';

export interface GPSCoordinates {
  latitude: number;
  longitude: number;
  altitude_m?: number;
}

export type SensorType = 'moisture' | 'temperature' | 'humidity' | 'ph';

export interface SensorReading {
  id?: string;
  zone_id: string;
  type: SensorType;
  value: number;
  unit: string;
  timestamp: string;
  source: string; // e.g. 'rover_probe_01', 'rover_ambient_01'
}

export interface SensorBundle {
  moisture_pct: number;
  temperature_c: number;
  humidity_pct: number;
  ph: number;
  timestamp: string;
}

export interface RoverTelemetry {
  rover_id: string;
  zone_id: string;
  gps: GPSCoordinates;
  battery_pct: number;
  status: RoverState;
  tilt_deg: number;
  fault_flags: string[];
  current_task_id?: string;
  timestamp: string;
}

/**
 * Validates sensor values against realistic agronomic and physical limits.
 */
export function validateSensorBundle(bundle: Partial<SensorBundle>): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (bundle.moisture_pct === undefined || bundle.moisture_pct < 0 || bundle.moisture_pct > 100) {
    errors.push(`Invalid moisture: ${bundle.moisture_pct}%. Must be between 0% and 100%.`);
  }
  if (bundle.temperature_c === undefined || bundle.temperature_c < -10 || bundle.temperature_c > 65) {
    errors.push(`Invalid temperature: ${bundle.temperature_c}°C. Must be between -10°C and 65°C.`);
  }
  if (bundle.humidity_pct === undefined || bundle.humidity_pct < 0 || bundle.humidity_pct > 100) {
    errors.push(`Invalid humidity: ${bundle.humidity_pct}%. Must be between 0% and 100%.`);
  }
  if (bundle.ph === undefined || bundle.ph < 0 || bundle.ph > 14) {
    errors.push(`Invalid pH: ${bundle.ph}. Must be between 0 and 14.`);
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Validates rover telemetry payload.
 */
export function validateTelemetry(telemetry: Partial<RoverTelemetry>): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!telemetry.rover_id || typeof telemetry.rover_id !== 'string') {
    errors.push('Missing or invalid rover_id.');
  }
  if (!telemetry.zone_id || typeof telemetry.zone_id !== 'string') {
    errors.push('Missing or invalid zone_id.');
  }
  if (
    !telemetry.gps ||
    typeof telemetry.gps.latitude !== 'number' ||
    typeof telemetry.gps.longitude !== 'number' ||
    telemetry.gps.latitude < -90 ||
    telemetry.gps.latitude > 90 ||
    telemetry.gps.longitude < -180 ||
    telemetry.gps.longitude > 180
  ) {
    errors.push('Invalid GPS coordinates.');
  }
  if (
    telemetry.battery_pct === undefined ||
    typeof telemetry.battery_pct !== 'number' ||
    telemetry.battery_pct < 0 ||
    telemetry.battery_pct > 100
  ) {
    errors.push(`Invalid battery level: ${telemetry.battery_pct}%. Must be between 0 and 100.`);
  }

  const validStates: RoverState[] = [
    'IDLE',
    'SCANNING',
    'IRRIGATING',
    'RE_SCANNING',
    'STOPPED',
    'ERROR',
    'CHARGING',
  ];
  if (!telemetry.status || !validStates.includes(telemetry.status)) {
    errors.push(`Invalid rover status: ${telemetry.status}.`);
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}
