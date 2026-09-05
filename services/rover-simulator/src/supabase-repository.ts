/**
 * PRAHAR Supabase Data Repository
 * Real PostgreSQL persistence layer implementing domain CRUD operations.
 * ALL functions accept a user-scoped `SupabaseClient` so that PostgreSQL Row-Level
 * Security (RLS) is strictly evaluated per-request by PostgreSQL.
 */

import { SupabaseClient } from '@supabase/supabase-js';
import {
  Alert,
  AlertStatus,
  ExpertAuditRecord,
  RemediationVerification,
} from '@prahar/shared';

export interface RemediationActionRecord {
  action_id: string;
  zone_id: string;
  action_type: string;
  duration_seconds: number;
  volume_liters: number;
  approved_by: string;
  approved_at: string;
  expert_note?: string;
  status: 'APPROVED' | 'EXECUTING' | 'COMPLETED' | 'FAILED';
}

export class SupabaseDataRepository {
  /**
   * Fetch alerts visible to the authenticated user under RLS.
   */
  public async getAlerts(
    client: SupabaseClient,
    filters?: { zone_id?: string; status?: AlertStatus }
  ): Promise<Alert[]> {
    let query = client.from('alerts').select('*');

    if (filters?.zone_id) {
      query = query.eq('zone_id', filters.zone_id);
    }
    if (filters?.status) {
      query = query.eq('status', filters.status);
    }

    query = query.order('created_at', { ascending: false });

    const { data, error } = await query;
    if (error) {
      throw new Error(`[SupabaseDataRepository] getAlerts error: ${error.message}`);
    }

    return (data || []).map((row: any) => ({
      alert_id: row.id,
      zone_id: row.zone_id,
      type: row.type,
      severity: row.severity,
      status: row.status,
      message: row.message,
      message_hi: row.message_hi,
      recommended_action: row.recommended_action,
      recommended_action_hi: row.recommended_action_hi,
      timestamp: row.created_at || row.last_occurrence_at || new Date().toISOString(),
      deduplication_key: row.deduplication_key,
      occurrence_count: row.occurrence_count || 1,
      last_occurrence_at: row.last_occurrence_at || row.created_at,
    }));
  }

  public async getAlertById(client: SupabaseClient, alertId: string): Promise<Alert | null> {
    const { data, error } = await client.from('alerts').select('*').eq('id', alertId).maybeSingle();
    if (error) {
      throw new Error(`[SupabaseDataRepository] getAlertById error: ${error.message}`);
    }
    if (!data) return null;

    return {
      alert_id: data.id,
      zone_id: data.zone_id,
      type: data.type,
      severity: data.severity,
      status: data.status,
      message: data.message,
      message_hi: data.message_hi,
      recommended_action: data.recommended_action,
      recommended_action_hi: data.recommended_action_hi,
      timestamp: data.created_at || data.last_occurrence_at || new Date().toISOString(),
      deduplication_key: data.deduplication_key,
      occurrence_count: data.occurrence_count || 1,
      last_occurrence_at: data.last_occurrence_at || data.created_at,
    };
  }

