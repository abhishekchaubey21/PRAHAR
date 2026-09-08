/**
 * PRAHAR Phase 4 — Multimodal Farm Intelligence, Voice, and Risk Contracts
 * Aligned with PRAHAR Engineering Specification v1.0 & Manager Phase 4 Directives.
 */

import { SeverityLevel, Detection, HazardType } from './detection.js';
import { SensorReading } from './telemetry.js';
import { Alert } from './alert.js';

// ============================================================================
// 1. Weather & Agricultural Risk Contracts
// ============================================================================

export type RiskCategory =
  | 'HEAT_STRESS'
  | 'WATER_STRESS'
  | 'FLOOD_RISK'
  | 'HUMIDITY_DISEASE_RISK'
  | 'IRRIGATION_SUITABILITY';

export type WeatherProviderType = 'LIVE_STATION' | 'EXTERNAL_API' | 'SIMULATION_DEMO';

export interface WeatherContext {
  temperature_c: number;
  relative_humidity_pct: number;
  rainfall_probability_pct: number;
  rainfall_forecast_24h_mm: number;
  wind_speed_kmh: number;
  provider_type: WeatherProviderType; // Explicitly distinguishes SIMULATION vs LIVE
  provider_label: string; // e.g. "SIMULATION WEATHER (DEMO Seasonal Engine)"
  forecast_summary_en: string;
  forecast_summary_hi: string;
  fetched_at: string;
  is_degraded_fallback: boolean;
}

export interface AgriculturalRiskAssessment {
  category: RiskCategory;
  risk_level: SeverityLevel;
  impact_description_en: string;
  impact_description_hi: string;
  irrigation_advisable: boolean;
  irrigation_advice_reason_en: string;
  irrigation_advice_reason_hi: string;
  contributing_factors: string[];
}

// ============================================================================
// 2. Explainability ("WHY Layer") Contracts
// ============================================================================

export interface EvidenceItem {
  source: 'SENSOR' | 'VISION_AI' | 'WEATHER' | 'HISTORICAL_BASELINE';
  parameter: string;
  value: string | number;
  threshold?: string | number;
  status: 'OPTIMAL' | 'ELEVATED' | 'WARNING' | 'CRITICAL';
  description_en: string;
  description_hi: string;
}

export interface ExplainabilityReport {
  recommendation_id: string;
  zone_id: string;
  observed_evidence: EvidenceItem[];
  detection_confidence?: number;
  contributing_rules: string[];
  plain_reason_en: string;
  plain_reason_hi: string;
  recommended_action_en: string;
  recommended_action_hi: string;
  confidence_rating: 'HIGH' | 'MEDIUM' | 'PROVISIONAL';
  limitations: string[];
  generated_at: string;
}

// ============================================================================
// 3. Constrained Multilingual Voice Contracts
// ============================================================================

export type VoiceIntentType =
  | 'FARM_STATUS'
  | 'ZONE_STATUS'
  | 'EXPLAIN_ALERT'
  | 'EXPLAIN_RECOMMENDATION'
  | 'LIST_ALERTS'
  | 'APPROVE_IRRIGATION'
  | 'CONFIRM_ACTION'
  | 'CANCEL_ACTION'
  | 'UNKNOWN';

export type VoiceInputType = 'REAL_SPEECH_STT' | 'SIMULATED_VOICE_INTENT';

export interface VoiceQuery {
  text: string;
  language: 'en' | 'hi';
  input_type: VoiceInputType; // Clearly distinguishes Real Mic STT vs Demo Text Intent
  user_id: string;
  role: 'FARMER' | 'EXPERT' | 'ADMIN';
  session_id?: string;
}

export interface VoiceResponse {
  spoken_text_en: string;
  spoken_text_hi: string;
  intent: VoiceIntentType;
  requires_confirmation: boolean;
  confirmation_prompt_en?: string;
  confirmation_prompt_hi?: string;
  pending_action?: {
    action_type: string;
    zone_id: string;
    duration_seconds: number;
    volume_liters: number;
  };
  safety_notice_en: string;
  safety_notice_hi: string;
}

// ============================================================================
// 4. Multimodal Secondary Evidence Contracts
// ============================================================================

export type MultimodalAgreementStatus =
  | 'AGREEMENT'
  | 'CONTRADICTION'
  | 'UNCERTAINTY'
  | 'COMPLEMENTARY';

