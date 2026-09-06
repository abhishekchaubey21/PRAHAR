/**
 * PRAHAR Real-Data Field Health & Historical Analytics Service
 * Aligned with Phase 6B-2 Specifications:
 * - Backed by authoritative PostgreSQL / Supabase under strict multi-tenant RLS
 * - ZERO synthetic / demo analytics data in production / live mode
 * - Deterministic PRAHAR Field-Health & Risk Summary (no invented ML health scores, no yield predictions)
 * - Bounded time-series sensor trends and detection risk aggregation
 * - Real closed-loop remediation action and verification history
 */

import { SupabaseClient } from '@supabase/supabase-js';
import {
  FarmAnalyticsSummary,
  ZoneHealthSummary,
  FieldHealthStatus,
  LatestSensorMetrics,
  AnalyticsTrendsResponse,
  SensorTrendPoint,
  HazardTrendItem,
  AnalyticsInterventionsResponse,
  InterventionHistoryItem,
} from '@prahar/shared';
import { isSupabaseConfigured, getServiceRoleClient } from './supabase-client.js';

export class AnalyticsService {
  /**
   * Generates a deterministic Field-Health & Risk Summary for a farm and its zones.
   */
  public async getSummary(
    farmId: string,
    zoneId?: string,
    client?: SupabaseClient
  ): Promise<FarmAnalyticsSummary> {
    if (!farmId) throw new Error('[AnalyticsService] farm_id is required.');

    if (isSupabaseConfigured() || client) {
      const activeClient = client || getServiceRoleClient();

      // 1. Fetch Farm (RLS checks tenant ownership)
      const { data: farm, error: farmErr } = await activeClient
        .from('farms')
        .select('id, name, crop_type, area_acres')
        .eq('id', farmId)
        .maybeSingle();

      if (farmErr) {
        throw new Error(`[AnalyticsService] Error fetching farm: ${farmErr.message}`);
      }
      if (!farm) {
        throw new Error(`[AnalyticsService] Farm '${farmId}' not found or access denied.`);
      }

      // 2. Fetch Zones for Farm
      let zoneQuery = activeClient.from('zones').select('*').eq('farm_id', farmId);
      if (zoneId) {
        zoneQuery = zoneQuery.eq('id', zoneId);
      }
      const { data: zones, error: zonesErr } = await zoneQuery;
      if (zonesErr) {
        throw new Error(`[AnalyticsService] Error fetching zones: ${zonesErr.message}`);
      }
      if (!zones || zones.length === 0) {
        if (zoneId) {
          throw new Error(`[AnalyticsService] Zone '${zoneId}' not found or access denied.`);
        }
      }

      const zoneIds = (zones || []).map((z: any) => z.id);

      // 3. Fetch latest sensor readings for these zones
      let sensorReadingsByZone = new Map<string, LatestSensorMetrics>();
      if (zoneIds.length > 0) {
        const { data: readings, error: readErr } = await activeClient
          .from('sensor_readings')
          .select('zone_id, type, value, recorded_at')
          .in('zone_id', zoneIds)
          .order('recorded_at', { ascending: false })
          .limit(200);

        if (!readErr && readings) {
          for (const r of readings) {
            const metrics = sensorReadingsByZone.get(r.zone_id) || {};
            if (r.type === 'moisture' && metrics.moisture_pct === undefined) {
              metrics.moisture_pct = Number(r.value);
              metrics.last_recorded_at = r.recorded_at;
            } else if (r.type === 'temperature' && metrics.temperature_c === undefined) {
              metrics.temperature_c = Number(r.value);
            } else if (r.type === 'humidity' && metrics.humidity_pct === undefined) {
              metrics.humidity_pct = Number(r.value);
            } else if (r.type === 'ph' && metrics.ph === undefined) {
              metrics.ph = Number(r.value);
            }
            sensorReadingsByZone.set(r.zone_id, metrics);
          }
        }
      }

      // 4. Fetch active alerts for these zones
      let activeAlertsCountByZone = new Map<string, number>();
      let maxAlertSeverityByZone = new Map<string, string>();
      if (zoneIds.length > 0) {
        const { data: alerts, error: alertErr } = await activeClient
          .from('alerts')
          .select('zone_id, severity, status')
          .in('zone_id', zoneIds)
          .in('status', ['NEW', 'ACKNOWLEDGED']);

        if (!alertErr && alerts) {
          for (const a of alerts) {
            const count = (activeAlertsCountByZone.get(a.zone_id) || 0) + 1;
            activeAlertsCountByZone.set(a.zone_id, count);

            const currSev = maxAlertSeverityByZone.get(a.zone_id);
            if (a.severity === 'CRITICAL' || currSev === 'CRITICAL') {
              maxAlertSeverityByZone.set(a.zone_id, 'CRITICAL');
            } else if (a.severity === 'HIGH' || currSev === 'HIGH') {
              maxAlertSeverityByZone.set(a.zone_id, 'HIGH');
            } else if (a.severity === 'MEDIUM' && (!currSev || currSev === 'LOW')) {
              maxAlertSeverityByZone.set(a.zone_id, 'MEDIUM');
            } else if (!currSev) {
              maxAlertSeverityByZone.set(a.zone_id, a.severity);
            }
          }
        }
      }

      // 5. Fetch recent detections count
      let recentDetectionsCountByZone = new Map<string, number>();
      if (zoneIds.length > 0) {
        const { data: detections, error: detErr } = await activeClient
          .from('detections')
          .select('zone_id')
          .in('zone_id', zoneIds)
          .limit(100);

        if (!detErr && detections) {
          for (const d of detections) {
            const count = (recentDetectionsCountByZone.get(d.zone_id) || 0) + 1;
            recentDetectionsCountByZone.set(d.zone_id, count);
          }
        }
      }

      // 6. Build ZoneHealthSummary for each zone
      const now = new Date().toISOString();
      let totalActiveAlerts = 0;


      const zoneSummaries: ZoneHealthSummary[] = (zones || []).map((z: any) => {
        const metrics = sensorReadingsByZone.get(z.id) || {};
        const alertCount = activeAlertsCountByZone.get(z.id) || 0;
        const worstAlertSev = maxAlertSeverityByZone.get(z.id);
        const detCount = recentDetectionsCountByZone.get(z.id) || 0;

        totalActiveAlerts += alertCount;

        // Deterministic Field Health Status Calculation
        let status: FieldHealthStatus = 'OPTIMAL';
        let summaryEn = 'Field telemetry and vegetative conditions within normal operational thresholds.';
        let summaryHi = 'खेत की टेलीमेट्री और फसल की स्थिति सामान्य परिचालन सीमा में है।';

        if (worstAlertSev === 'CRITICAL' || (metrics.moisture_pct !== undefined && metrics.moisture_pct !== null && metrics.moisture_pct < 18.0)) {
          status = 'CRITICAL';
          summaryEn = `Critical condition: Severe moisture depletion (${metrics.moisture_pct ?? 'low'}%) or active critical alert detected. Immediate action required.`;
          summaryHi = `गंभीर स्थिति: मिट्टी में नमी की अत्यधिक कमी (${metrics.moisture_pct ?? 'कम'}%) या गंभीर अलर्ट दर्ज। तत्काल कार्रवाई आवश्यक।`;
        } else if (worstAlertSev === 'HIGH' || worstAlertSev === 'MEDIUM' || (metrics.moisture_pct !== undefined && metrics.moisture_pct !== null && metrics.moisture_pct < 25.0) || alertCount > 0) {
          status = 'ATTENTION_REQUIRED';
          summaryEn = `Attention required: Elevated stress or active agronomic alert detected (${alertCount} active alerts).`;
          summaryHi = `ध्यान आवश्यक: बढ़ा हुआ तनाव या सक्रिय कृषि अलर्ट पाया गया (${alertCount} सक्रिय अलर्ट)।`;
        }

        return {
          zone_id: z.id,
          zone_name: z.zone_name,
          farm_id: farmId,
          soil_type: z.soil_type || 'Loam',
          health_status: status,
          health_label: 'PRAHAR Field-Health & Risk Summary',
          summary_en: summaryEn,
          summary_hi: summaryHi,
          latest_metrics: {
            moisture_pct: metrics.moisture_pct ?? null,
            temperature_c: metrics.temperature_c ?? null,
            humidity_pct: metrics.humidity_pct ?? null,
            ph: metrics.ph ?? null,
            last_recorded_at: metrics.last_recorded_at ?? null,
          },
          active_alerts_count: alertCount,
          recent_hazard_count: detCount,
          last_scan_at: z.last_scan_at || null,
          evaluated_at: now,
        };
      });

      let farmWorstStatus: FieldHealthStatus = 'OPTIMAL';
      for (const zs of zoneSummaries) {
        if (zs.health_status === 'CRITICAL') {
          farmWorstStatus = 'CRITICAL';
          break;
        } else if (zs.health_status === 'ATTENTION_REQUIRED') {
          farmWorstStatus = 'ATTENTION_REQUIRED';
        }
      }

      let overallSummaryEn = 'All monitored zones operating within baseline parameters.';
      let overallSummaryHi = 'सभी निगरानी वाले ज़ोन सामान्य मापदंडों के भीतर काम कर रहे हैं।';
      if (farmWorstStatus === 'CRITICAL') {
        overallSummaryEn = 'One or more zones exhibit critical water or pest stress requiring immediate intervention.';
        overallSummaryHi = 'एक या अधिक ज़ोन में पानी या कीट का गंभीर तनाव है जिस पर तत्काल ध्यान देने की आवश्यकता है।';
      } else if (farmWorstStatus === 'ATTENTION_REQUIRED') {
        overallSummaryEn = 'Monitored zones show elevated stress or active alerts under observation.';
        overallSummaryHi = 'निगरानी वाले ज़ोन में तनाव या सक्रिय अलर्ट देखे गए हैं।';
      }


      return {
        farm_id: farm.id,
        farm_name: farm.name,
        total_zones: zoneSummaries.length,
        overall_status: farmWorstStatus,
        health_label: 'PRAHAR Field-Health & Risk Summary',
        summary_en: overallSummaryEn,
        summary_hi: overallSummaryHi,
        active_alerts_count: totalActiveAlerts,
        zones: zoneSummaries,
        evaluated_at: now,
      };
    }

    // Pure Offline Mock / Test fallback (Supabase not configured)
    const now = new Date().toISOString();
    return {
      farm_id: farmId,
      farm_name: 'Offline Farm',
      total_zones: 1,
      overall_status: 'OPTIMAL',
      health_label: 'PRAHAR Field-Health & Risk Summary',
      summary_en: 'Operating in local offline mode.',
      summary_hi: 'स्थानीय ऑफ़लाइन मोड में चल रहा है।',
      active_alerts_count: 0,
      zones: [
        {
          zone_id: zoneId || 'ZONE-OFFLINE-01',
          zone_name: 'Zone Offline 1',
          farm_id: farmId,
          soil_type: 'Loam',
          health_status: 'OPTIMAL',
          health_label: 'PRAHAR Field-Health & Risk Summary',
          summary_en: 'Offline zone baseline optimal.',
          summary_hi: 'ऑफ़लाइन ज़ोन सामान्य है।',
          latest_metrics: {
            moisture_pct: 28.5,
            temperature_c: 30.0,
            humidity_pct: 55.0,
            ph: 6.5,
            last_recorded_at: now,
          },
          active_alerts_count: 0,
          recent_hazard_count: 0,
          last_scan_at: now,
          evaluated_at: now,
        },
      ],
      evaluated_at: now,
    };
  }

