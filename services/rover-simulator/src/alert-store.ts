/**
 * PRAHAR Alert Store & Audit Repository
 * Implements 24-hour deduplication and expert action audit trails behind a clean interface.
 * Aligned with Requirements 4 & 5.
 */

import { Alert, AlertStatus, DECISION_THRESHOLDS, ExpertAuditRecord } from '@prahar/shared';

export interface IAlertStore {
  saveAlert(alert: Alert): Promise<Alert> | Alert;
  updateAlert(alert: Alert): Promise<Alert> | Alert;
  findActiveAlertByDeduplicationKey(
    key: string,
    windowMs?: number
  ): Promise<Alert | null> | (Alert | null);
  getAlerts(filters?: { zone_id?: string; status?: AlertStatus }): Promise<Alert[]> | Alert[];
  getAlertById(alertId: string): Promise<Alert | null> | (Alert | null);
  recordAudit(record: ExpertAuditRecord): Promise<void> | void;
  getAuditHistory(filters?: { alert_id?: string; zone_id?: string }): Promise<ExpertAuditRecord[]> | ExpertAuditRecord[];
  clear(): void;
}

export class InMemoryAlertStore implements IAlertStore {
  private alerts: Map<string, Alert> = new Map();
  private auditRecords: ExpertAuditRecord[] = [];

  public saveAlert(alert: Alert): Alert {
    this.alerts.set(alert.alert_id, { ...alert });
    return alert;
  }

  public updateAlert(alert: Alert): Alert {
    this.alerts.set(alert.alert_id, { ...alert });
    return alert;
  }

  /**
   * Finds an existing active alert matching the deduplication key within the time window.
   * Format of key: `${zone_id}:${hazard_type}`
   */
  public findActiveAlertByDeduplicationKey(
    key: string,
    windowMs: number = DECISION_THRESHOLDS.ALERT_DEDUPLICATION_WINDOW_MS
  ): Alert | null {
    const now = Date.now();
    for (const alert of this.alerts.values()) {
      if (alert.deduplication_key === key && alert.status !== 'RESOLVED' && alert.status !== 'DISMISSED') {
        const alertTime = new Date(alert.last_occurrence_at || alert.timestamp).getTime();
        if (now - alertTime <= windowMs) {
          return alert;
        }
      }
    }
    return null;
  }

  public getAlerts(filters?: { zone_id?: string; status?: AlertStatus }): Alert[] {
    let result = Array.from(this.alerts.values());
    if (filters?.zone_id) {
      result = result.filter((a) => a.zone_id === filters.zone_id);
    }
    if (filters?.status) {
      result = result.filter((a) => a.status === filters.status);
    }
    // Sort descending by timestamp
    return result.sort(
      (a, b) => new Date(b.last_occurrence_at || b.timestamp).getTime() - new Date(a.last_occurrence_at || a.timestamp).getTime()
    );
  }

  public getAlertById(alertId: string): Alert | null {
    const alert = this.alerts.get(alertId);
    return alert ? { ...alert } : null;
  }

  public recordAudit(record: ExpertAuditRecord): void {
    this.auditRecords.push({ ...record });
  }

  public getAuditHistory(filters?: { alert_id?: string; zone_id?: string }): ExpertAuditRecord[] {
    let records = [...this.auditRecords];
    if (filters?.alert_id) {
      records = records.filter((r) => r.alert_id === filters.alert_id);
    }
    if (filters?.zone_id) {
      records = records.filter((r) => r.zone_id === filters.zone_id);
    }
    return records.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
  }

  public clear(): void {
    this.alerts.clear();
    this.auditRecords = [];
  }
}
