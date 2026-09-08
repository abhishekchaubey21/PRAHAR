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
  private farmerProfiles: Map<string, any> = new Map();

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

  public async getAlertsAsync(filters?: { zone_id?: string; status?: AlertStatus }): Promise<Alert[]> {
    if (isSupabaseConfigured() && this.activeToken) {
      try {
        const client = createUserScopedClient(this.activeToken);
        return await this.supabaseRepo.getAlerts(client, filters);
      } catch (err: any) {
        if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
          throw err;
        }
        console.warn('[ResilientDataStore] Supabase getAlerts failed, falling back to local store:', err.message);
      }
    }
    return this.localStore.getAlerts(filters);
  }

  public getAlertById(alertId: string): Alert | null {
    return this.localStore.getAlertById(alertId);
  }

  public async getAlertByIdAsync(alertId: string): Promise<Alert | null> {
    if (isSupabaseConfigured() && this.activeToken) {
      try {
        const client = createUserScopedClient(this.activeToken);
        return await this.supabaseRepo.getAlertById(client, alertId);
      } catch (err: any) {
        if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
          throw err;
        }
        console.warn('[ResilientDataStore] Supabase getAlertById failed, falling back to local store:', err.message);
      }
    }
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

  public async getAuditHistoryAsync(filters?: { alert_id?: string; zone_id?: string }): Promise<ExpertAuditRecord[]> {
    if (isSupabaseConfigured() && this.activeToken) {
      try {
        const client = createUserScopedClient(this.activeToken);
        return await this.supabaseRepo.getAuditHistory(client, filters);
      } catch (err: any) {
        if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
          throw err;
        }
        console.warn('[ResilientDataStore] Supabase getAuditHistory failed, falling back to local store:', err.message);
      }
    }
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

  public async getVerificationsAsync(zoneId?: string): Promise<RemediationVerification[]> {
    if (isSupabaseConfigured() && this.activeToken) {
      try {
        const client = createUserScopedClient(this.activeToken);
        return await this.supabaseRepo.getVerifications(client, zoneId);
      } catch (err: any) {
        if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
          throw err;
        }
        console.warn('[ResilientDataStore] Supabase getVerifications failed, falling back to local store:', err.message);
      }
    }
    return this.localStore.getVerifications(zoneId);
  }

  public getSupabaseRepo(): SupabaseDataRepository {
    return this.supabaseRepo;
  }

  public getFarmerProfile(userId: string): any | undefined {
    return this.farmerProfiles.get(userId);
  }

  public saveFarmerProfile(userId: string, profile: any): void {
    this.farmerProfiles.set(userId, profile);
  }

  public clear(): void {
    this.farmerProfiles.clear();
    this.localStore.clear();
  }
}
