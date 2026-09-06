/**
 * PRAHAR — Core Agricultural Entities (Section 9)
 */

export interface Farmer {
  id: string;
  name: string;
  phone: string;
  language: string;
  created_at: string;
}

export interface Farm {
  id: string;
  farmer_id: string;
  name: string;
  boundary_geojson: Record<string, any>;
  crop_type: string;
  area_acres: number;
  created_at: string;
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
