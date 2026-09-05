/**
 * PRAHAR Precision Rover — Crop / Pest / Hazard Detection Contracts
 * Aligned with PRAHAR Engineering Specification v1.0 Section 6, 7 & 9.
 */

export type HazardType =
  | 'DISEASE'
  | 'PEST'
  | 'WEED'
  | 'WATER_STRESS'
  | 'NUTRIENT_DEFICIENCY';

export type SeverityLevel = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

export interface BoundingBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface Detection {
  id?: string;
  zone_id: string;
  hazard_type: HazardType;
  hazard_name: string;
  confidence: number; // 0.0 to 1.0
  severity_hint: SeverityLevel;
  image_ref?: string;
  bounding_box?: BoundingBox;
  notes?: string;
  timestamp: string;
  source: string; // e.g. 'rover_cam_front', 'rover_ai_edge_v1'
}

/**
 * Validates a detection object.
 */
export function validateDetection(detection: Partial<Detection>): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!detection.zone_id) {
    errors.push('Missing zone_id.');
  }
  const validHazards: HazardType[] = ['DISEASE', 'PEST', 'WEED', 'WATER_STRESS', 'NUTRIENT_DEFICIENCY'];
  if (!detection.hazard_type || !validHazards.includes(detection.hazard_type)) {
    errors.push(`Invalid hazard_type: ${detection.hazard_type}.`);
  }
  if (!detection.hazard_name || typeof detection.hazard_name !== 'string') {
    errors.push('Missing hazard_name.');
  }
  if (
    detection.confidence === undefined ||
    typeof detection.confidence !== 'number' ||
    detection.confidence < 0 ||
    detection.confidence > 1
  ) {
    errors.push(`Invalid confidence: ${detection.confidence}. Must be between 0.0 and 1.0.`);
  }

  const validSeverities: SeverityLevel[] = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
  if (!detection.severity_hint || !validSeverities.includes(detection.severity_hint)) {
    errors.push(`Invalid severity_hint: ${detection.severity_hint}.`);
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}
