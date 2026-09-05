/**
 * PRAHAR Expert Console — Authenticated API Client
 * Automatically attaches Supabase JWT Bearer token and targets configured gateway URL.
 */

const GATEWAY_URL = process.env.NEXT_PUBLIC_GATEWAY_URL || 'http://localhost:3001';

export async function apiFetch<T = any>(
  path: string,
  options: RequestInit = {}
): Promise<{ success: boolean; data?: T; error?: string; status: number }> {
  const token = typeof window !== 'undefined' ? localStorage.getItem('prahar_expert_jwt') : null;

  const headers = new Headers(options.headers || {});
  headers.set('Content-Type', 'application/json');

  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }

  const url = path.startsWith('http') ? path : `${GATEWAY_URL}${path}`;

  try {
    const res = await fetch(url, {
      ...options,
      headers,
    });

    const data = await res.json().catch(() => ({}));

    return {
      success: res.ok && data.success !== false,
      data: data.data || data,
      error: data.error,
      status: res.status,
    };
  } catch (err: any) {
    return {
      success: false,
      error: err?.message || 'Network connection failed.',
      status: 0,
    };
  }
}

export function getGatewayUrl(): string {
  return GATEWAY_URL;
}
