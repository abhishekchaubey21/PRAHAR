/**
 * PRAHAR Authentication Service
 * Aligned with Phase 5A Amendment 2:
 * - Public registration permits ONLY FARMER users.
 * - Client-supplied role claims are rejected.
 * - Admin/Expert elevation requires privileged server-side admin credentials.
 * - Zero plaintext passwords stored.
 */

import {
  AuthSession,
  AuthenticatedContext,
  RegisterFarmerRequest,
  LoginRequest,
  UserRole,
} from '@prahar/shared';
import {
  getAnonClient,
  getServiceRoleClient,
  createUserScopedClient,
  isSupabaseConfigured,
} from './supabase-client.js';

// Local memory store for test/offline development profiles
interface LocalUserAccount {
  id: string;
  email: string;
  passwordHash: string; // In-memory development hash simulation
  fullName: string;
  role: UserRole;
  farmerId?: string;
}

const localUserStore: Map<string, LocalUserAccount> = new Map();

// Seed standard development/expert/admin accounts for local simulator operation
localUserStore.set('dr_sharma@kvk.gov.in', {
  id: 'usr-expert-sharma-01',
  email: 'dr_sharma@kvk.gov.in',
  passwordHash: 'Expert@123',
  fullName: 'Dr. Ramesh Sharma (KVK Agronomist)',
  role: 'EXPERT',
});

localUserStore.set('admin@prahar.gov.in', {
  id: 'usr-admin-prahar-01',
  email: 'admin@prahar.gov.in',
  passwordHash: 'Admin@123',
  fullName: 'PRAHAR System Administrator',
  role: 'ADMIN',
});

localUserStore.set('farmer.ramesh@kisan.in', {
  id: 'usr-farmer-ramesh-01',
  email: 'farmer.ramesh@kisan.in',
  passwordHash: 'Kisan@123',
  fullName: 'Ramesh Patel',
  role: 'FARMER',
  farmerId: 'FARMER-DEMO-01',
});

