/**
 * PRAHAR Phase 4 Test Suite — Historical Analytics, Reports & Opportunity Center
 * Validates:
 * 1. PRAHAR Composite Indicator — Demo Metric (Formula, centralized weights: Moisture 35%, Disease 25%, Pest 20%, Heat 20%).
 * 2. Boundary conditions for composite health index (0 to 100).
 * 3. PRAHAR Field Evidence Report with mandatory non-government legal disclaimer.
 * 4. Farmer Opportunity Center with verified Indian government portals & non-submission disclaimer.
 */

import { test, describe } from 'node:test';
import assert from 'node:assert';
import { InMemoryAlertStore } from '../services/rover-simulator/src/alert-store.js';
import { HistoricalAnalytics } from '../services/rover-simulator/src/historical-analytics.js';
import {
  FieldEvidenceReportGenerator,
  OpportunityCenter,
} from '../services/rover-simulator/src/reports-and-opportunities.js';
import { RemediationVerification, RoverScanPayload, COMPOSITE_INDICATOR_WEIGHTS } from '@prahar/shared';

describe('Phase 4: Composite Health Indicator — Demo Metric', () => {
  const alertStore = new InMemoryAlertStore();
  const analytics = new HistoricalAnalytics(alertStore);

  test('Centralized weights match specification (Moisture 35%, Disease 25%, Pest 20%, Heat 20%)', () => {
    assert.strictEqual(COMPOSITE_INDICATOR_WEIGHTS.MOISTURE_WEIGHT, 0.35);
    assert.strictEqual(COMPOSITE_INDICATOR_WEIGHTS.DISEASE_WEIGHT, 0.25);
    assert.strictEqual(COMPOSITE_INDICATOR_WEIGHTS.PEST_WEIGHT, 0.20);
    assert.strictEqual(COMPOSITE_INDICATOR_WEIGHTS.HEAT_WEIGHT, 0.20);

    const sum =
      COMPOSITE_INDICATOR_WEIGHTS.MOISTURE_WEIGHT +
      COMPOSITE_INDICATOR_WEIGHTS.DISEASE_WEIGHT +
      COMPOSITE_INDICATOR_WEIGHTS.PEST_WEIGHT +
      COMPOSITE_INDICATOR_WEIGHTS.HEAT_WEIGHT;
    assert.strictEqual(Number(sum.toFixed(2)), 1.00);
  });

  test('Farm Risk Dashboard contains required Demo Metric labeling and documented formula', async () => {
    const dashboard = await analytics.getFarmRiskDashboard('DEMO-FARM-01');

    assert.strictEqual(dashboard.composite_indicator.label, 'PRAHAR Composite Indicator — Demo Metric');
    assert.strictEqual(dashboard.composite_indicator.is_scientifically_validated, false);
    assert.ok(dashboard.composite_indicator.formula_description.includes('Moisture x 35%'));
    assert.ok(dashboard.composite_indicator.formula_description.includes('Disease x 25%'));
    assert.ok(dashboard.composite_indicator.formula_description.includes('Pest x 20%'));
    assert.ok(dashboard.composite_indicator.formula_description.includes('Heat x 20%'));
    assert.ok(
      dashboard.composite_indicator.score_out_of_100 >= 0 &&
      dashboard.composite_indicator.score_out_of_100 <= 100
    );
  });

  test('Time-series historical intelligence tracks trends across 4 hours', async () => {
    const intelligence = await analytics.getHistoricalIntelligence('DEMO-ZONE-02');
    assert.strictEqual(intelligence.zone_id, 'DEMO-ZONE-02');
    assert.ok(intelligence.trend_points.length >= 4);
    assert.ok(intelligence.summary_insight_en.length > 0);
    assert.ok(intelligence.summary_insight_hi.length > 0);
  });
});