export interface MultimodalAnalysisRequest {
  image_ref?: string;
  image_base64?: string;
  user_initiated: boolean; // Mandatory: must be explicitly user-initiated
  zone_id: string;
  primary_detection?: Detection; // Guy 3's edge model detection (Primary Ground Truth)
  sensor_summary?: {
    moisture?: number;
    temperature?: number;
    humidity?: number;
  };
}

export interface MultimodalAnalysisResult {
  status: MultimodalAgreementStatus;
  secondary_findings_en: string;
  secondary_findings_hi: string;
  visual_confidence_hint: number;
  recommendation_modifier?: string;
  requires_expert_review: boolean;
  is_provider_fallback: boolean;
  analyzed_at: string;
  disclaimer: string;
}

// ============================================================================
// 5. Farm Risk Dashboard & Composite Health Indicator
// ============================================================================

/**
 * Transparent Centralized Weights for the PRAHAR Composite Demo Metric.
 * Stated explicitly: These are DEMO COMPOSITE weights, NOT scientifically validated truth.
 */
export const COMPOSITE_INDICATOR_WEIGHTS = {
  MOISTURE_WEIGHT: 0.35,
  DISEASE_WEIGHT: 0.25,
  PEST_WEIGHT: 0.20,
  HEAT_WEIGHT: 0.20,
} as const;

export interface FarmConditionMetric {
  category: 'WATER' | 'CROP' | 'PEST' | 'DISEASE' | 'HEAT';
  status: 'OPTIMAL' | 'MODERATE' | 'STRESSED' | 'CRITICAL';
  score_out_of_100: number;
  summary_en: string;
  summary_hi: string;
}

export interface FarmRiskDashboardData {
  farm_id: string;
  conditions: {
    water: FarmConditionMetric;
    crop: FarmConditionMetric;
    pest: FarmConditionMetric;
    disease: FarmConditionMetric;
    heat: FarmConditionMetric;
  };
  composite_indicator: {
    score_out_of_100: number;
    classification: 'OPTIMAL' | 'FAIR' | 'REQUIRES_ATTENTION' | 'CRITICAL';
    label: string; // "PRAHAR Composite Indicator — Demo Metric"
    formula_description: string;
    weights: typeof COMPOSITE_INDICATOR_WEIGHTS;
    is_scientifically_validated: false; // Mandatory honesty flag
  };
  active_alerts_count: number;
  last_evaluated_at: string;
}

// ============================================================================
// 6. Field Evidence Report
// ============================================================================

export interface FieldEvidenceReport {
  report_id: string;
  report_title: 'PRAHAR Field Evidence Report';
  farm_id: string;
  farm_name: string;
  location?: string;
  crop_type?: string;
  zone_id: string;
  zone_name?: string;
  soil_type?: string;
  generated_at: string;
  scan_time: string;
  period?: {
    from: string;
    to: string;
  };
  field_health_summary?: {
    status: string;
    health_label: string;
    summary_en: string;
    summary_hi: string;
  };
  hazard_summary: {
    hazard_type: HazardType;
    hazard_name: string;
    severity: SeverityLevel;
    detection_confidence: number;
  };
  sensor_evidence: {
    moisture: number;
    temperature: number;
    humidity: number;
    ph: number;
  };
  hazard_history?: Array<{
    timestamp: string;
    hazard_type: string;
    hazard_name: string;
    severity: string;
    confidence: number;
  }>;
  alerts_history?: Array<{
    id: string;
    title: string;
    severity: string;
    status: string;
    created_at: string;
  }>;
  interventions_history?: Array<{
    action_id: string;
    action_type: string;
    duration_seconds?: number;
    volume_liters?: number;
    approved_by?: string;
    approved_at?: string;
    status: string;
    created_at: string;
    verification?: {
      verification_id: string;
      pre_moisture: number;
      post_moisture: number;
      moisture_delta: number;
      resolution_status: string;
      verified_at: string;
    };
  }>;
  weather_context_summary: string;
  recommendation_made: string;
  recommendations?: string[];
  action_approved_by?: string;
  action_executed: string;
  before_after_metrics?: {
    pre_moisture: number;
    post_moisture: number;
    delta: number;
    resolution_status: string;
  };
  verification_outcome: string;
  disclaimer: string; // Explicit non-government declaration
  pdf_base64?: string;
}

