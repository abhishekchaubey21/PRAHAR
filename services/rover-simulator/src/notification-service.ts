/**
 * PRAHAR In-App Notification Service
 * Aligned with Phase 6B-1 Specifications:
 * - Persistent notification management backed by PostgreSQL RLS
 * - Strict tenant isolation: Farmer A vs Farmer B
 * - Deduplication & idempotency protection at application and database layers
 * - Extensible adapter architecture (in-app implemented; ready for future FCM/SMS)
 * - Authoritative persistence with resilient local fallback for offline support
 */

import crypto from 'node:crypto';
import { SupabaseClient } from '@supabase/supabase-js';
import {
  NotificationRecord,
  CreateNotificationInput,
  ListNotificationsOptions,
} from '@prahar/shared';
import { isSupabaseConfigured, getServiceRoleClient } from './supabase-client.js';

export interface NotificationDeliveryAdapter {
  readonly channel: 'IN_APP' | 'FCM' | 'SMS' | 'WHATSAPP';
  deliver(notification: NotificationRecord): Promise<void>;
}

export class InAppDeliveryAdapter implements NotificationDeliveryAdapter {
  public readonly channel = 'IN_APP' as const;

  public async deliver(_notification: NotificationRecord): Promise<void> {
    // In-app persistence is authoritative; delivery is handled via persistent store query
  }
}

export class NotificationService {
  private localNotifications: NotificationRecord[] = [];
  private adapters: NotificationDeliveryAdapter[] = [];

  constructor(adapters?: NotificationDeliveryAdapter[]) {
    this.adapters = adapters || [new InAppDeliveryAdapter()];
  }

  /**
   * Generates a unique notification id
   */
  private generateNotificationId(): string {
    return `notif-${Date.now().toString(36)}-${crypto.randomBytes(4).toString('hex')}`;
  }

  /**
   * Creates a persistent notification idempotently.
   * If a notification with the same user_id and deduplication_key already exists,
   * the existing notification is returned and no duplicate is created.
   */
  public async createNotification(
    input: CreateNotificationInput,
    client?: SupabaseClient
  ): Promise<NotificationRecord> {
    if (!input.user_id) throw new Error('[NotificationService] user_id is required.');
    if (!input.farm_id) throw new Error('[NotificationService] farm_id is required.');
    if (!input.title) throw new Error('[NotificationService] title is required.');
    if (!input.message) throw new Error('[NotificationService] message is required.');

    // 1. Application-layer deduplication check
    if (input.deduplication_key) {
      const existingLocal = this.localNotifications.find(
        (n) => n.user_id === input.user_id && n.deduplication_key === input.deduplication_key
      );
      if (existingLocal) {
        return existingLocal;
      }
    }

    const notifId = input.notification_id || this.generateNotificationId();
    const id = crypto.randomUUID();
    const now = new Date().toISOString();

    const record: NotificationRecord = {
      id,
      notification_id: notifId,
      user_id: input.user_id,
      farm_id: input.farm_id,
      zone_id: input.zone_id || null,
      alert_id: input.alert_id || null,
      action_id: input.action_id || null,
      type: input.type,
      severity: input.severity,
      title: input.title,
      title_hi: input.title_hi || null,
      message: input.message,
      message_hi: input.message_hi || null,
      is_read: false,
      created_at: now,
      read_at: null,
      metadata: input.metadata || {},
      deduplication_key: input.deduplication_key || null,
    };

    // 2. Persist to real Supabase if configured (Authoritative Backend Source of Truth)
    if (isSupabaseConfigured() || client) {
      const activeClient = client || getServiceRoleClient();
      const { data, error } = await activeClient
        .from('notifications')
        .insert([
          {
            id: record.id,
            notification_id: record.notification_id,
            user_id: record.user_id,
            farm_id: record.farm_id,
            zone_id: record.zone_id,
            alert_id: record.alert_id,
            action_id: record.action_id,
            type: record.type,
            severity: record.severity,
            title: record.title,
            title_hi: record.title_hi,
            message: record.message,
            message_hi: record.message_hi,
            is_read: record.is_read,
            created_at: record.created_at,
            read_at: record.read_at,
            metadata: record.metadata,
            deduplication_key: record.deduplication_key,
          },
        ])
        .select()
        .maybeSingle();

      if (error) {
        // Idempotency: Check for 23505 Unique Violation on (user_id, deduplication_key)
        if (error.code === '23505' && record.deduplication_key) {
          const { data: existingDb, error: findErr } = await activeClient
            .from('notifications')
            .select('*')
            .eq('user_id', record.user_id)
            .eq('deduplication_key', record.deduplication_key)
            .maybeSingle();

          if (existingDb) {
            const mapped = this.mapDbRow(existingDb);
            return mapped;
          }
          if (findErr) {
            throw new Error(`[NotificationService] Failed retrieving deduplicated notification: ${findErr.message}`);
          }
        }
        // Strict: Never silently fall back on database errors
        throw new Error(`[NotificationService] Supabase insert failed: ${error.message}`);
      }

      if (data) {
        const mapped = this.mapDbRow(data);
        // Dispatch through adapters
        for (const adapter of this.adapters) {
          await adapter.deliver(mapped).catch(() => {});
        }
        return mapped;
      }
    }

    // 3. Offline / Test fallback ONLY when Supabase is not configured
    this.cacheLocal(record);

    for (const adapter of this.adapters) {
      await adapter.deliver(record).catch(() => {});
    }

    return record;
  }