describe('Phase 4: Field Evidence Report & Legal Disclaimer', () => {
  test('Report is named PRAHAR Field Evidence Report and contains mandatory non-government disclaimer', () => {
    const mockScan: RoverScanPayload = {
      scan_id: 'scan-rep-01',
      rover_id: 'ROVER-DEMO-01',
      zone_id: 'DEMO-ZONE-02',
      gps: { latitude: 12.9734, longitude: 77.5934 },
      battery_pct: 94.0,
      timestamp: new Date().toISOString(),
      sensor_readings: [
        { zone_id: 'DEMO-ZONE-02', type: 'moisture', value: 17.5, unit: '%', timestamp: new Date().toISOString(), source: 'probe' },
        { zone_id: 'DEMO-ZONE-02', type: 'temperature', value: 34.0, unit: '°C', timestamp: new Date().toISOString(), source: 'probe' },
      ],
      detections: [
        {
          id: 'det-rep-01',
          zone_id: 'DEMO-ZONE-02',
          hazard_type: 'WATER_STRESS',
          hazard_name: 'Soil Moisture Deficit',
          confidence: 0.92,
          severity_hint: 'HIGH',
          timestamp: new Date().toISOString(),
          source: 'ai',
        },
      ],
    };

    const mockVerification: RemediationVerification = {
      verification_id: 'verif-rep-01',
      zone_id: 'DEMO-ZONE-02',
      action_id: 'act-rep-01',
      pre_moisture: 17.5,
      post_moisture: 28.2,
      moisture_delta: 10.7,
      resolved: true,
      verification_timestamp: new Date().toISOString(),
      summary_en: 'Zone 2 moisture improved from 17.5% to 28.2% (+10.7%).',
      summary_hi: 'ज़ोन 2 नमी 17.5% से बढ़कर 28.2% हो गई।',
    };

    const report = FieldEvidenceReportGenerator.generateReport({
      farmId: 'DEMO-FARM-01',
      farmName: 'Demo Farm Alpha',
      zoneId: 'DEMO-ZONE-02',
      scan: mockScan,
      actionExecuted: 'IRRIGATE (30s micro-irrigation)',
      approvedBy: 'dr_sharma_kvk_expert',
      verification: mockVerification,
    });

    assert.strictEqual(report.report_title, 'PRAHAR Field Evidence Report');
    assert.ok(report.disclaimer.includes('NOT an official government certificate'));
    assert.ok(report.disclaimer.includes('PRAHAR-generated informational field evidence report'));
    assert.strictEqual(report.before_after_metrics?.pre_moisture, 17.5);
    assert.strictEqual(report.before_after_metrics?.post_moisture, 28.2);
    assert.strictEqual(report.before_after_metrics?.delta, 10.7);
  });
});

describe('Phase 4: Farmer Opportunity Center & Verified Schemes', () => {
  test('All government schemes use official, verified Indian government URLs', () => {
    const schemes = OpportunityCenter.getSchemes();
    assert.ok(schemes.length >= 4);

    const kusum = schemes.find((s) => s.scheme_id.includes('KUSUM'));
    assert.ok(kusum);
    assert.strictEqual(kusum.official_portal_url, 'https://pmkusum.mnre.gov.in');
    assert.strictEqual(kusum.source_type, 'OFFICIAL_GOVERNMENT_SCHEME');

    const pdmc = schemes.find((s) => s.scheme_id.includes('PDMC'));
    assert.ok(pdmc);
    assert.strictEqual(pdmc.official_portal_url, 'https://pmksy.gov.in');

    const smam = schemes.find((s) => s.scheme_id.includes('SMAM'));
    assert.ok(smam);
    assert.strictEqual(smam.official_portal_url, 'https://agrimachinery.nic.in');

    const pmfby = schemes.find((s) => s.scheme_id.includes('PMFBY'));
    assert.ok(pmfby);
    assert.strictEqual(pmfby.official_portal_url, 'https://pmfby.gov.in');
  });

  test('All schemes provide explicit PRAHAR informational assistance note', () => {
    const schemes = OpportunityCenter.getSchemes();
    for (const scheme of schemes) {
      assert.ok(scheme.prahar_assistance_note_en.includes('informational guidance only') || scheme.prahar_assistance_note_en.includes('PRAHAR'));
      assert.ok(scheme.official_portal_url.startsWith('https://'));
    }
  });
});
