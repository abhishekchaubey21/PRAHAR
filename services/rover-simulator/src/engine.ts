/**
 * PRAHAR Rover Simulator — Rover Engine & State Machine
 * Central coordinator for telemetry generation, detections, command execution,
 * offline event queueing, and physical safety boundaries.
 * Aligned with PRAHAR Engineering Specification v1.0 Section 6.
 */

import {
  RoverState,
  RoverCommand,
  CommandAck,
  RoverTelemetry,
  RoverScanPayload,
} from '@prahar/shared';
import {
  generateRoverTelemetry,
  generateSensorBundle,
  bundleToReadings,
  generateZoneGps,
  DEMO_ZONE_PROFILES,
} from './telemetry-gen.js';
import { generateDetections } from './detection-gen.js';
import { OfflineEventStore, OfflineEvent } from './offline-store.js';
import { CommandProcessor, CommandExecutionHandler } from './command-proc.js';

export interface RoverEngineOptions {
  roverId?: string;
  initialZoneId?: string;
  initialBattery?: number;
  offlineMode?: boolean;
}

export interface RoverStatusReport {
  rover_id: string;
  state: RoverState;
  current_zone_id: string;
  battery_pct: number;
  is_offline: boolean;
  offline_buffered_events: number;
  current_task_id?: string;
  last_scan_id?: string;
  total_commands_executed: number;
  timestamp: string;
}

export class RoverEngine {
  private readonly roverId: string;
  private currentZoneId: string;
  private state: RoverState = 'IDLE';
  private batteryPct: number;
  private isOffline: boolean;
  private currentTaskId?: string;
  private lastScanPayload?: RoverScanPayload;

  public readonly offlineStore: OfflineEventStore;
  public readonly commandProcessor: CommandProcessor;

  constructor(options: RoverEngineOptions = {}) {
    this.roverId = options.roverId || 'ROVER-DEMO-01';
    this.currentZoneId = options.initialZoneId || 'DEMO-ZONE-01';
    this.batteryPct = options.initialBattery !== undefined ? options.initialBattery : 95.0;
    this.isOffline = options.offlineMode || false;

    this.offlineStore = new OfflineEventStore();
    this.commandProcessor = new CommandProcessor();
  }

  public getRoverId(): string {
    return this.roverId;
  }

  public getState(): RoverState {
    return this.state;
  }

  public getCurrentZoneId(): string {
    return this.currentZoneId;
  }

  public getBatteryPct(): number {
    return this.batteryPct;
  }

  public isOfflineMode(): boolean {
    return this.isOffline;
  }

  public setOfflineMode(enabled: boolean): void {
    this.isOffline = enabled;
  }

  /**
   * Dispatches a command to the rover with strict idempotency and safety limits.
   */
  public async executeCommand(command: RoverCommand): Promise<CommandAck> {
    const handlers: CommandExecutionHandler = {
      getBatteryLevel: () => this.batteryPct,
      onStartScan: async (cmd) => this.handleStartScan(cmd),
      onStop: async (cmd) => this.handleStop(cmd),
      onReScan: async (cmd) => this.handleReScan(cmd),
      onIrrigate: async (cmd) => this.handleIrrigate(cmd),
      onStatus: async () => this.getStatus(),
    };

    const ack = await this.commandProcessor.process(command, handlers);

    // If offline and newly executed (not duplicate rejection), buffer the ACK
    if (this.isOffline && !ack.duplicate) {
      this.offlineStore.enqueue('COMMAND_ACK', ack);
    }

    return ack;
  }

  /**
   * Executes a simulated scan cycle on a zone.
   * Generates GPS, sensor readings (moisture, temp, humidity, pH), and AI detections.
   */
  public simulateScanCycle(zoneId?: string, isReScan: boolean = false): RoverScanPayload {
    const targetZone = zoneId || this.currentZoneId;
    this.currentZoneId = targetZone;
    this.state = isReScan ? 'RE_SCANNING' : 'SCANNING';

    // Drain simulated battery for scanning action
    this.batteryPct = Math.max(1.0, this.batteryPct - 1.2);

    const scanId = `scan-${targetZone.toLowerCase()}-${Date.now().toString(36)}`;
    const gps = generateZoneGps(targetZone);
    const bundle = generateSensorBundle(targetZone);
    const sensorReadings = bundleToReadings(targetZone, bundle, `${this.roverId}_probe`);
    const detections = generateDetections({ zoneId: targetZone });

    const scanPayload: RoverScanPayload = {
      scan_id: scanId,
      rover_id: this.roverId,
      zone_id: targetZone,
      gps,
      sensor_readings: sensorReadings,
      detections,
      battery_pct: Number(this.batteryPct.toFixed(1)),
      timestamp: new Date().toISOString(),
    };

    this.lastScanPayload = scanPayload;
    this.state = 'IDLE';

    // If rover is offline, buffer the scan payload into local offline store
    if (this.isOffline) {
      this.offlineStore.enqueue('SCAN_PAYLOAD', scanPayload);
    }

    return scanPayload;
  }

