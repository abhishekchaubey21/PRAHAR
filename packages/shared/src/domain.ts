/**
 * PRAHAR — Core Agricultural Entities (Section 9)
 */

export interface Farmer {
  id: string;
  name: string;
  phone: string;
  language: string;
  state?: string;
  district?: string;
  village?: string;
  created_at: string;
}

export interface Farm {
  id: string;
  farmer_id: string;
  name: string;
  boundary_geojson: Record<string, any>;
  crop_type: string;
  area_acres: number;
  ownership_type?: string; // 'OWNED' | 'TENANT' | 'SHARECROPPER'
  irrigation_status?: string; // 'IRRIGATED' | 'PARTIAL' | 'RAINFED'
  water_source?: string; // 'BOREWELL' | 'CANAL' | 'OPEN_WELL' | 'RIVER' | 'RAINFED'
  soil_type?: string;
  season?: string; // 'KHARIF' | 'RABI' | 'ZAID' | 'YEAR_ROUND'
  crop_variety?: string;
  sowing_date?: string;
  created_at: string;
}

export interface FarmerProfilePayload {
  name: string;
  state: string;
  district: string;
  village: string;
  preferred_language: 'en' | 'hi' | 'mr' | 'pa';
}

export interface FarmSetupPayload {
  area_acres: number;
  ownership_type: 'OWNED' | 'TENANT' | 'SHARECROPPER';
  irrigation_status: 'IRRIGATED' | 'PARTIAL' | 'RAINFED';
  water_source: 'BOREWELL' | 'CANAL' | 'OPEN_WELL' | 'RIVER' | 'RAINFED';
  soil_type: string;
}

export interface CropSetupPayload {
  main_crops: string[];
  season: 'KHARIF' | 'RABI' | 'ZAID' | 'YEAR_ROUND';
  variety?: string;
  sowing_date?: string;
}

export interface FarmerOnboardingState {
  profile: FarmerProfilePayload;
  farm: FarmSetupPayload;
  crops: CropSetupPayload;
  is_completed: boolean;
  completed_at?: string;
}

export interface Zone {
  id: string;
  farm_id: string;
  zone_name: string;
  geometry_geojson: Record<string, any>;
  soil_type: string;
  last_scan_at?: string;
  created_at: string;
}

// ----------------------------------------------------------------------------
// Phase 6B-1: Notification Contracts
// ----------------------------------------------------------------------------

export type NotificationType =
  | 'ALERT_CREATED'
  | 'RISK_DETECTED'
  | 'ACTION_RECOMMENDED'
  | 'ACTION_APPROVED'
  | 'ACTION_EXECUTED'
  | 'VERIFICATION_COMPLETED'
  | 'VERIFICATION_FAILED'
  | 'SYSTEM';

export type NotificationSeverity = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL' | 'INFO';

export interface NotificationRecord {
  id: string;
  notification_id: string;
  user_id: string;
  farm_id: string;
  zone_id?: string | null;
  alert_id?: string | null;
  action_id?: string | null;
  type: NotificationType;
  severity: NotificationSeverity;
  title: string;
  title_hi?: string | null;
  message: string;
  message_hi?: string | null;
  is_read: boolean;
  created_at: string;
  read_at?: string | null;
  metadata?: Record<string, any>;
  deduplication_key?: string | null;
}

export interface CreateNotificationInput {
  notification_id?: string;
  user_id: string;
  farm_id: string;
  zone_id?: string | null;
  alert_id?: string | null;
  action_id?: string | null;
  type: NotificationType;
  severity: NotificationSeverity;
  title: string;
  title_hi?: string;
  message: string;
  message_hi?: string;
  metadata?: Record<string, any>;
  deduplication_key?: string;
}

export interface ListNotificationsOptions {
  is_read?: boolean;
  limit?: number;
  offset?: number;
}

// ============================================================================
// Phase 6B-2: Farmer Analytics, Field Health & Historical Trends Contracts
// ============================================================================

export type FieldHealthStatus = 'OPTIMAL' | 'ATTENTION_REQUIRED' | 'CRITICAL';

export interface LatestSensorMetrics {
  moisture_pct?: number | null;
  temperature_c?: number | null;
  humidity_pct?: number | null;
  ph?: number | null;
  last_recorded_at?: string | null;
}

export interface ZoneHealthSummary {
  zone_id: string;
  zone_name: string;
  farm_id: string;
  soil_type: string;
  health_status: FieldHealthStatus;
  health_label: string; // "PRAHAR Field-Health & Risk Summary"
  summary_en: string;
  summary_hi: string;
  latest_metrics: LatestSensorMetrics;
  active_alerts_count: number;
  recent_hazard_count: number;
  last_scan_at?: string | null;
  evaluated_at: string;
}

