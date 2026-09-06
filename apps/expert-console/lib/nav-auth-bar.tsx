'use client';

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { AuthProvider, useAuth } from './auth-context';
import { apiFetch } from './api-client';

function NavAuthContent() {
  const { user, login, logout, error } = useAuth();
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [email, setEmail] = useState('dr_sharma@kvk.gov.in');
  const [password, setPassword] = useState('Expert@123');

  // Phase 6B-1: In-App Notification State
  const [unreadCount, setUnreadCount] = useState<number>(0);
  const [showDropdown, setShowDropdown] = useState<boolean>(false);
  const [notifications, setNotifications] = useState<any[]>([]);
  const [loadingNotifs, setLoadingNotifs] = useState<boolean>(false);

  useEffect(() => {
    if (!user) return;
    let isMounted = true;
    const fetchUnread = async () => {
      try {
        const res = await apiFetch('/api/notifications/unread-count');
        if (isMounted && res.success && res.data && typeof res.data.count === 'number') {
          setUnreadCount(res.data.count);
        }
      } catch (_) {}
    };
    fetchUnread();
    const interval = setInterval(fetchUnread, 15000);
    return () => {
      isMounted = false;
      clearInterval(interval);
    };
  }, [user]);

  const toggleDropdown = async () => {
    if (!showDropdown) {
      setLoadingNotifs(true);
      try {
        const res = await apiFetch('/api/notifications?limit=10');
        if (res.success && Array.isArray(res.data)) {
          setNotifications(res.data);
        }
      } catch (_) {}
      setLoadingNotifs(false);
    }
    setShowDropdown(!showDropdown);
  };

  const markNotificationRead = async (id: string) => {
    await apiFetch(`/api/notifications/${id}/read`, { method: 'PATCH' });
    setNotifications((prev) =>
      prev.map((n) => (n.id === id || n.notification_id === id ? { ...n, is_read: true } : n))
    );
    setUnreadCount((c) => Math.max(0, c - 1));
  };

  const markAllRead = async () => {
    await apiFetch('/api/notifications/read-all', { method: 'POST' });
    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })));
    setUnreadCount(0);
  };

  const handleLoginSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const success = await login(email, password);
    if (success) {
      setShowLoginModal(false);
    }
  };

  return (
    <>
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginLeft: 'auto', position: 'relative' }}>
        {user ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.82rem' }}>
            {/* Notification Bell Button */}
            <div style={{ position: 'relative' }}>
              <button
                key="expert_notification_bell"
                onClick={toggleDropdown}
                title="Notifications"
                style={{
                  background: showDropdown ? 'var(--bg-card)' : 'transparent',
                  border: '1px solid var(--border-color)',
                  color: unreadCount > 0 ? 'var(--accent-emerald)' : 'var(--text-muted)',
                  borderRadius: '6px',
                  padding: '4px 8px',
                  cursor: 'pointer',
                  fontSize: '0.85rem',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                }}
              >
                <span>🔔</span>
                {unreadCount > 0 && (
                  <span
                    key="expert_unread_count_badge"
                    style={{
                      background: '#f43f5e',
                      color: '#fff',
                      fontSize: '0.68rem',
                      fontWeight: 700,
                      borderRadius: '10px',
                      padding: '1px 5px',
                    }}
                  >
                    {unreadCount}
                  </span>
                )}
              </button>

              {/* Notification Popover Dropdown */}
              {showDropdown && (
                <div
                  style={{
                    position: 'absolute',
                    top: 'calc(100% + 8px)',
                    right: 0,
                    width: '320px',
                    background: 'var(--bg-card)',
                    border: '1px solid var(--border-color)',
                    borderRadius: '8px',
                    boxShadow: 'var(--shadow-card)',
                    padding: '12px',
                    zIndex: 1000,
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                    <span style={{ fontWeight: 700, fontSize: '0.85rem' }}>Notifications</span>
                    {unreadCount > 0 && (
                      <button
                        onClick={markAllRead}
                        style={{
                          background: 'transparent',
                          border: 'none',
                          color: 'var(--accent-emerald)',
                          cursor: 'pointer',
                          fontSize: '0.72rem',
                          padding: 0,
                        }}
                      >
                        Mark all read
                      </button>
                    )}
                  </div>

                  {loadingNotifs ? (
                    <div style={{ textAlign: 'center', padding: '16px', color: 'var(--text-muted)', fontSize: '0.78rem' }}>
                      Loading notifications...
                    </div>
                  ) : notifications.length === 0 ? (
                    <div style={{ textAlign: 'center', padding: '16px', color: 'var(--text-muted)', fontSize: '0.78rem' }}>
                      No notifications available.
                    </div>
                  ) : (
                    <div style={{ maxHeight: '260px', overflowY: 'auto' }}>
                      {notifications.map((n) => (
                        <div
                          key={n.id || n.notification_id}
                          style={{
                            padding: '8px',
                            borderRadius: '6px',
                            marginBottom: '6px',
                            background: n.is_read ? 'transparent' : 'rgba(16, 185, 129, 0.08)',
                            borderLeft: n.is_read ? '2px solid var(--border-color)' : '2px solid var(--accent-emerald)',
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'flex-start',
                            fontSize: '0.78rem',
                          }}
                        >
                          <div style={{ flex: 1, marginRight: '6px' }}>
                            <div style={{ fontWeight: n.is_read ? 500 : 700, color: 'var(--text-primary)' }}>
                              {n.title}
                            </div>
                            <div style={{ color: 'var(--text-muted)', fontSize: '0.72rem', marginTop: '2px' }}>
                              {n.message}
                            </div>
                            {n.zone_id && (
                              <span style={{ fontSize: '0.68rem', color: 'var(--text-secondary)' }}>
                                Zone: {n.zone_id}
                              </span>
                            )}
                          </div>
                          {!n.is_read && (
                            <button
                              onClick={() => markNotificationRead(n.notification_id || n.id)}
                              title="Mark as read"
                              style={{
                                background: 'transparent',
                                border: 'none',
                                color: 'var(--accent-emerald)',
                                cursor: 'pointer',
                                fontSize: '0.8rem',
                                padding: '2px',
                              }}
                            >
                              ✓
                            </button>
                          )}
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>

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
