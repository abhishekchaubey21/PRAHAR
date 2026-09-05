/**
 * PRAHAR Rover Simulator — Telemetry & Sensor Generator
 * Aligned with PRAHAR Engineering Specification v1.0 Section 6.
 */

import { GPSCoordinates, SensorReading, SensorBundle, RoverTelemetry, RoverState } from '@prahar/shared';

export interface ZoneProfile {
  zone_id: string;
  name: string;
  center_gps: GPSCoordinates;
  base_moisture_pct: number;
  base_temperature_c: number;
  base_humidity_pct: number;
  base_ph: number;
}

export const DEMO_ZONE_PROFILES: Record<string, ZoneProfile> = {
  'DEMO-ZONE-01': {
    zone_id: 'DEMO-ZONE-01',
    name: 'Zone 1 - North Sector (Optimal)',
    center_gps: { latitude: 12.9734, longitude: 77.5912, altitude_m: 915.0 },
    base_moisture_pct: 38.0,
    base_temperature_c: 27.5,
    base_humidity_pct: 65.0,
    base_ph: 6.8,
  },
  'DEMO-ZONE-02': {
    zone_id: 'DEMO-ZONE-02',
    name: 'Zone 2 - East Sector (Water Stressed)',
    center_gps: { latitude: 12.9734, longitude: 77.5934, altitude_m: 916.2 },
    base_moisture_pct: 17.5, // Dry / water stress
    base_temperature_c: 34.0,
    base_humidity_pct: 42.0,
    base_ph: 6.5,
  },
  'DEMO-ZONE-03': {
    zone_id: 'DEMO-ZONE-03',
    name: 'Zone 3 - South Sector (Disease Prone)',
    center_gps: { latitude: 12.9712, longitude: 77.5934, altitude_m: 914.8 },
    base_moisture_pct: 32.0,
    base_temperature_c: 29.0,
    base_humidity_pct: 75.0, // High humidity favoring fungal disease
    base_ph: 6.2,
  },
  'DEMO-ZONE-04': {
    zone_id: 'DEMO-ZONE-04',
    name: 'Zone 4 - West Sector (Alkaline Patch)',
    center_gps: { latitude: 12.9712, longitude: 77.5912, altitude_m: 915.5 },
    base_moisture_pct: 28.0,
    base_temperature_c: 30.5,
    base_humidity_pct: 55.0,
    base_ph: 7.6,
  },
};

export function updateZoneMoisture(zoneId: string, newMoisturePct: number): void {
  if (DEMO_ZONE_PROFILES[zoneId]) {
    DEMO_ZONE_PROFILES[zoneId].base_moisture_pct = Number(newMoisturePct.toFixed(1));
  }
}

/**
 * Add random Gaussian-like jitter around a base value.
 */
function jitter(base: number, variance: number): number {
  const delta = (Math.random() - 0.5) * 2 * variance;
  return Number((base + delta).toFixed(2));
}

/**
 * Generates realistic sensor bundle for a zone.
 */
export function generateSensorBundle(zoneId: string = 'DEMO-ZONE-01'): SensorBundle {
  const profile = DEMO_ZONE_PROFILES[zoneId] || DEMO_ZONE_PROFILES['DEMO-ZONE-01'];
  return {
    moisture_pct: Math.max(5.0, Math.min(60.0, jitter(profile.base_moisture_pct, 2.5))),
    temperature_c: Math.max(10.0, Math.min(48.0, jitter(profile.base_temperature_c, 1.2))),
    humidity_pct: Math.max(20.0, Math.min(95.0, jitter(profile.base_humidity_pct, 3.0))),
    ph: Math.max(4.5, Math.min(9.0, jitter(profile.base_ph, 0.2))),
    timestamp: new Date().toISOString(),
  };
}

/**
 * Generates individual SensorReading records from a bundle.
 */
export function bundleToReadings(zoneId: string, bundle: SensorBundle, source: string = 'rover_probe_v1'): SensorReading[] {
  return [
    {
      zone_id: zoneId,
      type: 'moisture',
      value: bundle.moisture_pct,
      unit: '%',
      timestamp: bundle.timestamp,
      source,
    },
    {
      zone_id: zoneId,
      type: 'temperature',
      value: bundle.temperature_c,
      unit: '°C',
      timestamp: bundle.timestamp,
      source,
    },
    {
      zone_id: zoneId,
      type: 'humidity',
      value: bundle.humidity_pct,
      unit: '%',
      timestamp: bundle.timestamp,
      source,
    },
    {
      zone_id: zoneId,
      type: 'ph',
      value: bundle.ph,
      unit: 'pH',
      timestamp: bundle.timestamp,
      source,
    },
  ];
}

/**
 * Generates GPS coordinates with minor positional wander within zone bounds.
 */
export function generateZoneGps(zoneId: string = 'DEMO-ZONE-01'): GPSCoordinates {
  const profile = DEMO_ZONE_PROFILES[zoneId] || DEMO_ZONE_PROFILES['DEMO-ZONE-01'];
  // ~5-15 meters wander
  const latDelta = (Math.random() - 0.5) * 0.0002;
  const lngDelta = (Math.random() - 0.5) * 0.0002;
  return {
    latitude: Number((profile.center_gps.latitude + latDelta).toFixed(7)),
    longitude: Number((profile.center_gps.longitude + lngDelta).toFixed(7)),
    altitude_m: jitter(profile.center_gps.altitude_m || 915.0, 0.5),
  };
}

/**
 * Generates complete RoverTelemetry snapshot.
 */
export function generateRoverTelemetry(params: {
  roverId?: string;
  zoneId?: string;
  batteryPct: number;
  status: RoverState;
  currentTaskId?: string;
}): RoverTelemetry {
  const zoneId = params.zoneId || 'DEMO-ZONE-01';
  return {
    rover_id: params.roverId || 'ROVER-DEMO-01',
    zone_id: zoneId,
    gps: generateZoneGps(zoneId),
    battery_pct: Number(params.batteryPct.toFixed(1)),
    status: params.status,
    tilt_deg: jitter(1.5, 1.0),
    fault_flags: params.batteryPct < 15.0 ? ['LOW_BATTERY_WARNING'] : [],
    current_task_id: params.currentTaskId,
    timestamp: new Date().toISOString(),
  };
}