export interface FarmAnalyticsSummary {
  farm_id: string;
  farm_name: string;
  total_zones: number;
  overall_status: FieldHealthStatus;
  health_label: string;
  summary_en: string;
  summary_hi: string;
  active_alerts_count: number;
  zones: ZoneHealthSummary[];
  evaluated_at: string;
}

export interface SensorTrendPoint {
  timestamp: string;
  moisture_pct?: number | null;
  temperature_c?: number | null;
  humidity_pct?: number | null;
  ph?: number | null;
}

export interface HazardTrendItem {
  hazard_type: string;
  hazard_name: string;
  highest_severity: string;
  occurrence_count: number;
  latest_recorded_at: string;
  latest_confidence: number;
}

export interface AnalyticsTrendsResponse {
  zone_id: string;
  zone_name?: string;
  from?: string;
  to?: string;
  has_sufficient_data: boolean;
  sensor_trends: SensorTrendPoint[];
  hazard_breakdown: HazardTrendItem[];
  evaluated_at: string;
}

export interface InterventionHistoryItem {
  action_id: string;
  zone_id: string;
  action_type: string;
  duration_seconds: number;
  volume_liters: number;
  approved_by: string;
  approved_at: string;
  status: string;
  expert_note?: string | null;
  created_at: string;
  verification?: {
    verification_id: string;
    pre_moisture: number;
    post_moisture: number;
    moisture_delta: number;
    resolved: boolean;
    verification_timestamp: string;
    summary_en: string;
    summary_hi: string;
  } | null;
}

export interface AnalyticsInterventionsResponse {
  farm_id?: string;
  zone_id?: string;
  total_count: number;
  interventions: InterventionHistoryItem[];
  evaluated_at: string;
}

// ============================================================================
// Phase 7B: PRAHAR Contextual Field Assistant Contracts
// ============================================================================

export type AssistantIntent =
  | 'FIELD_STATUS'
  | 'ZONE_STATUS'
  | 'HAZARD_EXPLANATION'
  | 'RECOMMENDATION_EXPLANATION'
  | 'ACTION_STATUS'
  | 'VERIFICATION_STATUS'
  | 'SCHEME_QUERY'
  | 'PROFILE_QUERY'
  | 'GENERAL_FARM_GUIDANCE'
  | 'UNKNOWN';

export type AssistantSafetyLevel =
  | 'SAFE_INFORMATIONAL'
  | 'REQUIRES_CONFIRMATION'
  | 'PROHIBITED_AUTONOMOUS';

export type AssistantActionType = 'IRRIGATE' | 'RE_SCAN' | 'NONE';

export interface AssistantContextZone {
  id: string;
  name: string;
  soil_type?: string;
  moisture_pct?: number;
  temperature_c?: number;
  ph?: number;
  active_hazard?: string | null;
  severity?: string;
}

export interface AssistantContextAlert {
  id: string;
  zone_id: string;
  hazard_type: string;
  severity: string;
  title: string;
  why_reasoning?: string;
}

export interface FarmerAssistantContext {
  data_source: 'DEMO';
  rover_status: 'DISCONNECTED';
  farmer?: {
    id?: string;
    name?: string;
    phone?: string;
    state?: string;
    district?: string;
    village?: string;
    language?: string;
  };
  farm?: {
    id?: string;
    name?: string;
    area_acres?: number;
    ownership_type?: string;
    irrigation_status?: string;
    water_source?: string;
    soil_type?: string;
    season?: string;
    crop_type?: string;
  };
  zones?: AssistantContextZone[];
  active_alerts?: AssistantContextAlert[];
  latest_verification?: {
    action_id?: string;
    zone_id?: string;
    pre_moisture?: number;
    post_moisture?: number;
    moisture_delta?: number;
    summary?: string;
  } | null;
  eligible_schemes?: Array<{
    scheme_id: string;
    title: string;
    category?: string;
    official_url?: string;
  }>;
}

export interface AssistantPendingAction {
  action_type: string;
  zone_id: string;
  duration_seconds?: number;
  volume_liters?: number;
}

export interface AssistantStructuredResponse {
  answer: string;
  intent: AssistantIntent;
  referenced_zone?: string | null;
  severity: 'HIGH' | 'MEDIUM' | 'LOW' | 'NONE';
  evidence?: string | null;
  recommendation?: string | null;
  action_required: boolean;
  action_type: AssistantActionType;
  requires_confirmation: boolean;
  safety_level: AssistantSafetyLevel;
  simulation_status: string;
  indicative_disclaimer?: string | null;
  pending_action?: AssistantPendingAction | null;
}

export interface AssistantQueryRequest {
  query: string;
  language?: 'en' | 'hi' | 'mr' | 'pa';
  session_id?: string;
  context?: Partial<FarmerAssistantContext>;
  user_id?: string;
}

