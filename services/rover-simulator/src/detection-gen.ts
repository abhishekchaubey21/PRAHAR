/**
 * PRAHAR Rover Simulator — Crop / Pest / Hazard Detection Generator
 * Simulates edge AI computer vision model inferences.
 */

import { Detection, HazardType, SeverityLevel } from '@prahar/shared';

interface HazardTemplate {
  hazard_type: HazardType;
  hazard_name: string;
  default_severity: SeverityLevel;
  notes: string;
}

const HAZARD_TEMPLATES: HazardTemplate[] = [
  {
    hazard_type: 'DISEASE',
    hazard_name: 'Early Blight (Alternaria solani)',
    default_severity: 'MEDIUM',
    notes: 'Brown to black necrotic concentric rings observed on basal foliage.',
  },
  {
    hazard_type: 'DISEASE',
    hazard_name: 'Tomato Leaf Curl Virus',
    default_severity: 'HIGH',
    notes: 'Stunted plant growth, severe upward leaf curling and chlorosis.',
  },
  {
    hazard_type: 'PEST',
    hazard_name: 'Fall Armyworm (Spodoptera frugiperda)',
    default_severity: 'HIGH',
    notes: 'Visible pinhole feeding damage and frass on whorl leaves.',
  },
  {
    hazard_type: 'PEST',
    hazard_name: 'Aphid Colony (Aphis gossypii)',
    default_severity: 'MEDIUM',
    notes: 'Dense clustering of nymphs on underside of young terminal leaves.',
  },
  {
    hazard_type: 'WATER_STRESS',
    hazard_name: 'Severe Root-Zone Moisture Deficit',
    default_severity: 'HIGH',
    notes: 'Turgor loss and leaf wilting consistent with soil moisture < 20%.',
  },
  {
    hazard_type: 'WEED',
    hazard_name: 'Parthenium Hysterophorus Infestation',
    default_severity: 'LOW',
    notes: 'Dense invasive weed patches along furrow bed edges.',
  },
  {
    hazard_type: 'NUTRIENT_DEFICIENCY',
    hazard_name: 'Nitrogen Deficiency Chlorosis',
    default_severity: 'LOW',
    notes: 'Generalized pale yellowing progressing from older to newer leaves.',
  },
];

/**
 * Generates synthetic detections for a given zone.
 * In Zone 2, higher probability of water stress; in Zone 3, higher probability of disease.
 */
export function generateDetections(params: {
  zoneId: string;
  forceHazard?: boolean;
}): Detection[] {
  const detections: Detection[] = [];
  const { zoneId, forceHazard = false } = params;

  // Decide if this zone scan finds hazards
  const shouldFindHazard =
    forceHazard ||
    zoneId === 'DEMO-ZONE-02' ||
    zoneId === 'DEMO-ZONE-03' ||
    Math.random() < 0.35;

  if (!shouldFindHazard) {
    return detections;
  }

  // Select appropriate hazards based on zone characteristics
  let templatesToUse: HazardTemplate[] = [];

  if (zoneId === 'DEMO-ZONE-02') {
    // Dry zone -> Water stress detection
    templatesToUse.push(HAZARD_TEMPLATES[4]); // Water stress
  } else if (zoneId === 'DEMO-ZONE-03') {
    // Humid zone -> Early blight disease or aphids
    templatesToUse.push(HAZARD_TEMPLATES[0]); // Early blight
    if (Math.random() < 0.5) {
      templatesToUse.push(HAZARD_TEMPLATES[3]); // Aphids
    }
  } else {
    // Random pick from templates
    const picked = HAZARD_TEMPLATES[Math.floor(Math.random() * HAZARD_TEMPLATES.length)];
    templatesToUse.push(picked);
  }

  for (const t of templatesToUse) {
    const confidence = Number((0.75 + Math.random() * 0.22).toFixed(3)); // 0.75 to 0.97
    const detId = `det-${zoneId.toLowerCase()}-${Date.now().toString(36)}-${Math.random().toString(36).substring(2, 6)}`;

    detections.push({
      id: detId,
      zone_id: zoneId,
      hazard_type: t.hazard_type,
      hazard_name: t.hazard_name,
      confidence,
      severity_hint: t.default_severity,
      image_ref: `sim_img_${zoneId.toLowerCase()}_${Date.now()}.webp`,
      bounding_box: {
        x: Math.floor(100 + Math.random() * 200),
        y: Math.floor(100 + Math.random() * 200),
        width: Math.floor(150 + Math.random() * 150),
        height: Math.floor(150 + Math.random() * 150),
      },
      notes: t.notes,
      timestamp: new Date().toISOString(),
      source: 'rover_ai_edge_v1',
    });
  }

  return detections;
}
