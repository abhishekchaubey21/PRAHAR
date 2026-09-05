/**
 * PRAHAR Rover Simulator — Command Processor & Idempotency Engine
 * Aligned with PRAHAR Engineering Specification v1.0 Section 6 & 16.
 */

import {
  RoverCommand,
  CommandAck,
  CommandStatus,
  SAFETY_LIMITS,
  validateCommand,
} from '@prahar/shared';

export interface CommandExecutionHandler {
  onStartScan: (cmd: RoverCommand) => Promise<any> | any;
  onStop: (cmd: RoverCommand) => Promise<any> | any;
  onReScan: (cmd: RoverCommand) => Promise<any> | any;
  onIrrigate: (cmd: RoverCommand) => Promise<any> | any;
  onStatus: (cmd: RoverCommand) => Promise<any> | any;
  getBatteryLevel: () => number;
}

export class CommandProcessor {
  // Command execution history map for strict idempotency
  private executedCommands: Map<string, CommandAck> = new Map();
  private maxHistorySize: number;

  constructor(maxHistorySize: number = 1000) {
    this.maxHistorySize = maxHistorySize;
  }

  /**
   * Dispatches command with idempotency verification and physical safety checks.
   */
  public async process(
    command: RoverCommand,
    handlers: CommandExecutionHandler
  ): Promise<CommandAck> {
    const { command_id, rover_id, command_type } = command;

    // 1. Idempotency Check: Have we already processed or are we processing this command_id?
    const existingAck = this.executedCommands.get(command_id);
    if (existingAck) {
      return {
        ...existingAck,
        duplicate: true,
        message: `Command ID '${command_id}' was already processed. Duplicate execution skipped.`,
      };
    }

    // 2. Validate Command Schema & Parameters
    const validation = validateCommand(command);
    if (!validation.valid) {
      const rejectAck: CommandAck = {
        command_id,
        rover_id,
        command_type,
        status: 'REJECTED',
        duplicate: false,
        message: validation.error || 'Command validation failed.',
        timestamp: new Date().toISOString(),
        error: validation.error,
      };
      this.cacheAck(command_id, rejectAck);
      return rejectAck;
    }

    // 3. Physical Safety Boundary: Battery Check
    const battery = handlers.getBatteryLevel();
    if (command_type !== 'STATUS' && command_type !== 'STOP' && battery <= SAFETY_LIMITS.MIN_BATTERY_FOR_ACTION_PCT) {
      const batteryRejectAck: CommandAck = {
        command_id,
        rover_id,
        command_type,
        status: 'REJECTED',
        duplicate: false,
        message: `Safety violation: Battery level (${battery.toFixed(1)}%) is below critical threshold (${SAFETY_LIMITS.MIN_BATTERY_FOR_ACTION_PCT}%). Action disallowed.`,
        timestamp: new Date().toISOString(),
        error: 'LOW_BATTERY_ABORT',
      };
      this.cacheAck(command_id, batteryRejectAck);
      return batteryRejectAck;
    }

    // 4. Physical Safety Boundary: Irrigation Limits
    if (command_type === 'IRRIGATE') {
      const duration = command.payload?.duration_seconds;
      if (duration > SAFETY_LIMITS.MAX_IRRIGATION_DURATION_SEC) {
        const irrigateRejectAck: CommandAck = {
          command_id,
          rover_id,
          command_type,
          status: 'REJECTED',
          duplicate: false,
          message: `Safety violation: Requested duration ${duration}s exceeds safety cap of ${SAFETY_LIMITS.MAX_IRRIGATION_DURATION_SEC}s.`,
          timestamp: new Date().toISOString(),
          error: 'MAX_IRRIGATION_DURATION_EXCEEDED',
        };
        this.cacheAck(command_id, irrigateRejectAck);
        return irrigateRejectAck;
      }
    }

    // 5. Execute Command via State Handlers
    try {
      let executionResult: any;

      switch (command_type) {
        case 'START_SCAN':
          executionResult = await handlers.onStartScan(command);
          break;
        case 'STOP':
          executionResult = await handlers.onStop(command);
          break;
        case 'RE_SCAN':
          executionResult = await handlers.onReScan(command);
          break;
        case 'IRRIGATE':
          executionResult = await handlers.onIrrigate(command);
          break;
        case 'STATUS':
          executionResult = await handlers.onStatus(command);
          break;
      }

      const completedAck: CommandAck = {
        command_id,
        rover_id,
        command_type,
        status: 'COMPLETED',
        duplicate: false,
        message: `Command '${command_type}' executed successfully.`,
        timestamp: new Date().toISOString(),
        result: executionResult,
      };

      this.cacheAck(command_id, completedAck);
      return completedAck;
    } catch (err: any) {
      const failedAck: CommandAck = {
        command_id,
        rover_id,
        command_type,
        status: 'FAILED',
        duplicate: false,
        message: `Command execution failed: ${err?.message || String(err)}`,
        timestamp: new Date().toISOString(),
        error: err?.message || String(err),
      };

      this.cacheAck(command_id, failedAck);
      return failedAck;
    }
  }

  /**
   * Returns whether a command ID has been recorded in the history cache.
   */
  public hasCommand(commandId: string): boolean {
    return this.executedCommands.has(commandId);
  }

  /**
   * Returns total count of processed commands in cache.
   */
  public getHistorySize(): number {
    return this.executedCommands.size;
  }

  /**
   * Clears the command history (primarily for test resets).
   */
  public clearHistory(): void {
    this.executedCommands.clear();
  }

  private cacheAck(commandId: string, ack: CommandAck): void {
    if (this.executedCommands.size >= this.maxHistorySize) {
      const oldestKey = this.executedCommands.keys().next().value;
      if (oldestKey) this.executedCommands.delete(oldestKey);
    }
    this.executedCommands.set(commandId, ack);
  }
}