export interface GenerateReportOptions {
  farm_id: string;
  zone_id?: string;
  from?: string;
  to?: string;
  format?: 'json' | 'pdf';
}

// ============================================================================
// 7. Farmer Opportunity Center
// ============================================================================

export type OpportunitySourceType =
  | 'OFFICIAL_GOVERNMENT_SCHEME'
  | 'PRAHAR_GUIDANCE'
  | 'UNVERIFIED';

export type OpportunityType = 'SCHEME' | 'SUBSIDY' | 'LOAN' | 'INSURANCE' | 'SUPPORT';

export type OpportunityCategory =
  | 'SOLAR_PUMP'
  | 'CROP_INSURANCE'
  | 'EQUIPMENT_SUBSIDY'
  | 'SOIL_HEALTH'
  | 'MICRO_IRRIGATION'
  | 'DIRECT_BENEFIT'
  | 'CREDIT';

export type OpportunityVerificationStatus = 'VERIFIED' | 'NEEDS_VERIFICATION';

export interface OpportunityApplicationStep {
  step_number: number;
  title_en: string;
  title_hi: string;
  description_en: string;
  description_hi: string;
  is_online: boolean;
  portal_url?: string;
}

export interface DeterministicEligibilityRule {
  field: 'land_acres' | 'crop_type' | 'state' | 'aadhaar_verified' | 'bank_account' | 'irrigation_status' | 'ownership_type';
  operator: 'gte' | 'lte' | 'in' | 'eq' | 'required';
  value?: any;
  label_en: string;
  label_hi: string;
}

export interface FarmerOpportunity {
  id: string;
  scheme_id: string; // compatibility alias for id
  title_en: string;
  title_hi: string;
  type: OpportunityType;
  category: OpportunityCategory;
  source_type: OpportunitySourceType; // Clearly distinguishes official vs guidance
  sponsoring_agency: string; // e.g., "Ministry of Agriculture & Farmers Welfare, Govt of India"
  department_authority: string; // e.g., "Ministry of Agriculture & Farmers Welfare, Govt of India"
  description_en: string;
  description_hi: string;
  benefits_summary_en: string;
  benefits_summary_hi: string;
  target_profile_en: string;
  target_profile_hi: string;
  eligibility_criteria_en: string[];
  eligibility_criteria_hi: string[];
  required_documents: string[];
  official_portal_url: string; // Verified real Indian government URL (.gov.in / .nic.in)
  application_procedure_summary_en: string;
  application_procedure_summary_hi: string;
  application_steps: OpportunityApplicationStep[];
  prahar_assistance_note_en: string; // Clarifies PRAHAR does not directly submit apps
  prahar_assistance_note_hi: string;
  last_verified_at: string;
  status: OpportunityVerificationStatus;
  disclaimer: string; // Mandatory non-government guidance declaration
  deterministic_rules?: DeterministicEligibilityRule[];
}

export type EligibilityResultStatus =
  | 'LIKELY_ELIGIBLE'
  | 'MAY_BE_ELIGIBLE'
  | 'INSUFFICIENT_INFORMATION'
  | 'LIKELY_NOT_ELIGIBLE';

export type ApplicationTrackingStatus =
  | 'NOT_STARTED'
  | 'PREPARING'
  | 'READY_TO_APPLY'
  | 'USER_SUBMITTED'
  | 'COMPLETED';

export interface OpportunityEligibilityEvaluation {
  opportunity_id: string;
  status: EligibilityResultStatus;
  matched_criteria_en: string[];
  matched_criteria_hi: string[];
  unmatched_criteria_en: string[];
  unmatched_criteria_hi: string[];
  missing_information_en: string[];
  missing_information_hi: string[];
  disclaimer: string;
  evaluated_at: string;
}

export interface FarmerOpportunityTrackingRecord {
  id: string;
  user_id: string;
  opportunity_id: string;
  status: ApplicationTrackingStatus;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface CheckEligibilityInput {
  opportunity_id: string;
  farm_id?: string;
  crop_type?: string;
  land_acres?: number;
  state?: string;
  irrigation_status?: string;
  ownership_type?: string;
}

export interface UpdateTrackingInput {
  opportunity_id: string;
  status: ApplicationTrackingStatus;
  notes?: string;
}