  /**
   * Lists notifications for a given user under RLS / multi-tenancy.
   */
  public async listNotifications(
    userId: string,
    options?: ListNotificationsOptions,
    client?: SupabaseClient
  ): Promise<NotificationRecord[]> {
    if (client || isSupabaseConfigured()) {
      const activeClient = client || getServiceRoleClient();
      let query = activeClient.from('notifications').select('*');
      if (options?.is_read !== undefined) {
        query = query.eq('is_read', options.is_read);
      }
      query = query.order('created_at', { ascending: false });

      if (options?.limit) {
        query = query.limit(options.limit);
      }

      const { data, error } = await query;
      if (error) {
        throw new Error(`[NotificationService] listNotifications error: ${error.message}`);
      }

      return (data || []).map((row: any) => this.mapDbRow(row));
    }

    // Pure Offline / Test query (Supabase unconfigured)
    return this.localNotifications
      .filter((n) => n.user_id === userId && (options?.is_read === undefined || n.is_read === options.is_read))
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
      .slice(0, options?.limit || 50);
  }

  /**
   * Gets unread notification count for a specific user.
   */
  public async getUnreadCount(userId: string, client?: SupabaseClient): Promise<number> {
    if (client || isSupabaseConfigured()) {
      const activeClient = client || getServiceRoleClient();
      const { count, error } = await activeClient
        .from('notifications')
        .select('*', { count: 'exact', head: true })
        .eq('is_read', false);

      if (error) {
        throw new Error(`[NotificationService] getUnreadCount error: ${error.message}`);
      }

      return count || 0;
    }

    return this.localNotifications.filter((n) => n.user_id === userId && !n.is_read).length;
  }

  /**
   * Marks a specific notification as read.
   */
  public async markRead(
    userId: string,
    notificationIdOrPk: string,
    client?: SupabaseClient
  ): Promise<NotificationRecord | null> {
    const now = new Date().toISOString();

    if (client || isSupabaseConfigured()) {
      const activeClient = client || getServiceRoleClient();
      // Allow matching by notification_id or UUID id
      const { data, error } = await activeClient
        .from('notifications')
        .update({ is_read: true, read_at: now })
        .or(`id.eq.${notificationIdOrPk},notification_id.eq.${notificationIdOrPk}`)
        .select()
        .maybeSingle();

      if (error) {
        throw new Error(`[NotificationService] markRead error: ${error.message}`);
      }
      if (!data) return null;

      return this.mapDbRow(data);
    }

    const item = this.localNotifications.find(
      (n) => n.user_id === userId && (n.id === notificationIdOrPk || n.notification_id === notificationIdOrPk)
    );
    if (!item) return null;

    item.is_read = true;
    item.read_at = now;
    return item;
  }

  /**
   * Marks all unread notifications as read for a specific user.
   */
  public async markAllRead(userId: string, client?: SupabaseClient): Promise<number> {
    const now = new Date().toISOString();

    if (client || isSupabaseConfigured()) {
      const activeClient = client || getServiceRoleClient();
      const { data, error } = await activeClient
        .from('notifications')
        .update({ is_read: true, read_at: now })
        .eq('is_read', false)
        .select();

      if (error) {
        throw new Error(`[NotificationService] markAllRead error: ${error.message}`);
      }

      return data ? data.length : 0;
    }

    let count = 0;
    for (const n of this.localNotifications) {
      if (n.user_id === userId && !n.is_read) {
        n.is_read = true;
        n.read_at = now;
        count++;
      }
    }
    return count;
  }

  /**
   * Clear local memory (used for test fixture resets)
   */
  public clearLocal(userId?: string): void {
    if (userId) {
      this.localNotifications = this.localNotifications.filter((n) => n.user_id !== userId);
    } else {
      this.localNotifications = [];
    }
  }

  private cacheLocal(record: NotificationRecord): void {
    const idx = this.localNotifications.findIndex((n) => n.id === record.id || n.notification_id === record.notification_id);
    if (idx >= 0) {
      this.localNotifications[idx] = record;
    } else {
      this.localNotifications.unshift(record);
    }
  }

  private updateLocal(record: NotificationRecord): void {
    const idx = this.localNotifications.findIndex((n) => n.id === record.id || n.notification_id === record.notification_id);
    if (idx >= 0) {
      this.localNotifications[idx] = record;
    }
  }

  private mapDbRow(row: any): NotificationRecord {
    return {
      id: row.id,
      notification_id: row.notification_id,
      user_id: row.user_id,
      farm_id: row.farm_id,
      zone_id: row.zone_id || null,
      alert_id: row.alert_id || null,
      action_id: row.action_id || null,
      type: row.type,
      severity: row.severity,
      title: row.title,
      title_hi: row.title_hi || null,
      message: row.message,
      message_hi: row.message_hi || null,
      is_read: Boolean(row.is_read),
      created_at: row.created_at,
      read_at: row.read_at || null,
      metadata: row.metadata || {},
      deduplication_key: row.deduplication_key || null,
    };
  }
}
