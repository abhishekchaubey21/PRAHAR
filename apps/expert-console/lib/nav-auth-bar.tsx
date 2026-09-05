'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { AuthProvider, useAuth } from './auth-context';

function NavAuthContent() {
  const { user, login, logout, error } = useAuth();
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [email, setEmail] = useState('dr_sharma@kvk.gov.in');
  const [password, setPassword] = useState('Expert@123');

  const handleLoginSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const success = await login(email, password);
    if (success) {
      setShowLoginModal(false);
    }
  };

  return (
    <>
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginLeft: 'auto' }}>
        {user ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.82rem' }}>
            <span
              className="badge"
              style={{
                background: 'rgba(16, 185, 129, 0.2)',
                color: 'var(--accent-emerald)',
                fontWeight: 700,
                border: '1px solid var(--accent-emerald)',
                padding: '2px 8px',
                borderRadius: '6px',
              }}
            >
              {user.role}
            </span>
            <span style={{ color: 'var(--text-secondary)' }}>{user.full_name}</span>
            <button
              onClick={logout}
              style={{
                background: 'transparent',
                border: '1px solid var(--border-color)',
                color: 'var(--text-muted)',
                borderRadius: '6px',
                padding: '3px 8px',
                cursor: 'pointer',
                fontSize: '0.78rem',
              }}
            >
              Logout
            </button>
          </div>
        ) : (
          <button
            onClick={() => setShowLoginModal(true)}
            style={{
              background: 'var(--accent-emerald)',
              color: '#000',
              fontWeight: 700,
              border: 'none',
              borderRadius: '6px',
              padding: '6px 14px',
              cursor: 'pointer',
              fontSize: '0.82rem',
            }}
          >
            Expert Login
          </button>
        )}
      </div>

      {showLoginModal && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0, 0, 0, 0.75)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 9999,
          }}
        >
          <div
            style={{
              background: 'var(--bg-card)',
              border: '1px solid var(--border-color)',
              padding: '24px',
              borderRadius: '12px',
              width: '360px',
              boxShadow: 'var(--shadow-card)',
            }}
          >
            <h3 style={{ margin: '0 0 14px 0', fontSize: '1.2rem', fontWeight: 700 }}>
              Supabase Expert Authentication
            </h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginBottom: '16px' }}>
              Sign in with your verified agronomist or administrator credentials.
            </p>

            {error && (
              <div
                style={{
                  background: 'rgba(239, 68, 68, 0.15)',
                  border: '1px solid var(--accent-ruby)',
                  color: 'var(--accent-ruby)',
                  padding: '8px 12px',
                  borderRadius: '6px',
                  fontSize: '0.8rem',
                  marginBottom: '12px',
                }}
              >
                {error}
              </div>
            )}

            <form onSubmit={handleLoginSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.8rem', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                  Email
                </label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px 10px',
                    borderRadius: '6px',
                    background: 'var(--bg-primary)',
                    border: '1px solid var(--border-color)',
                    color: 'var(--text-primary)',
                  }}
                  required
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.8rem', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                  Password
                </label>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px 10px',
                    borderRadius: '6px',
                    background: 'var(--bg-primary)',
                    border: '1px solid var(--border-color)',
                    color: 'var(--text-primary)',
                  }}
                  required
                />
              </div>

              <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '8px' }}>
                <button
                  type="button"
                  onClick={() => setShowLoginModal(false)}
                  style={{
                    background: 'transparent',
                    border: '1px solid var(--border-color)',
                    color: 'var(--text-muted)',
                    borderRadius: '6px',
                    padding: '6px 12px',
                    cursor: 'pointer',
                  }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  style={{
                    background: 'var(--accent-emerald)',
                    color: '#000',
                    fontWeight: 700,
                    border: 'none',
                    borderRadius: '6px',
                    padding: '6px 14px',
                    cursor: 'pointer',
                  }}
                >
                  Sign In
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}

export function ExpertRootShell({ children }: { children: React.ReactNode }) {
  return (
    <AuthProvider>
      <nav className="navbar">
        <div className="nav-brand">
          <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ color: 'var(--text-primary)', fontWeight: 800, letterSpacing: '1px' }}>PRAHAR</span>
            <span style={{ color: 'var(--text-muted)', fontWeight: 400 }}>|</span>
            <span style={{ color: 'var(--accent-emerald)', fontWeight: 600, fontSize: '1.05rem' }}>Field Intelligence</span>
          </Link>
        </div>
        <div className="nav-links">
          <Link href="/" className="nav-link">Overview</Link>
          <Link href="/queue" className="nav-link">Triage Queue</Link>
          <Link href="/closed-loop" className="nav-link">Closed-Loop</Link>
          <Link href="/fleet" className="nav-link">Fleet Telemetry</Link>
        </div>
        <NavAuthContent />
      </nav>
      <main className="container">{children}</main>
    </AuthProvider>
  );
}
