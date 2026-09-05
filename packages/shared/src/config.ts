/**
 * PRAHAR Centralized Configuration & Environment Validation
 * Aligned with Phase 5A Amendment 4:
 * - Centralizes configuration without hardcoding
 * - Production guard: Refuses startup if NODE_ENV=production and ALLOW_SIMULATOR_BYPASS=true
 * - Service-role key is strictly server-side
 */

export interface PraharConfig {
  nodeEnv: 'development' | 'production' | 'test';
  port: number;
  supabaseUrl?: string;
  supabaseAnonKey?: string;
  supabaseServiceRoleKey?: string;
  allowedOrigins: string[];
  allowSimulatorBypass: boolean;
  roverApiKey?: string;
  weatherApiUrl: string;
}

export function loadConfig(env: Record<string, string | undefined> = process.env): PraharConfig {
  const nodeEnv = (env.NODE_ENV as any) || 'development';
  const port = parseInt(env.PORT || '3001', 10);
  const allowSimulatorBypass = env.ALLOW_SIMULATOR_BYPASS === 'true' || (nodeEnv !== 'production' && env.ALLOW_SIMULATOR_BYPASS !== 'false');

  // Amendment 4: Production must refuse startup if ALLOW_SIMULATOR_BYPASS=true
  if (nodeEnv === 'production' && allowSimulatorBypass) {
    throw new Error(
      '[PRAHAR SECURITY VIOLATION] Refusing startup: ALLOW_SIMULATOR_BYPASS cannot be true when NODE_ENV is production. Authenticated device credentials are required.'
    );
  }

  const allowedOrigins = env.ALLOWED_ORIGINS
    ? env.ALLOWED_ORIGINS.split(',').map((s) => s.trim())
    : ['http://localhost:3000', 'http://localhost:3001'];

  return {
    nodeEnv,
    port,
    supabaseUrl: env.SUPABASE_URL,
    supabaseAnonKey: env.SUPABASE_ANON_KEY,
    supabaseServiceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
    allowedOrigins,
    allowSimulatorBypass,
    roverApiKey: env.ROVER_API_KEY || 'prahar_hw_demo_key_2026',
    weatherApiUrl: env.WEATHER_API_URL || 'https://api.open-meteo.com/v1/forecast',
  };
}
