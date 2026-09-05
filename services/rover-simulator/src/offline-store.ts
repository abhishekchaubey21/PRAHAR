/**
 * PRAHAR Rover Simulator — Offline Event Store
 * Buffers telemetry, scan cycles, and rover events when network is unavailable.
 * Aligned with PRAHAR Engineering Specification v1.0 Section 6 & 14 (P0).
 */

import { RoverScanPayload, RoverTelemetry } from '@prahar/shared';

export interface OfflineEvent {
  event_id: string;
  event_type: 'SCAN_PAYLOAD' | 'TELEMETRY_HEARTBEAT' | 'COMMAND_ACK';
  payload: RoverScanPayload | RoverTelemetry | Record<string, any>;
  buffered_at: string;
  synced: boolean;
}

export class OfflineEventStore {
  private queue: OfflineEvent[] = [];
  private maxQueueSize: number;

  constructor(maxQueueSize: number = 500) {
    this.maxQueueSize = maxQueueSize;
  }

  /**
   * Enqueues an event to local offline buffer.
   */
  public enqueue(
    eventType: OfflineEvent['event_type'],
    payload: OfflineEvent['payload']
  ): OfflineEvent {
    if (this.queue.length >= this.maxQueueSize) {
      // FIFO eviction of oldest if overflowed
      this.queue.shift();
    }

    const event: OfflineEvent = {
      event_id: `offline-evt-${Date.now().toString(36)}-${Math.random().toString(36).substring(2, 6)}`,
      event_type: eventType,
      payload,
      buffered_at: new Date().toISOString(),
      synced: false,
    };

    this.queue.push(event);
    return event;
  }

  /**
   * Returns current count of unsynced events in offline buffer.
   */
  public getCount(): number {
    return this.queue.length;
  }

  /**
   * Returns all currently buffered offline events without clearing.
   */
  public peekAll(): OfflineEvent[] {
    return [...this.queue];
  }

  /**
   * Flushes and drains the offline store in FIFO order when connectivity is restored.
   */
  public flush(): OfflineEvent[] {
    const drained = [...this.queue];
    for (const evt of drained) {
      evt.synced = true;
    }
    this.queue = [];
    return drained;
  }

  /**
   * Clears the store.
   */
  public clear(): void {
    this.queue = [];
  }
}
