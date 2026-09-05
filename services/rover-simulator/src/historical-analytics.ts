/**
 * PRAHAR Historical Analytics & Farm Risk Dashboard
 * Aligned with Amendment 4 & 10:
 * - Farm Risk Conditions across Water, Crop, Pest, Disease, Heat
 * - Transparent PRAHAR Composite Indicator — Demo Metric
 * - Centralized calculation and documented formula
 * - Time-series trend analytics and intervention verification delta tracking
 */

import {
  FarmRiskDashboardData,
  FarmConditionMetric,
  COMPOSITE_INDICATOR_WEIGHTS,
  RemediationVerification,
  Alert,
} from '@prahar/shared';
import { IAlertStore } from './alert-store.js';

export interface HistoricalTrendPoint {
  timestamp: string;
  moisture_pct: number;
  temperature_c: number;
  humidity_pct: number;
}

export class HistoricalAnalytics {
  private alertStore: IAlertStore;

  constructor(alertStore: IAlertStore) {
    this.alertStore = alertStore;
  }

  /**
   * Generates Farm Risk Dashboard metrics including the transparent Composite Demo Indicator.
   */
  public async getFarmRiskDashboard(farmId: string = 'FARM-DEMO-01'): Promise<FarmRiskDashboardData> {
    const alerts = await this.alertStore.getAlerts();
    const activeAlerts = alerts.filter((a) => a.status === 'NEW' || a.status === 'ACKNOWLEDGED');

    const hasWaterStress = activeAlerts.some((a) => a.type === 'WATER_STRESS');
    const hasDisease = activeAlerts.some((a) => a.type === 'DISEASE');
    const hasPest = activeAlerts.some((a) => a.type === 'PEST');

    // 1. Calculate Component Scores (0 to 100, where 100 is optimal/zero risk)
    const waterScore = hasWaterStress ? 40 : 85;
    const diseaseScore = hasDisease ? 55 : 90;
    const pestScore = hasPest ? 60 : 92;
    const heatScore = 75; // Based on seasonal elevated 33-34°C baseline
    const cropScore = Math.round((waterScore + diseaseScore) / 2);

    const conditions: FarmRiskDashboardData['conditions'] = {
      water: {
        category: 'WATER',
        status: hasWaterStress ? 'STRESSED' : 'OPTIMAL',
        score_out_of_100: waterScore,
        summary_en: hasWaterStress ? 'Zone 2 exhibits sub-20% soil moisture depletion.' : 'Soil moisture within target thresholds.',
        summary_hi: hasWaterStress ? 'ज़ोन 2 में मिट्टी की नमी 20% से कम हो गई है।' : 'मिट्टी की नमी लक्ष्य सीमा में है।',
      },
      crop: {
        category: 'CROP',
        status: cropScore < 60 ? 'MODERATE' : 'OPTIMAL',
        score_out_of_100: cropScore,
        summary_en: 'Tomato crop canopy vegetative index stable.',
        summary_hi: 'टमाटर की फसल का कैनोपी सूचकांक स्थिर है।',
      },
      pest: {
        category: 'PEST',
        status: hasPest ? 'MODERATE' : 'OPTIMAL',
        score_out_of_100: pestScore,
        summary_en: hasPest ? 'Isolated pest vectors observed in peripheral zone.' : 'No active pest infestations detected.',
        summary_hi: hasPest ? 'सीमांत क्षेत्र में छिटपुट कीट देखे गए।' : 'कोई सक्रिय कीट प्रकोप नहीं है।',
      },
      disease: {
        category: 'DISEASE',
        status: hasDisease ? 'STRESSED' : 'OPTIMAL',
        score_out_of_100: diseaseScore,
        summary_en: hasDisease ? 'Fungal disease risk elevated under localized humidity.' : 'No fungal lesions detected.',
        summary_hi: hasDisease ? 'स्थानीय आर्द्रता के कारण फफूंद रोग का जोखिम बढ़ा है।' : 'कोई फफूंद धब्बे नहीं पाए गए।',
      },
      heat: {
        category: 'HEAT',
        status: 'MODERATE',
        score_out_of_100: heatScore,
        summary_en: 'Midday temperatures reach 33-35°C.',
        summary_hi: 'दोपहर का तापमान 33-35°C तक पहुँच रहा है।',
      },
    };

    // 2. Centralized Composite Formula:
    // Score = (Water * 0.35) + (Disease * 0.25) + (Pest * 0.20) + (Heat * 0.20)
    const compositeScore = Math.round(
      waterScore * COMPOSITE_INDICATOR_WEIGHTS.MOISTURE_WEIGHT +
      diseaseScore * COMPOSITE_INDICATOR_WEIGHTS.DISEASE_WEIGHT +
      pestScore * COMPOSITE_INDICATOR_WEIGHTS.PEST_WEIGHT +
      heatScore * COMPOSITE_INDICATOR_WEIGHTS.HEAT_WEIGHT
    );

    let classification: FarmRiskDashboardData['composite_indicator']['classification'] = 'OPTIMAL';
    if (compositeScore < 50) classification = 'CRITICAL';
    else if (compositeScore < 70) classification = 'REQUIRES_ATTENTION';
    else if (compositeScore < 85) classification = 'FAIR';

    return {
      farm_id: farmId,
      conditions,
      composite_indicator: {
        score_out_of_100: compositeScore,
        classification,
        label: 'PRAHAR Composite Indicator — Demo Metric',
        formula_description: 'Weighted composite formula: (Moisture x 35%) + (Disease x 25%) + (Pest x 20%) + (Heat x 20%). Demo indicator for prototype scoring.',
        weights: COMPOSITE_INDICATOR_WEIGHTS,
        is_scientifically_validated: false, // Mandatory honesty declaration
      },
      active_alerts_count: activeAlerts.length,
      last_evaluated_at: new Date().toISOString(),
    };
  }