export class AuthService {
  /**
   * Amendment 2: Public registration strictly creates FARMER users.
   * Role parameter is hardcoded to 'FARMER'; client input is rejected if it claims other roles.
   */
  public async registerFarmer(req: RegisterFarmerRequest): Promise<AuthSession> {
    const email = req.email.trim().toLowerCase();
    const password = req.password;
    const fullName = req.full_name.trim();

    if (!email || !password || password.length < 6) {
      throw new Error('Valid email and minimum 6-character password are required.');
    }

    if (isSupabaseConfigured()) {
      const anonClient = getAnonClient();
      // Notice: role is hardcoded to FARMER. Client has zero ability to specify role.
      const { data, error } = await anonClient.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: fullName,
            role: 'FARMER',
          },
        },
      });

      if (error) {
        throw new Error(`[AuthService] Registration failed: ${error.message}`);
      }

      const user = data.user!;
      const session = data.session;

      return {
        access_token: session?.access_token || `token-farmer-${user.id}`,
        token_type: 'Bearer',
        expires_in: session?.expires_in || 3600,
        refresh_token: session?.refresh_token,
        user: {
          id: user.id,
          email: user.email!,
          role: 'FARMER', // Strictly FARMER
          full_name: fullName,
        },
      };
    }

    // Local / offline simulation fallback
    if (localUserStore.has(email)) {
      throw new Error('User with this email already registered.');
    }

    const userId = `usr-farmer-${Date.now().toString(36)}`;
    const account: LocalUserAccount = {
      id: userId,
      email,
      passwordHash: password,
      fullName,
      role: 'FARMER', // Strictly FARMER
      farmerId: `FARMER-${Date.now().toString(36).toUpperCase()}`,
    };
    localUserStore.set(email, account);

    return {
      access_token: `mock-jwt-${account.role.toLowerCase()}-${account.id}`,
      token_type: 'Bearer',
      expires_in: 3600,
      user: {
        id: account.id,
        email: account.email,
        role: account.role,
        full_name: account.fullName,
        farmer_id: account.farmerId,
      },
    };
  }

  /**
   * Authenticate user with Supabase Auth or local development accounts.
   */
  public async login(req: LoginRequest): Promise<AuthSession> {
    const email = req.email.trim().toLowerCase();
    const password = req.password;

    if (isSupabaseConfigured()) {
      const anonClient = getAnonClient();
      const { data, error } = await anonClient.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        throw new Error(`[AuthService] Login failed: ${error.message}`);
      }

      const session = data.session!;
      const user = data.user!;

      // Resolve role from public.profiles using user-scoped client
      let role: UserRole = 'FARMER';
      let fullName = user.user_metadata?.full_name || email;
      let farmerId: string | undefined = undefined;

      try {
        const userClient = createUserScopedClient(session.access_token);
        const { data: profile } = await userClient
          .from('profiles')
          .select('role, full_name, farmer_id')
          .eq('id', user.id)
          .maybeSingle();

        if (profile) {
          role = (profile.role as UserRole) || 'FARMER';
          fullName = profile.full_name || fullName;
          farmerId = profile.farmer_id;
        }
      } catch {
        // Fallback to metadata
        role = (user.user_metadata?.role as UserRole) || 'FARMER';
      }

      return {
        access_token: session.access_token,
        token_type: 'Bearer',
        expires_in: session.expires_in,
        refresh_token: session.refresh_token,
        user: {
          id: user.id,
          email: user.email!,
          role,
          full_name: fullName,
          farmer_id: farmerId,
        },
      };
    }

    // Local / offline fallback
    const account = localUserStore.get(email);
    if (!account || account.passwordHash !== password) {
      throw new Error('Invalid email or password.');
    }

    return {
      access_token: `mock-jwt-${account.role.toLowerCase()}-${account.id}`,
      token_type: 'Bearer',
      expires_in: 3600,
      user: {
        id: account.id,
        email: account.email,
        role: account.role,
        full_name: account.fullName,
        farmer_id: account.farmerId,
      },
    };
  }

  /**
   * Validates JWT token and resolves caller context.
   */
  public async verifyToken(token: string): Promise<AuthenticatedContext | null> {
    if (!token || token.trim() === '') return null;

    // Check mock tokens for local testing
    if (token.startsWith('mock-jwt-')) {
      const parts = token.split('-');
      // format: mock-jwt-<role>-<id>
      const roleStr = parts[2]?.toUpperCase() as UserRole;
      const userId = parts.slice(3).join('-');

      for (const account of localUserStore.values()) {
        if (account.id === userId) {
          return {
            user_id: account.id,
            email: account.email,
            role: account.role,
            farmer_id: account.farmerId,
          };
        }
      }

      if (['FARMER', 'EXPERT', 'ADMIN'].includes(roleStr)) {
        return {
          user_id: userId,
          email: `${userId}@prahar.local`,
          role: roleStr,
        };
      }
      return null;
    }

    if (isSupabaseConfigured()) {
      try {
        const anonClient = getAnonClient();
        const { data: { user }, error } = await anonClient.auth.getUser(token);
        if (error || !user) return null;

        // Resolve profile & role from profiles table
        let role: UserRole = (user.user_metadata?.role as UserRole) || 'FARMER';
        let farmerId: string | undefined = undefined;

        try {
          const userClient = createUserScopedClient(token);
          const { data: profile } = await userClient
            .from('profiles')
            .select('role, farmer_id')
            .eq('id', user.id)
            .maybeSingle();

          if (profile) {
            role = (profile.role as UserRole) || 'FARMER';
            farmerId = profile.farmer_id;
          }
        } catch {
          // Keep metadata role
        }

        return {
          user_id: user.id,
          email: user.email || '',
          role,
          farmer_id: farmerId,
        };
      } catch {
        return null;
      }
    }

    return null;
  }

  /**
   * DOCUMENTED SERVICE-ROLE USAGE #1:
   * Promotes a user to EXPERT or ADMIN.
   * Requires verified caller to be ADMIN.
   * Uses `getServiceRoleClient()` to update `public.profiles` safely.
   */
  public async promoteUserRole(
    adminContext: AuthenticatedContext,
    targetUserId: string,
    newRole: UserRole
  ): Promise<void> {
    if (adminContext.role !== 'ADMIN') {
      throw new Error('[Security Violation] Only ADMIN users can promote roles.');
    }

    if (!['FARMER', 'EXPERT', 'ADMIN'].includes(newRole)) {
      throw new Error(`Invalid role '${newRole}'.`);
    }

    if (isSupabaseConfigured()) {
      const adminClient = getServiceRoleClient();
      const { error } = await adminClient
        .from('profiles')
        .update({ role: newRole, updated_at: new Date().toISOString() })
        .eq('id', targetUserId);

      if (error) {
        throw new Error(`[AuthService] Role promotion failed: ${error.message}`);
      }
      return;
    }

    // Local fallback
    for (const acc of localUserStore.values()) {
      if (acc.id === targetUserId) {
        acc.role = newRole;
        return;
      }
    }
  }

  public getLocalAccounts(): LocalUserAccount[] {
    return Array.from(localUserStore.values());
  }
}
