/**
 * PRAHAR AI Decision Layer & Closed-Loop Contracts
 * Aligned with PRAHAR Engineering Specification v1.0 Section 7, 8 & Manager Blueprint.
 */

import { SeverityLevel, Detection, HazardType } from './detection.js';
import { SensorBundle } from './telemetry.js';
import { Alert } from './alert.js';

/**
 * Centralized, Configurable Decision Engine Thresholds.
 * Centralized configuration per Requirement 8 (no scattered magic numbers).
 */
export const DECISION_THRESHOLDS = {
  // Confidence Gating: < 0.70 strictly suppresses physical intervention and routes to expert
  MIN_CONFIDENCE_THRESHOLD: 0.70,
  HIGH_CONFIDENCE_THRESHOLD: 0.85,

  // Agronomic Sensor Thresholds
  LOW_MOISTURE_CRITICAL_PCT: 20.0,
  LOW_MOISTURE_WARNING_PCT: 25.0,
  OPTIMAL_MOISTURE_PCT: 35.0,
  HIGH_TEMP_HEAT_STRESS_C: 32.0,
  HIGH_HUMIDITY_DISEASE_RISK_PCT: 70.0,
  ACIDIC_SOIL_PH: 5.5,
  ALKALINE_SOIL_PH: 7.8,

  // Safety & Remediation Bounds
  DEFAULT_IRRIGATION_DURATION_SEC: 30,
  DEFAULT_IRRIGATION_VOLUME_L: 7.5,
  MAX_IRRIGATION_DURATION_SEC: 180,
  MAX_IRRIGATION_VOLUME_L: 50.0,

  // Deduplication Window: 24 Hours
  ALERT_DEDUPLICATION_WINDOW_MS: 24 * 60 * 60 * 1000,
} as const;

export type RecommendedActionType =
  | 'RECOMMEND_IRRIGATION'
  | 'RECOMMEND_INSPECTION'
  | 'ROUTE_TO_EXPERT'
  | 'MONITOR';

export interface ActionRecommendation {
  action_type: RecommendedActionType;
  description_en: string;
  description_hi: string;
  suggested_params: {
    duration_seconds?: number;
    volume_liters?: number;
    target_zone_id: string;
  };
  requires_approval: true; // Mandatory safety gate: always true for physical action
  approval_status: 'PENDING_APPROVAL' | 'APPROVED' | 'REJECTED' | 'EXECUTED';
}

export interface DecisionResult {
  zone_id: string;
  overall_severity: SeverityLevel;
  requires_expert_review: boolean;
  action_recommendation?: ActionRecommendation;
  alerts_to_create: Alert[];
  alerts_updated: Alert[];
  reasons: string[];
  evaluated_at: string;
}

/**
 * Closed-Loop Remediation Verification Record (Requirement 3).
 * Must genuinely compare pre- and post-intervention state.
 */
export interface RemediationVerification {
  verification_id: string;
  zone_id: string;
  action_id: string;
  pre_moisture: number;
  post_moisture: number;
  moisture_delta: number;
  pre_detection?: Detection;
  post_detection?: Detection;
  resolved: boolean;
  verification_timestamp: string;
  summary_en: string;
  summary_hi: string;
}

/**
 * Expert Action Audit Record (Requirement 5).
 */
export interface ExpertAuditRecord {
  audit_id: string;
  actor: string;
  timestamp: string;
  zone_id: string;
  alert_id: string;
  action: 'CONFIRM' | 'CORRECT' | 'ESCALATE' | 'APPROVE_INTERVENTION' | 'REJECT_INTERVENTION';
  previous_state: string;
  new_state: string;
  expert_note?: string;
}