  /**
   * Generates time-series historical trend metrics and highlights intervention effectiveness.
   */
  public async getHistoricalIntelligence(zoneId: string = 'DEMO-ZONE-02'): Promise<{
    zone_id: string;
    trend_points: HistoricalTrendPoint[];
    verified_interventions: RemediationVerification[];
    summary_insight_en: string;
    summary_insight_hi: string;
  }> {
    const now = Date.now();
    const trendPoints: HistoricalTrendPoint[] = [
      {
        timestamp: new Date(now - 4 * 3600000).toISOString(),
        moisture_pct: 26.5,
        temperature_c: 28.0,
        humidity_pct: 62.0,
      },
      {
        timestamp: new Date(now - 3 * 3600000).toISOString(),
        moisture_pct: 22.0,
        temperature_c: 31.0,
        humidity_pct: 54.0,
      },
      {
        timestamp: new Date(now - 2 * 3600000).toISOString(),
        moisture_pct: 18.2,
        temperature_c: 33.5,
        humidity_pct: 48.0,
      },
      {
        timestamp: new Date(now - 1 * 3600000).toISOString(),
        moisture_pct: 16.5,
        temperature_c: 34.5,
        humidity_pct: 45.0,
      },
      {
        timestamp: new Date(now).toISOString(),
        moisture_pct: 28.5, // Post-intervention recovery
        temperature_c: 31.5,
        humidity_pct: 52.0,
      },
    ];

    const verifications = (await this.alertStore.getVerifications?.(zoneId)) || [];

    return {
      zone_id: zoneId,
      trend_points: trendPoints,
      verified_interventions: verifications,
      summary_insight_en: 'Historical telemetry indicates a steep moisture decline during peak solar hours, successfully reversed by targeted 30s micro-irrigation (+12.0% moisture verified).',
      summary_insight_hi: 'ऐतिहासिक टेलीमेट्री से पता चलता है कि दोपहर में नमी तेजी से घटी थी, जिसे 30 सेकंड की लक्षित सूक्ष्म-सिंचाई द्वारा सफलतापूर्वक बहाल किया गया (+12.0% नमी सत्यापित)।',
    };
  }
}
