/**
 * PRAHAR Supabase Client Factory
 * Aligned with Phase 5A Amendment 1:
 * - Service-role client is NEVER the default data path.
 * - Normal authenticated CRUD routes through user-scoped clients preserving PostgreSQL RLS.
 * - Service-role client is used ONLY for explicitly documented administrative/system operations.
 * - Secrets are strictly server-side and never logged.
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { loadConfig } from '@prahar/shared';

const config = loadConfig();

let anonClientInstance: SupabaseClient | null = null;
let serviceRoleClientInstance: SupabaseClient | null = null;

export function isSupabaseConfigured(): boolean {
  return (
    Boolean(config.supabaseUrl) &&
    Boolean(config.supabaseAnonKey) &&
    !config.supabaseUrl?.includes('your-project-id') &&
    !config.supabaseAnonKey?.includes('your-supabase-anon-key')
  );
}

/**
 * Returns a standard anonymous client for public auth endpoints (sign-in, sign-up).
 */
export function getAnonClient(): SupabaseClient {
  if (!config.supabaseUrl || !config.supabaseAnonKey) {
    throw new Error('[SupabaseClient] SUPABASE_URL and SUPABASE_ANON_KEY must be configured.');
  }

  if (!anonClientInstance) {
    anonClientInstance = createClient(config.supabaseUrl, config.supabaseAnonKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });
  }
  return anonClientInstance;
}

/**
 * Creates a user-scoped Supabase client configured with the caller's JWT Bearer token.
 * ALL standard Farmer/Expert/Admin application queries MUST use this client
 * so that PostgreSQL Row-Level Security (RLS) is strictly enforced in the database.
 */
export function createUserScopedClient(accessToken: string): SupabaseClient {
  if (!config.supabaseUrl || !config.supabaseAnonKey) {
    throw new Error('[SupabaseClient] Cannot create user-scoped client: Supabase not configured.');
  }

  return createClient(config.supabaseUrl, config.supabaseAnonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  });
}

/**
 * Privileged Service-Role Client.
 *
 * DOCUMENTED SERVICE-ROLE USAGES:
 * 1. `AuthService.promoteUserRole()`: Changing a user's role to EXPERT or ADMIN after admin authentication check.
 * 2. `RoverIngestionService`: Ingesting automated telemetry/sensor batches from verified rovers where no interactive user is logged in.
 * 3. Database test harness: Setting up/tearing down test tenant fixtures in isolated test databases.
 *
 * SECURITY INVARIANTS:
 * - NEVER exposed to Flutter mobile app or browser bundles.
 * - NEVER returned in API responses or printed to log streams.
 */
export function getServiceRoleClient(): SupabaseClient {
  if (!config.supabaseUrl || !config.supabaseServiceRoleKey) {
    throw new Error('[SupabaseClient] Service-role operations require SUPABASE_SERVICE_ROLE_KEY.');
  }

  if (!serviceRoleClientInstance) {
    serviceRoleClientInstance = createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });
  }
  return serviceRoleClientInstance;
}