  /**
   * Retrieves historical time-series sensor trends and detection risk aggregation for a zone.
   */
  public async getTrends(
    zoneId: string,
    options: { from?: string; to?: string; limit?: number } = {},
    client?: SupabaseClient
  ): Promise<AnalyticsTrendsResponse> {
    if (!zoneId) throw new Error('[AnalyticsService] zone_id is required.');

    const now = new Date().toISOString();

    if (isSupabaseConfigured() || client) {
      const activeClient = client || getServiceRoleClient();

      // 1. Verify zone access under RLS
      const { data: zone, error: zoneErr } = await activeClient
        .from('zones')
        .select('id, zone_name, farm_id')
        .eq('id', zoneId)
        .maybeSingle();

      if (zoneErr) {
        throw new Error(`[AnalyticsService] Error fetching zone: ${zoneErr.message}`);
      }
      if (!zone) {
        throw new Error(`[AnalyticsService] Zone '${zoneId}' not found or access denied.`);
      }

      // 2. Fetch sensor readings bounded by date range
      let readQuery = activeClient
        .from('sensor_readings')
        .select('type, value, recorded_at')
        .eq('zone_id', zoneId);

      if (options.from) {
        readQuery = readQuery.gte('recorded_at', options.from);
      }
      if (options.to) {
        readQuery = readQuery.lte('recorded_at', options.to);
      }

      const limit = Math.min(options.limit || 100, 200);
      readQuery = readQuery.order('recorded_at', { ascending: true }).limit(limit);

      const { data: readings, error: readErr } = await readQuery;
      if (readErr) {
        throw new Error(`[AnalyticsService] Error fetching sensor trends: ${readErr.message}`);
      }

      // 3. Bin readings by timestamp or chronological sequence
      const trendPointsMap = new Map<string, SensorTrendPoint>();
      if (readings) {
        for (const r of readings) {
          // Truncate to minute for grouping if simultaneous
          const tsKey = new Date(r.recorded_at).toISOString();
          const point = trendPointsMap.get(tsKey) || { timestamp: tsKey };

          if (r.type === 'moisture') point.moisture_pct = Number(r.value);
          else if (r.type === 'temperature') point.temperature_c = Number(r.value);
          else if (r.type === 'humidity') point.humidity_pct = Number(r.value);
          else if (r.type === 'ph') point.ph = Number(r.value);

          trendPointsMap.set(tsKey, point);
        }
      }

      const sensorTrends = Array.from(trendPointsMap.values()).sort(
        (a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
      );

      // 4. Fetch detections bounded by date range
      let detQuery = activeClient
        .from('detections')
        .select('hazard_type, hazard_name, confidence, severity_hint, recorded_at')
        .eq('zone_id', zoneId);

      if (options.from) {
        detQuery = detQuery.gte('recorded_at', options.from);
      }
      if (options.to) {
        detQuery = detQuery.lte('recorded_at', options.to);
      }

      detQuery = detQuery.order('recorded_at', { ascending: false }).limit(limit);

      const { data: detections, error: detErr } = await detQuery;
      if (detErr) {
        throw new Error(`[AnalyticsService] Error fetching hazard trends: ${detErr.message}`);
      }

      // Aggregate detections by hazard_type
      const hazardMap = new Map<string, HazardTrendItem>();
      if (detections) {
        for (const d of detections) {
          const existing = hazardMap.get(d.hazard_type);
          if (existing) {
            existing.occurrence_count += 1;
            if (
              d.severity_hint === 'CRITICAL' ||
              (d.severity_hint === 'HIGH' && existing.highest_severity !== 'CRITICAL') ||
              (d.severity_hint === 'MEDIUM' && existing.highest_severity === 'LOW')
            ) {
              existing.highest_severity = d.severity_hint;
            }
          } else {
            hazardMap.set(d.hazard_type, {
              hazard_type: d.hazard_type,
              hazard_name: d.hazard_name || d.hazard_type,
              highest_severity: d.severity_hint,
              occurrence_count: 1,
              latest_recorded_at: d.recorded_at,
              latest_confidence: Number(d.confidence || 0.8),
            });
          }
        }
      }

      const hazardBreakdown = Array.from(hazardMap.values());
      const hasSufficientData = sensorTrends.length > 0 || hazardBreakdown.length > 0;

      return {
        zone_id: zoneId,
        zone_name: zone.zone_name,
        from: options.from,
        to: options.to,
        has_sufficient_data: hasSufficientData,
        sensor_trends: sensorTrends,
        hazard_breakdown: hazardBreakdown,
        evaluated_at: now,
      };
    }

    // Pure Offline Mock
    return {
      zone_id: zoneId,
      zone_name: 'Zone Offline',
      from: options.from,
      to: options.to,
      has_sufficient_data: false,
      sensor_trends: [],
      hazard_breakdown: [],
      evaluated_at: now,
    };
  }

  /**
   * Retrieves closed-loop remediation actions and verification history.
   */
  public async getInterventions(
    options: { farmId?: string; zoneId?: string; limit?: number } = {},
    client?: SupabaseClient
  ): Promise<AnalyticsInterventionsResponse> {
    const now = new Date().toISOString();

    if (isSupabaseConfigured() || client) {
      const activeClient = client || getServiceRoleClient();

      let actionQuery = activeClient.from('remediation_actions').select('*');

      if (options.zoneId) {
        actionQuery = actionQuery.eq('zone_id', options.zoneId);
      } else if (options.farmId) {
        // Find zones for farm
        const { data: zones, error: zErr } = await activeClient
          .from('zones')
          .select('id')
          .eq('farm_id', options.farmId);
        if (zErr) {
          throw new Error(`[AnalyticsService] Error resolving farm zones: ${zErr.message}`);
        }
        const zoneIds = (zones || []).map((z: any) => z.id);
        if (zoneIds.length === 0) {
          return {
            farm_id: options.farmId,
            zone_id: options.zoneId,
            total_count: 0,
            interventions: [],
            evaluated_at: now,
          };
        }
        actionQuery = actionQuery.in('zone_id', zoneIds);
      }

      const limit = Math.min(options.limit || 50, 100);
      actionQuery = actionQuery.order('created_at', { ascending: false }).limit(limit);

      const { data: actions, error: actErr } = await actionQuery;
      if (actErr) {
        throw new Error(`[AnalyticsService] Error fetching remediation actions: ${actErr.message}`);
      }

      const actionIds = (actions || []).map((a: any) => a.action_id);
      const verificationsMap = new Map<string, any>();

      if (actionIds.length > 0) {
        const { data: verifs, error: verifErr } = await activeClient
          .from('remediation_verifications')
          .select('*')
          .in('action_id', actionIds);

        if (!verifErr && verifs) {
          for (const v of verifs) {
            verificationsMap.set(v.action_id, v);
          }
        }
      }

      const items: InterventionHistoryItem[] = (actions || []).map((a: any) => {
        const v = verificationsMap.get(a.action_id);
        return {
          action_id: a.action_id,
          zone_id: a.zone_id,
          action_type: a.action_type,
          duration_seconds: a.duration_seconds,
          volume_liters: Number(a.volume_liters),
          approved_by: a.approved_by,
          approved_at: a.approved_at,
          status: a.status,
          expert_note: a.expert_note || null,
          created_at: a.created_at,
          verification: v
            ? {
                verification_id: v.verification_id,
                pre_moisture: Number(v.pre_moisture),
                post_moisture: Number(v.post_moisture),
                moisture_delta: Number(v.moisture_delta),
                resolved: Boolean(v.resolved),
                verification_timestamp: v.verification_timestamp,
                summary_en: v.summary_en,
                summary_hi: v.summary_hi,
              }
            : null,
        };
      });

      return {
        farm_id: options.farmId,
        zone_id: options.zoneId,
        total_count: items.length,
        interventions: items,
        evaluated_at: now,
      };
    }

    // Offline mock
    return {
      farm_id: options.farmId,
      zone_id: options.zoneId,
      total_count: 0,
      interventions: [],
      evaluated_at: now,
    };
  }
}