  public async saveAlert(client: SupabaseClient, alert: Alert): Promise<Alert> {
    const row = {
      id: alert.alert_id,
      zone_id: alert.zone_id,
      type: alert.type,
      severity: alert.severity,
      status: alert.status,
      message: alert.message,
      message_hi: alert.message_hi,
      recommended_action: alert.recommended_action,
      recommended_action_hi: alert.recommended_action_hi,
      deduplication_key: alert.deduplication_key,
      occurrence_count: alert.occurrence_count || 1,
      last_occurrence_at: alert.last_occurrence_at || alert.timestamp || new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { error } = await client.from('alerts').upsert(row, { onConflict: 'id' });
    if (error) {
      throw new Error(`[SupabaseDataRepository] saveAlert error: ${error.message}`);
    }
    return alert;
  }

  public async updateAlert(client: SupabaseClient, alert: Alert): Promise<Alert> {
    const { error } = await client
      .from('alerts')
      .update({
        status: alert.status,
        message: alert.message,
        occurrence_count: alert.occurrence_count,
        last_occurrence_at: alert.last_occurrence_at || alert.timestamp,
        updated_at: new Date().toISOString(),
      })
      .eq('id', alert.alert_id);

    if (error) {
      throw new Error(`[SupabaseDataRepository] updateAlert error: ${error.message}`);
    }
    return alert;
  }

  public async recordAudit(client: SupabaseClient, record: ExpertAuditRecord): Promise<void> {
    const row = {
      audit_id: record.audit_id,
      actor: record.actor,
      timestamp: record.timestamp,
      zone_id: record.zone_id,
      alert_id: record.alert_id,
      action: record.action,
      previous_state: record.previous_state,
      new_state: record.new_state,
      expert_note: record.expert_note,
    };

    const { error } = await client.from('expert_audit_records').insert(row);
    if (error) {
      throw new Error(`[SupabaseDataRepository] recordAudit error: ${error.message}`);
    }
  }

  public async getAuditHistory(
    client: SupabaseClient,
    filters?: { zone_id?: string; alert_id?: string }
  ): Promise<ExpertAuditRecord[]> {
    let query = client.from('expert_audit_records').select('*');
    if (filters?.zone_id) query = query.eq('zone_id', filters.zone_id);
    if (filters?.alert_id) query = query.eq('alert_id', filters.alert_id);
    query = query.order('timestamp', { ascending: false });

    const { data, error } = await query;
    if (error) {
      throw new Error(`[SupabaseDataRepository] getAuditHistory error: ${error.message}`);
    }

    return (data || []).map((r: any) => ({
      audit_id: r.audit_id,
      actor: r.actor,
      timestamp: r.timestamp,
      zone_id: r.zone_id,
      alert_id: r.alert_id,
      action: r.action,
      previous_state: r.previous_state,
      new_state: r.new_state,
      expert_note: r.expert_note,
    }));
  }

  public async saveVerification(
    client: SupabaseClient,
    verification: RemediationVerification
  ): Promise<RemediationVerification> {
    const row = {
      verification_id: verification.verification_id,
      zone_id: verification.zone_id,
      action_id: verification.action_id,
      pre_moisture: verification.pre_moisture,
      post_moisture: verification.post_moisture,
      moisture_delta: verification.moisture_delta,
      pre_detection: verification.pre_detection,
      post_detection: verification.post_detection,
      resolved: verification.resolved,
      verification_timestamp: verification.verification_timestamp,
      summary_en: verification.summary_en,
      summary_hi: verification.summary_hi,
    };

    const { error } = await client.from('remediation_verifications').upsert(row, { onConflict: 'verification_id' });
    if (error) {
      throw new Error(`[SupabaseDataRepository] saveVerification error: ${error.message}`);
    }
    return verification;
  }

  public async getVerifications(
    client: SupabaseClient,
    zoneId?: string
  ): Promise<RemediationVerification[]> {
    let query = client.from('remediation_verifications').select('*');
    if (zoneId) query = query.eq('zone_id', zoneId);
    query = query.order('verification_timestamp', { ascending: false });

    const { data, error } = await query;
    if (error) {
      throw new Error(`[SupabaseDataRepository] getVerifications error: ${error.message}`);
    }

    return (data || []).map((v: any) => ({
      verification_id: v.verification_id,
      zone_id: v.zone_id,
      action_id: v.action_id,
      pre_moisture: Number(v.pre_moisture),
      post_moisture: Number(v.post_moisture),
      moisture_delta: Number(v.moisture_delta),
      pre_detection: v.pre_detection,
      post_detection: v.post_detection,
      resolved: v.resolved,
      verification_timestamp: v.verification_timestamp,
      summary_en: v.summary_en,
      summary_hi: v.summary_hi,
    }));
  }

  public async saveRemediationAction(
    client: SupabaseClient,
    action: RemediationActionRecord
  ): Promise<void> {
    const row = {
      action_id: action.action_id,
      zone_id: action.zone_id,
      action_type: action.action_type,
      duration_seconds: action.duration_seconds,
      volume_liters: action.volume_liters,
      approved_by: action.approved_by,
      approved_at: action.approved_at,
      expert_note: action.expert_note,
      status: action.status,
    };

    const { error } = await client.from('remediation_actions').upsert(row, { onConflict: 'action_id' });
    if (error) {
      throw new Error(`[SupabaseDataRepository] saveRemediationAction error: ${error.message}`);
    }
  }

  public async getRemediationActionById(
    client: SupabaseClient,
    actionId: string
  ): Promise<RemediationActionRecord | undefined> {
    const { data, error } = await client.from('remediation_actions').select('*').eq('action_id', actionId).maybeSingle();
    if (error) {
      throw new Error(`[SupabaseDataRepository] getRemediationActionById error: ${error.message}`);
    }
    if (!data) return undefined;

    return {
      action_id: data.action_id,
      zone_id: data.zone_id,
      action_type: data.action_type,
      duration_seconds: data.duration_seconds,
      volume_liters: Number(data.volume_liters),
      approved_by: data.approved_by,
      approved_at: data.approved_at,
      expert_note: data.expert_note,
      status: data.status,
    };
  }

  public async getFarms(client: SupabaseClient): Promise<any[]> {
    const { data, error } = await client
      .from('farms')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      throw new Error(`[SupabaseDataRepository] getFarms error: ${error.message}`);
    }

    return (data || []).map((f: any) => ({
      id: f.id,
      farmer_id: f.farmer_id,
      name: f.name,
      crop_type: f.crop_type,
      area_acres: Number(f.area_acres),
      created_at: f.created_at,
    }));
  }

  public async getZones(client: SupabaseClient, farmId?: string): Promise<any[]> {
    let query = client.from('zones').select('*');
    if (farmId) {
      query = query.eq('farm_id', farmId);
    }
    query = query.order('created_at', { ascending: false });

    const { data, error } = await query;
    if (error) {
      throw new Error(`[SupabaseDataRepository] getZones error: ${error.message}`);
    }

    return (data || []).map((z: any) => ({
      id: z.id,
      farm_id: z.farm_id,
      name: z.name,
      soil_type: z.soil_type,
      crop_variety: z.crop_variety,
      baseline_moisture_pct: Number(z.baseline_moisture_pct),
      created_at: z.created_at,
    }));
  }
}
