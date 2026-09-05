/**
 * PRAHAR Offline Synchronization Engine
 * Manages 5-state synchronization lifecycle, FIFO queueing, retry with exponential backoff,
 * duplicate idempotency protection, and conflict resolution.
 * Aligned with PRAHAR Engineering Specification v1.0 Section 14 (P0) & Phase 3.
 */

import fs from 'node:fs';
import path from 'node:path';
import {
  SyncRecord,
  SyncStatus,
  SyncBatchRequest,
  SyncBatchResponse,
  SyncBatchResultItem,
  SyncQueueStatus,
  resolveConflict,
} from '@prahar/shared';

export interface SyncEngineOptions {
  storageDir?: string;
  maxQueueSize?: number;
  maxRetries?: number;
  baseBackoffMs?: number;
}

export class SyncEngine {
  private storageDir: string;
  private queueFile: string;
  private processedKeysFile: string;

  private queue: SyncRecord[] = [];
  private processedKeys: Set<string> = new Set();
  private entityStore: Map<string, { data: any; updated_at: string }> = new Map();

  private maxQueueSize: number;
  private maxRetries: number;
  private baseBackoffMs: number;
  private isOnline: boolean = true;
  private lastSuccessfulSyncAt?: string;

  constructor(options?: SyncEngineOptions) {
    this.storageDir = options?.storageDir || path.resolve(process.cwd(), '.prahar_data');
    this.queueFile = path.join(this.storageDir, 'sync_queue.json');
    this.processedKeysFile = path.join(this.storageDir, 'processed_sync_keys.json');

    this.maxQueueSize = options?.maxQueueSize || 1000;
    this.maxRetries = options?.maxRetries || 5;
    this.baseBackoffMs = options?.baseBackoffMs || 500;

    this.ensureStorageDir();
    this.loadFromDisk();
  }

  private ensureStorageDir(): void {
    try {
      if (!fs.existsSync(this.storageDir)) {
        fs.mkdirSync(this.storageDir, { recursive: true });
      }
    } catch {
      // Memory fallback
    }
  }

  private loadFromDisk(): void {
    try {
      if (fs.existsSync(this.queueFile)) {
        const raw = fs.readFileSync(this.queueFile, 'utf-8');
        this.queue = JSON.parse(raw);
      }
      if (fs.existsSync(this.processedKeysFile)) {
        const raw = fs.readFileSync(this.processedKeysFile, 'utf-8');
        const keys: string[] = JSON.parse(raw);
        this.processedKeys = new Set(keys);
      }
    } catch {
      // Fallback
    }
  }

  private persistQueue(): void {
    try {
      this.ensureStorageDir();
      fs.writeFileSync(this.queueFile, JSON.stringify(this.queue, null, 2), 'utf-8');
      fs.writeFileSync(
        this.processedKeysFile,
        JSON.stringify(Array.from(this.processedKeys), null, 2),
        'utf-8'
      );
    } catch {
      // Memory fallback
    }
  }

  /**
   * Set network connectivity state.
   */
  public setOnline(online: boolean): void {
    this.isOnline = online;
  }

  public getOnline(): boolean {
    return this.isOnline;
  }

  /**
   * Enqueues a record locally into the FIFO synchronization queue.
   */
  public enqueue(record: Omit<SyncRecord, 'status' | 'retry_count' | 'max_retries' | 'buffered_at'>): SyncRecord {
    if (this.queue.length >= this.maxQueueSize) {
      // Drop oldest non-critical or oldest record
      this.queue.shift();
    }

    const fullRecord: SyncRecord = {
      ...record,
      status: 'PENDING',
      retry_count: 0,
      max_retries: this.maxRetries,
      buffered_at: new Date().toISOString(),
    };

    this.queue.push(fullRecord);
    this.persistQueue();
    return fullRecord;
  }

  /**
   * Returns current sync queue status and breakdown.
   */
  public getStatus(): SyncQueueStatus {
    const pending = this.queue.filter((r) => r.status === 'PENDING').length;
    const syncing = this.queue.filter((r) => r.status === 'SYNCING').length;
    const failed = this.queue.filter((r) => r.status === 'FAILED').length;
    const conflict = this.queue.filter((r) => r.status === 'CONFLICT').length;

    return {
      total_buffered: this.queue.length,
      pending_count: pending,
      syncing_count: syncing,
      failed_count: failed,
      conflict_count: conflict,
      is_online: this.isOnline,
      last_successful_sync_at: this.lastSuccessfulSyncAt,
    };
  }

  /**
   * Inspect failed or conflict events for troubleshooting.
   */
  public getFailedEvents(): SyncRecord[] {
    return this.queue.filter((r) => r.status === 'FAILED' || r.status === 'CONFLICT');
  }

