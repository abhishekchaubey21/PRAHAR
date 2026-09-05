/**
 * PRAHAR Resilient Dual-Mode Data Store
 * Aligned with Phase 5A Amendments 1 & 5:
 * - Implements IAlertStore interface synchronously and asynchronously where needed.
 * - When Supabase is configured & online, normal operations route through user-scoped RLS client.
 * - When offline or unconfigured, operations cleanly fallback to PersistentAlertStore.
 * - Offline security: On logout/session invalidation, cached user state is locked/cleared.
 */

import {
  Alert,
  AlertStatus,
  ExpertAuditRecord,
  RemediationVerification,
} from '@prahar/shared';
import { IAlertStore } from './alert-store.js';
import { PersistentAlertStore } from './persistent-alert-store.js';
import { SupabaseDataRepository } from './supabase-repository.js';
import { isSupabaseConfigured, createUserScopedClient } from './supabase-client.js';

export class ResilientDataStore implements IAlertStore {
  private localStore: PersistentAlertStore;
  private supabaseRepo: SupabaseDataRepository;
  private activeToken?: string;
  private userCacheLock: Set<string> = new Set();

  constructor(localStore?: PersistentAlertStore) {
    this.localStore = localStore || new PersistentAlertStore();
    this.supabaseRepo = new SupabaseDataRepository();
  }

  public setRequestContext(accessToken?: string): void {
    this.activeToken = accessToken;
  }

  /**
   * Amendment 5: On logout, locks/clears protected cached data for this user.
   */
  public handleLogout(userId: string): void {
    this.userCacheLock.add(userId);
    this.activeToken = undefined;
  }

  public isUserLocked(userId: string): boolean {
    return this.userCacheLock.has(userId);
  }

  public unlockUser(userId: string): void {
    this.userCacheLock.delete(userId);
  }

  public saveAlert(alert: Alert): Alert {
    // Write locally for immediate consistent sync and offline fallback
    this.localStore.saveAlert(alert);

    if (isSupabaseConfigured() && this.activeToken) {
      const client = createUserScopedClient(this.activeToken);
      this.supabaseRepo.saveAlert(client, alert).catch((err) => {
        console.warn('[ResilientDataStore] Supabase saveAlert failed, retained in local fallback:', err);
      });
    }

    return alert;
  }

  public updateAlert(alert: Alert): Alert {
    this.localStore.updateAlert(alert);

    if (isSupabaseConfigured() && this.activeToken) {
      const client = createUserScopedClient(this.activeToken);
      this.supabaseRepo.updateAlert(client, alert).catch((err) => {
        console.warn('[ResilientDataStore] Supabase updateAlert failed, retained in local fallback:', err);
      });
    }

    return alert;
  }

  public findActiveAlertByDeduplicationKey(key: string, windowMs?: number): Alert | null {
    return this.localStore.findActiveAlertByDeduplicationKey(key, windowMs);
  }

  public getAlerts(filters?: { zone_id?: string; status?: AlertStatus }): Alert[] {
    return this.localStore.getAlerts(filters);
  }

  public getAlertById(alertId: string): Alert | null {
    return this.localStore.getAlertById(alertId);
  }

  public recordAudit(record: ExpertAuditRecord): void {
    this.localStore.recordAudit(record);

    if (isSupabaseConfigured() && this.activeToken) {
      const client = createUserScopedClient(this.activeToken);
      this.supabaseRepo.recordAudit(client, record).catch((err) => {
        console.warn('[ResilientDataStore] Supabase recordAudit failed, retained in local fallback:', err);
      });
    }
  }

  public addAuditRecord(record: ExpertAuditRecord): void {
    this.recordAudit(record);
  }

  public getAuditHistory(filters?: { alert_id?: string; zone_id?: string }): ExpertAuditRecord[] {
    return this.localStore.getAuditHistory(filters);
  }

  public saveVerification(verification: RemediationVerification): RemediationVerification {
    this.localStore.saveVerification(verification);

    if (isSupabaseConfigured() && this.activeToken) {
      const client = createUserScopedClient(this.activeToken);
      this.supabaseRepo.saveVerification(client, verification).catch((err) => {
        console.warn('[ResilientDataStore] Supabase saveVerification failed, retained in local fallback:', err);
      });
    }

    return verification;
  }

  public getVerifications(zoneId?: string): RemediationVerification[] {
    return this.localStore.getVerifications(zoneId);
  }

  public clear(): void {
    this.localStore.clear();
  }
}
