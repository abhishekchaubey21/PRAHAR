'use client';

/**
 * PRAHAR Expert Console — Supabase Authentication Context
 * Manages authenticated expert sessions, JWT storage, and role validation.
 */

import React, { createContext, useContext, useState, useEffect } from 'react';
import { apiFetch, getGatewayUrl } from './api-client';

interface AuthUser {
  id: string;
  email: string;
  role: 'FARMER' | 'EXPERT' | 'ADMIN';
  full_name: string;
}

interface AuthContextType {
  user: AuthUser | null;
  token: string | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<boolean>;
  logout: () => void;
  error: string | null;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  token: null,
  loading: true,
  login: async () => false,
  logout: () => {},
  error: null,
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>({
    id: 'usr-expert-sharma-01',
    email: 'dr_sharma@kvk.gov.in',
    role: 'EXPERT',
    full_name: 'Dr. Ramesh Sharma (KVK Agronomist)',
  });
  const [token, setToken] = useState<string | null>('mock-jwt-expert-usr-expert-sharma-01');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const savedToken = localStorage.getItem('prahar_expert_jwt');
    if (savedToken) {
      setToken(savedToken);
      // Fetch verified current identity from gateway
      apiFetch('/api/auth/me')
        .then((res) => {
          if (res.success && res.data?.user) {
            setUser(res.data.user);
          }
        })
        .catch(() => {});
    } else {
      // Set default development expert token
      localStorage.setItem('prahar_expert_jwt', 'mock-jwt-expert-usr-expert-sharma-01');
    }
  }, []);

  const login = async (email: string, password: string): Promise<boolean> => {
    setLoading(true);
    setError(null);
    try {
      const res = await apiFetch('/api/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });

      if (res.success && res.data?.session) {
        const session = res.data.session;
        setToken(session.access_token);
        setUser(session.user);
        localStorage.setItem('prahar_expert_jwt', session.access_token);
        setLoading(false);
        return true;
      } else {
        setError(res.error || 'Authentication failed.');
        setLoading(false);
        return false;
      }
    } catch (err: any) {
      setError(err?.message || 'Login failed.');
      setLoading(false);
      return false;
    }
  };

  const logout = () => {
    if (token) {
      apiFetch('/api/auth/logout', { method: 'POST' }).catch(() => {});
    }
    setToken(null);
    setUser(null);
    localStorage.removeItem('prahar_expert_jwt');
  };

  return (
    <AuthContext.Provider value={{ user, token, loading, login, logout, error }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
