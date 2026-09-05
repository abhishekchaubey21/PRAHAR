/**
 * PRAHAR Offline Synchronization Contracts & State Machine
 * Aligned with PRAHAR Engineering Specification v1.0 Section 6 & 14 (P0) and Phase 3 Blueprint.
 */

export type SyncStatus = 'PENDING' | 'SYNCING' | 'SYNCED' | 'FAILED' | 'CONFLICT';

export type SyncConflictStrategy = 'SERVER_WINS' | 'CLIENT_WINS' | 'LAST_WRITE_WINS';

export interface SyncRecord<T = Record<string, any>> {
  event_id: string;
  idempotency_key: string;
  rover_id: string;
  entity_type: 'SCAN_PAYLOAD' | 'TELEMETRY' | 'COMMAND_ACK' | 'ALERT_ACK' | 'REMEDIATION_ACTION';
  action: 'INSERT' | 'UPDATE' | 'UPSERT';
  payload: T;
  status: SyncStatus;
  retry_count: number;
  max_retries: number;
  last_error?: string;
  buffered_at: string;
  synced_at?: string;
  client_timestamp: string;
  server_timestamp?: string;
}

export interface SyncBatchRequest {
  client_id: string;
  records: SyncRecord[];
  strategy?: SyncConflictStrategy;
}

export interface SyncBatchResultItem {
  idempotency_key: string;
  event_id: string;
  status: SyncStatus;
  is_duplicate: boolean;
  conflict_resolved: boolean;
  error?: string;
}

export interface SyncBatchResponse {
  success: boolean;
  synced_count: number;
  failed_count: number;
  conflict_count: number;
  duplicate_count: number;
  results: SyncBatchResultItem[];
  timestamp: string;
}

export interface SyncQueueStatus {
  total_buffered: number;
  pending_count: number;
  syncing_count: number;
  failed_count: number;
  conflict_count: number;
  is_online: boolean;
  last_successful_sync_at?: string;
}

/**
 * Validates a sync record before enqueueing.
 */
export function validateSyncRecord(record: Partial<SyncRecord>): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  if (!record.event_id) errors.push('Missing event_id');
  if (!record.idempotency_key) errors.push('Missing idempotency_key');
  if (!record.rover_id) errors.push('Missing rover_id');
  if (!record.entity_type) errors.push('Missing entity_type');
  if (!record.payload) errors.push('Missing payload');

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Resolves conflict between client record and server record using LAST_WRITE_WINS strategy.
 */
export function resolveConflict<T extends { updated_at?: string; timestamp?: string }>(
  clientItem: T,
  serverItem: T,
  strategy: SyncConflictStrategy = 'LAST_WRITE_WINS'
): { winner: 'CLIENT' | 'SERVER'; resolvedItem: T } {
  if (strategy === 'CLIENT_WINS') {
    return { winner: 'CLIENT', resolvedItem: clientItem };
  }
  if (strategy === 'SERVER_WINS') {
    return { winner: 'SERVER', resolvedItem: serverItem };
  }

  // LAST_WRITE_WINS
  const clientTimeStr = clientItem.updated_at || clientItem.timestamp || '1970-01-01T00:00:00Z';
  const serverTimeStr = serverItem.updated_at || serverItem.timestamp || '1970-01-01T00:00:00Z';

  const clientTime = new Date(clientTimeStr).getTime();
  const serverTime = new Date(serverTimeStr).getTime();

  if (clientTime >= serverTime) {
    return { winner: 'CLIENT', resolvedItem: clientItem };
  } else {
    return { winner: 'SERVER', resolvedItem: serverItem };
  }
}
