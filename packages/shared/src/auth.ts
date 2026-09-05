/**
 * PRAHAR Shared Authentication & RBAC Contracts
 * Aligned with Phase 5A Amendment 2:
 * - Roles: FARMER, EXPERT, ADMIN
 * - Public registration permits ONLY FARMER users
 * - Role assignment security: Client cannot self-promote to EXPERT or ADMIN
 */

export type UserRole = 'FARMER' | 'EXPERT' | 'ADMIN';

export interface UserProfile {
  id: string;
  email: string;
  full_name: string;
  role: UserRole;
  farmer_id?: string;
  assigned_cluster?: string;
  created_at: string;
  updated_at: string;
}

export interface AuthSession {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token?: string;
  user: {
    id: string;
    email: string;
    role: UserRole;
    full_name: string;
    farmer_id?: string;
  };
}

export interface AuthenticatedContext {
  user_id: string;
  email: string;
  role: UserRole;
  farmer_id?: string;
  is_service_role?: boolean;
}

export interface RegisterFarmerRequest {
  email: string;
  password: string;
  full_name: string;
  phone?: string;
  // NOTE: 'role' is intentionally NOT accepted from registration payload!
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface AuthResponse {
  success: boolean;
  message?: string;
  session?: AuthSession;
  error?: string;
}