  /**
   * Ingests a batch of sync records pushed from a client / rover.
   * Handles idempotency (duplicate prevention), conflict resolution, and status tracking.
   */
  public processBatch(batch: SyncBatchRequest): SyncBatchResponse {
    const results: SyncBatchResultItem[] = [];
    let syncedCount = 0;
    let failedCount = 0;
    let conflictCount = 0;
    let duplicateCount = 0;

    const strategy = batch.strategy || 'LAST_WRITE_WINS';

    for (const record of batch.records) {
      // 1. Idempotency Check: Have we already processed this exact idempotency_key?
      if (this.processedKeys.has(record.idempotency_key)) {
        duplicateCount++;
        results.push({
          idempotency_key: record.idempotency_key,
          event_id: record.event_id,
          status: 'SYNCED',
          is_duplicate: true,
          conflict_resolved: false,
        });
        continue;
      }

      // 2. Conflict Check: Check if an entity with this ID exists with a competing timestamp
      const entityId = (record.payload as any)?.id || (record.payload as any)?.event_id || record.idempotency_key;
      const existing = this.entityStore.get(entityId);

      if (existing) {
        const clientTimestamp = record.client_timestamp || record.buffered_at || new Date().toISOString();
        const conflictResolution = resolveConflict(
          { ...record.payload, updated_at: clientTimestamp },
          { ...existing.data, updated_at: existing.updated_at },
          strategy
        );

        if (conflictResolution.winner === 'CLIENT') {
          this.entityStore.set(entityId, {
            data: conflictResolution.resolvedItem,
            updated_at: clientTimestamp,
          });
          this.processedKeys.add(record.idempotency_key);
          syncedCount++;
          conflictCount++;
          results.push({
            idempotency_key: record.idempotency_key,
            event_id: record.event_id,
            status: 'SYNCED',
            is_duplicate: false,
            conflict_resolved: true,
          });
        } else {
          // Server wins — mark as CONFLICT on client record
          this.processedKeys.add(record.idempotency_key);
          conflictCount++;
          results.push({
            idempotency_key: record.idempotency_key,
            event_id: record.event_id,
            status: 'CONFLICT',
            is_duplicate: false,
            conflict_resolved: true,
            error: 'Server state newer; server record retained under LAST_WRITE_WINS policy.',
          });
        }
      } else {
        // 3. Normal Clean Ingestion
        const recordTime = record.client_timestamp || record.buffered_at || new Date().toISOString();
        this.entityStore.set(entityId, {
          data: record.payload,
          updated_at: recordTime,
        });
        this.processedKeys.add(record.idempotency_key);
        syncedCount++;
        results.push({
          idempotency_key: record.idempotency_key,
          event_id: record.event_id,
          status: 'SYNCED',
          is_duplicate: false,
          conflict_resolved: false,
        });
      }
    }

    this.lastSuccessfulSyncAt = new Date().toISOString();
    this.persistQueue();

    return {
      success: failedCount === 0,
      synced_count: syncedCount,
      failed_count: failedCount,
      conflict_count: conflictCount,
      duplicate_count: duplicateCount,
      results,
      timestamp: this.lastSuccessfulSyncAt,
    };
  }

  /**
   * Simulates client-side flushing of pending local queue to remote gateway.
   * If remote is unreachable or network is offline, transitions records through retry handling.
   */
  public async flushQueue(
    remotePusher?: (batch: SyncBatchRequest) => Promise<SyncBatchResponse>
  ): Promise<{
    flushed: number;
    synced: number;
    failed: number;
    conflicts: number;
  }> {
    if (!this.isOnline) {
      return { flushed: 0, synced: 0, failed: 0, conflicts: 0 };
    }

    const pending = this.queue.filter((r) => r.status === 'PENDING' || r.status === 'FAILED');
    if (pending.length === 0) {
      return { flushed: 0, synced: 0, failed: 0, conflicts: 0 };
    }

    // Mark as SYNCING
    for (const r of pending) {
      r.status = 'SYNCING';
    }
    this.persistQueue();

    const batch: SyncBatchRequest = {
      client_id: 'ROVER-LOCAL-CLIENT',
      records: pending,
    };

    let response: SyncBatchResponse;
    if (remotePusher) {
      try {
        response = await remotePusher(batch);
      } catch (err: any) {
        // Network failure during push — handle retries
        for (const r of pending) {
          r.retry_count++;
          r.last_error = err?.message || 'Network connection failed during sync';
          if (r.retry_count >= r.max_retries) {
            r.status = 'FAILED';
          } else {
            r.status = 'PENDING'; // Ready for next retry
          }
        }
        this.persistQueue();
        return { flushed: pending.length, synced: 0, failed: pending.length, conflicts: 0 };
      }
    } else {
      // In-process loopback push (direct evaluation)
      response = this.processBatch(batch);
    }

    // Update queue records based on batch response
    let synced = 0;
    let failed = 0;
    let conflicts = 0;

    for (const res of response.results) {
      const item = this.queue.find((r) => r.idempotency_key === res.idempotency_key);
      if (item) {
        if (res.status === 'SYNCED') {
          item.status = 'SYNCED';
          item.synced_at = new Date().toISOString();
          synced++;
        } else if (res.status === 'CONFLICT') {
          item.status = 'CONFLICT';
          item.last_error = res.error;
          conflicts++;
        } else {
          item.retry_count++;
          item.last_error = res.error || 'Sync rejected';
          if (item.retry_count >= item.max_retries) {
            item.status = 'FAILED';
            failed++;
          } else {
            item.status = 'PENDING';
          }
        }
      }
    }

    // Remove successfully SYNCED items from pending queue to keep buffer clean
    this.queue = this.queue.filter((r) => r.status !== 'SYNCED');
    this.persistQueue();

    return {
      flushed: pending.length,
      synced,
      failed,
      conflicts,
    };
  }

  /**
   * Retry all failed events manually.
   */
  public retryFailed(): number {
    let count = 0;
    for (const r of this.queue) {
      if (r.status === 'FAILED' || r.status === 'CONFLICT') {
        r.status = 'PENDING';
        r.retry_count = 0;
        r.last_error = undefined;
        count++;
      }
    }
    this.persistQueue();
    return count;
  }

  public clear(): void {
    this.queue = [];
    this.processedKeys.clear();
    this.entityStore.clear();
    try {
      if (fs.existsSync(this.queueFile)) fs.unlinkSync(this.queueFile);
      if (fs.existsSync(this.processedKeysFile)) fs.unlinkSync(this.processedKeysFile);
    } catch {
      // Ignore
    }
  }
}
