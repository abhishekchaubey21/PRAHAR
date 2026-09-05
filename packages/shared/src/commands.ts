/**
 * PRAHAR Precision Rover — Command & Control Contracts
 * Aligned with PRAHAR Engineering Specification v1.0 Section 6.
 */

export type CommandType =
  | 'START_SCAN'
  | 'STOP'
  | 'RE_SCAN'
  | 'IRRIGATE'
  | 'STATUS';

export type CommandStatus =
  | 'ACKNOWLEDGED'
  | 'EXECUTING'
  | 'COMPLETED'
  | 'REJECTED'
  | 'FAILED';

export interface StartScanPayload {
  zone_id: string;
  scan_mode?: 'RAPID' | 'DEEP';
}

export interface StopPayload {
  reason?: string;
}

export interface ReScanPayload {
  zone_id: string;
  previous_scan_id?: string;
}

export interface IrrigatePayload {
  zone_id: string;
  duration_seconds: number; // Simulated solenoid activation time
  volume_liters?: number;
  approved_by: string; // Safety gate: mandatory attribution ('farmer' | 'expert' | actor ID)
  approval_token?: string;
}

export type StatusPayload = Record<string, never>;

export type CommandPayload =
  | StartScanPayload
  | StopPayload
  | ReScanPayload
  | IrrigatePayload
  | StatusPayload;

export interface RoverCommand<T = any> {
  command_id: string;
  rover_id: string;
  command_type: CommandType;
  payload: T;
  issued_at: string;
}

export interface CommandAck {
  command_id: string;
  rover_id: string;
  command_type: CommandType;
  status: CommandStatus;
  duplicate: boolean; // True if this command_id was already received & processed
  message: string;
  timestamp: string;
  result?: any;
  error?: string;
}

/**
 * Physical Safety Limits for Rover Simulation (Phase 1).
 */
export const SAFETY_LIMITS = {
  MAX_IRRIGATION_DURATION_SEC: 180, // Prevent runaway simulated water release
  MAX_IRRIGATION_VOLUME_L: 50.0,
  MIN_BATTERY_FOR_ACTION_PCT: 10.0, // Rover halts or rejects heavy motion below 10%
} as const;

/**
 * Validates command structure and parameters before execution.
 */
export function validateCommand(command: Partial<RoverCommand>): { valid: boolean; error?: string } {
  if (!command.command_id || typeof command.command_id !== 'string') {
    return { valid: false, error: 'Command must contain a valid string command_id.' };
  }
  if (!command.rover_id || typeof command.rover_id !== 'string') {
    return { valid: false, error: 'Command must specify a rover_id.' };
  }

  const validTypes: CommandType[] = ['START_SCAN', 'STOP', 'RE_SCAN', 'IRRIGATE', 'STATUS'];
  if (!command.command_type || !validTypes.includes(command.command_type)) {
    return { valid: false, error: `Unsupported command_type: ${command.command_type}` };
  }

  const payload = command.payload || {};

  switch (command.command_type) {
    case 'START_SCAN':
      if (!payload.zone_id || typeof payload.zone_id !== 'string') {
        return { valid: false, error: 'START_SCAN requires a valid zone_id.' };
      }
      break;
    case 'RE_SCAN':
      if (!payload.zone_id || typeof payload.zone_id !== 'string') {
        return { valid: false, error: 'RE_SCAN requires a valid zone_id.' };
      }
      break;
    case 'IRRIGATE':
      if (!payload.zone_id || typeof payload.zone_id !== 'string') {
        return { valid: false, error: 'IRRIGATE requires a valid zone_id.' };
      }
      if (!payload.approved_by || typeof payload.approved_by !== 'string' || payload.approved_by.trim() === '') {
        return {
          valid: false,
          error: 'Safety Gate Violation: IRRIGATE requires explicit approved_by attribution (farmer or expert approval). Autonomous execution blocked.',
        };
      }
      if (
        payload.duration_seconds === undefined ||
        typeof payload.duration_seconds !== 'number' ||
        payload.duration_seconds <= 0
      ) {
        return { valid: false, error: 'IRRIGATE requires a positive duration_seconds.' };
      }
      if (payload.duration_seconds > SAFETY_LIMITS.MAX_IRRIGATION_DURATION_SEC) {
        return {
          valid: false,
          error: `Safety constraint violation: duration ${payload.duration_seconds}s exceeds max limit of ${SAFETY_LIMITS.MAX_IRRIGATION_DURATION_SEC}s.`,
        };
      }
      if (payload.volume_liters !== undefined && payload.volume_liters > SAFETY_LIMITS.MAX_IRRIGATION_VOLUME_L) {
        return {
          valid: false,
          error: `Safety constraint violation: volume ${payload.volume_liters}L exceeds max limit of ${SAFETY_LIMITS.MAX_IRRIGATION_VOLUME_L}L.`,
        };
      }
      break;
    case 'STOP':
    case 'STATUS':
      // Valid with minimal/empty payload
      break;
  }

  return { valid: true };
}