  /**
   * Simulates micro-irrigation in a target zone with physical safety caps.
   * NOTE: Per specification, Phase 1 only simulates irrigation.
   */
  public simulateIrrigation(params: {
    zoneId: string;
    durationSeconds: number;
    volumeLiters?: number;
  }): {
    zone_id: string;
    duration_seconds: number;
    volume_liters: number;
    moisture_before_pct: number;
    moisture_after_pct: number;
  } {
    const { zoneId, durationSeconds } = params;
    this.currentZoneId = zoneId;
    this.state = 'IRRIGATING';

    const volumeLiters = params.volumeLiters || Number((durationSeconds * 0.25).toFixed(2)); // ~0.25 L/sec
    // Drain simulated battery for pump/actuator activation
    this.batteryPct = Math.max(1.0, this.batteryPct - (durationSeconds * 0.05));

    // Simulate moisture increase
    const currentBundle = generateSensorBundle(zoneId);
    const moistureBefore = currentBundle.moisture_pct;
    const moistureIncrease = Math.min(25.0, (durationSeconds / 60.0) * 12.0);
    const moistureAfter = Number(Math.min(65.0, moistureBefore + moistureIncrease).toFixed(1));

    const result = {
      zone_id: zoneId,
      duration_seconds: durationSeconds,
      volume_liters: volumeLiters,
      moisture_before_pct: moistureBefore,
      moisture_after_pct: moistureAfter,
    };

    this.state = 'IDLE';

    if (this.isOffline) {
      this.offlineStore.enqueue('COMMAND_ACK', {
        action: 'IRRIGATE_SIMULATED',
        result,
        timestamp: new Date().toISOString(),
      });
    }

    return result;
  }

  /**
   * Generates latest telemetry heartbeat.
   */
  public getTelemetry(): RoverTelemetry {
    const telemetry = generateRoverTelemetry({
      roverId: this.roverId,
      zoneId: this.currentZoneId,
      batteryPct: this.batteryPct,
      status: this.state,
      currentTaskId: this.currentTaskId,
    });

    if (this.isOffline) {
      this.offlineStore.enqueue('TELEMETRY_HEARTBEAT', telemetry);
    }

    return telemetry;
  }

  /**
   * Returns current rover status report.
   */
  public getStatus(): RoverStatusReport {
    return {
      rover_id: this.roverId,
      state: this.state,
      current_zone_id: this.currentZoneId,
      battery_pct: Number(this.batteryPct.toFixed(1)),
      is_offline: this.isOffline,
      offline_buffered_events: this.offlineStore.getCount(),
      current_task_id: this.currentTaskId,
      last_scan_id: this.lastScanPayload?.scan_id,
      total_commands_executed: this.commandProcessor.getHistorySize(),
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Flushes offline buffer when connectivity is restored.
   */
  public flushOfflineQueue(): OfflineEvent[] {
    return this.offlineStore.flush();
  }

  /**
   * Recharges rover battery.
   */
  public recharge(targetPct: number = 100.0): void {
    this.batteryPct = Math.min(100.0, Math.max(0.0, targetPct));
  }

  // Private command action handlers
  private async handleStartScan(cmd: RoverCommand): Promise<RoverScanPayload> {
    const zoneId = cmd.payload?.zone_id || this.currentZoneId;
    this.currentTaskId = cmd.command_id;
    const scanPayload = this.simulateScanCycle(zoneId, false);
    this.currentTaskId = undefined;
    return scanPayload;
  }

  private async handleStop(cmd: RoverCommand): Promise<{ status: string; reason?: string }> {
    this.state = 'STOPPED';
    this.currentTaskId = undefined;
    return {
      status: 'ROVER_HALTED_SAFELY',
      reason: cmd.payload?.reason || 'User emergency stop',
    };
  }

  private async handleReScan(cmd: RoverCommand): Promise<RoverScanPayload> {
    const zoneId = cmd.payload?.zone_id || this.currentZoneId;
    this.currentTaskId = cmd.command_id;
    const scanPayload = this.simulateScanCycle(zoneId, true);
    this.currentTaskId = undefined;
    return scanPayload;
  }

  private async handleIrrigate(cmd: RoverCommand): Promise<any> {
    const { zone_id, duration_seconds, volume_liters } = cmd.payload;
    this.currentTaskId = cmd.command_id;
    const result = this.simulateIrrigation({
      zoneId: zone_id,
      durationSeconds: duration_seconds,
      volumeLiters: volume_liters,
    });
    this.currentTaskId = undefined;
    return result;
  }
}
