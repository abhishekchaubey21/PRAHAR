/**
 * PRAHAR Authentication & Authorization Middleware
 * Aligned with Phase 5A Amendments 1, 2 & 4:
 * - Reads Bearer JWT and resolves authenticated user context
 * - Enforces 401 on missing/invalid/expired token
 * - Enforces 403 on role mismatch
 * - Device boundary: Distinguishes SIMULATOR from trusted hardware ingestion
 * - NEVER trusts user_id or role from request body
 */

import http from 'node:http';
import { AuthenticatedContext, UserRole, PraharConfig } from '@prahar/shared';
import { AuthService } from './auth-service.js';

export interface AuthenticatedRequest extends http.IncomingMessage {
  auth?: AuthenticatedContext;
  roverSource?: string;
}

export function extractBearerToken(req: http.IncomingMessage): string | null {
  const authHeader = req.headers.authorization;
  if (!authHeader) return null;

  const parts = authHeader.split(' ');
  if (parts.length === 2 && parts[0].toLowerCase() === 'bearer') {
    return parts[1].trim();
  }
  return null;
}

/**
 * Middleware: Requires a valid JWT token.
 * Returns 401 Unauthorized if missing, malformed, or invalid.
 */
export async function authenticateRequest(
  req: AuthenticatedRequest,
  res: http.ServerResponse,
  authService: AuthService
): Promise<AuthenticatedContext | null> {
  const token = extractBearerToken(req);

  if (!token) {
    res.writeHead(401, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(
      JSON.stringify(
        {
          success: false,
          error: 'Authentication required. Missing Bearer token in Authorization header.',
        },
        null,
        2
      )
    );
    return null;
  }

  const context = await authService.verifyToken(token);
  if (!context) {
    res.writeHead(401, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(
      JSON.stringify(
        {
          success: false,
          error: 'Authentication failed. Token is invalid or expired.',
        },
        null,
        2
      )
    );
    return null;
  }

  req.auth = context;
  return context;
}

/**
 * Middleware: Enforces role authorization (RBAC).
 * Returns 403 Forbidden if user role is not in allowedRoles.
 */
export function enforceRole(
  req: AuthenticatedRequest,
  res: http.ServerResponse,
  allowedRoles: UserRole[]
): boolean {
  const context = req.auth;

  if (!context || !allowedRoles.includes(context.role)) {
    res.writeHead(403, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(
      JSON.stringify(
        {
          success: false,
          error: `Forbidden: Action requires one of [${allowedRoles.join(', ')}] role. Current role: '${context?.role || 'UNAUTHENTICATED'}'.`,
        },
        null,
        2
      )
    );
    return false;
  }

  return true;
}

/**
 * Middleware: Rover Ingestion & Device Security Boundary
 * Aligned with Amendment 4:
 * - Production requires verified X-Rover-Api-Key
 * - Development permits SIMULATOR_DEV_BYPASS only if explicitly configured
 */
export function authenticateRoverIngestion(
  req: AuthenticatedRequest,
  res: http.ServerResponse,
  config: PraharConfig
): boolean {
  const roverKey = req.headers['x-rover-api-key'] as string | undefined;

  // 1. Valid device API key provided
  if (roverKey && config.roverApiKey && roverKey === config.roverApiKey) {
    req.roverSource = 'AUTHENTICATED_HARDWARE_ROVER';
    return true;
  }

  // 2. Simulator Development Bypass (ONLY allowed in non-production when configured)
  if (config.allowSimulatorBypass && config.nodeEnv !== 'production') {
    req.roverSource = 'SIMULATOR_DEV_BYPASS';
    return true;
  }

  // 3. Rejected
  res.writeHead(401, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(
    JSON.stringify(
      {
        success: false,
        error: 'Unauthorized rover ingestion: Valid X-Rover-Api-Key device header required. Simulator bypass is disabled.',
      },
      null,
      2
    )
  );
  return false;
}
