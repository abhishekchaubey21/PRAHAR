'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { apiFetch } from '../lib/api-client';

export default function DashboardPage() {
  const [dashboard, setDashboard] = useState<any>(null);
  const [weather, setWeather] = useState<any>(null);
  const [alertSummary, setAlertSummary] = useState<{ active: number; resolved: number }>({ active: 0, resolved: 2 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Fetch Farm Risk Dashboard
    apiFetch('/api/analytics/farm-risk')
      .then((res) => {
        if (res.success && res.data) {
          setDashboard(res.data.dashboard || res.data);
        }
      })
      .catch(() => {});

    // Fetch Weather Context
    apiFetch('/api/weather/risk')
      .then((res) => {
        if (res.success && res.data) {
          setWeather(res.data.weather || res.data);
        }
      })
      .catch(() => {});

    // Fetch alerts to compute accurate active vs resolved counts
    apiFetch('/api/alerts')
      .then((res) => {
        if (res.success && Array.isArray(res.data)) {
          const active = res.data.filter((a: any) => a.status !== 'RESOLVED').length;
          const resolved = res.data.filter((a: any) => a.status === 'RESOLVED').length;
          setAlertSummary({ active, resolved });
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '26px' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '14px' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '6px' }}>
            <h1 style={{ fontSize: '1.85rem', fontWeight: 800, letterSpacing: '-0.5px' }}>
              Farm Precision Overview &amp; Risk Intelligence
            </h1>
            <span className="badge badge-success" style={{ fontSize: '0.72rem' }}>
              DEMO MONITORING
            </span>
          </div>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
            Kisan Demo Farm Alpha (3.5 Acres • Crop: Tomato) — Simulated Edge Rover &bull; Gateway :3001
          </p>
        </div>

        {weather ? (
          <div style={{
            background: 'var(--bg-secondary)',
            border: '1px solid var(--border-color)',
            padding: '10px 16px',
            borderRadius: '10px',
            fontSize: '0.85rem',
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            boxShadow: 'var(--shadow-card)',
          }}>
            <span className="badge badge-medium" style={{ fontSize: '0.72rem' }}>
              SIMULATION WEATHER (DEMO)
            </span>
            <span style={{ color: 'var(--text-secondary)' }}>
              {weather.temperature_c}°C &bull; {weather.relative_humidity_pct}% humidity &bull; 0mm rain
            </span>
          </div>
        ) : (
          <div style={{
            background: 'var(--bg-secondary)',
            border: '1px solid var(--border-color)',
            padding: '10px 16px',
            borderRadius: '10px',
            fontSize: '0.85rem',
          }}>
            <span className="badge badge-medium" style={{ fontSize: '0.72rem' }}>
              SIMULATION WEATHER (DEMO)
            </span>
            <span style={{ color: 'var(--text-secondary)', marginLeft: '8px' }}>
              33.5°C &bull; 45% humidity &bull; Deterministic Model
            </span>
          </div>
        )}
      </header>

      {/* Metrics Row with Transparent Demo Composite Indicator & Fixed Active vs Resolved Breakdown */}
      <div className="grid grid-cols-3">
        {/* Composite Indicator Card */}
        <div className="card" style={{ borderColor: 'var(--accent-emerald)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div className="metric-label" style={{ color: 'var(--accent-emerald)' }}>
              PRAHAR Composite Indicator — Demo Metric
            </div>
            <span className="badge badge-low" style={{ fontSize: '0.7rem' }}>
              PROTOTYPE / DEMO METRIC
            </span>
          </div>
          <div className="metric-val" style={{ color: 'var(--accent-emerald)' }}>
            {dashboard ? `${dashboard.composite_indicator.score_out_of_100}/100` : '86/100'}
          </div>
          <div style={{ fontSize: '0.82rem', color: 'var(--text-secondary)', fontWeight: 600, marginBottom: '6px' }}>
            Classification: {dashboard?.composite_indicator?.classification || 'OPTIMAL (Post-Remediation)'}
          </div>
          <p style={{ fontSize: '0.74rem', color: 'var(--text-muted)', lineHeight: 1.45, borderTop: '1px solid var(--border-subtle)', paddingTop: '8px' }}>
            Formula: (Moisture 35% + Disease 25% + Pest 20% + Heat 20%). Demo indicator for prototype scoring; not scientifically validated agronomic truth.
          </p>
        </div>

        {/* Active Field Alerts Card: Fixed Contradiction with Resolved Subtext */}
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div className="metric-label">Field Alert Status</div>
            <span className={`badge ${alertSummary.active > 0 ? 'badge-high' : 'badge-success'}`} style={{ fontSize: '0.7rem' }}>
              {alertSummary.active > 0 ? 'ATTENTION REQUIRED' : 'ALL CLEAR'}
            </span>
          </div>
          <div className="metric-val" style={{ color: alertSummary.active > 0 ? 'var(--accent-amber)' : 'var(--accent-emerald)' }}>
            {alertSummary.active} active &bull; {alertSummary.resolved} recently resolved
          </div>
          <div style={{ fontSize: '0.82rem', color: 'var(--text-secondary)', fontWeight: 600, marginBottom: '4px' }}>
            {alertSummary.active === 0
              ? 'Zone 2: Simulated micro-irrigation verified (16.4% → 28.4%) • Zone 3: Monitored'
              : 'Zone 2: Awaiting closed-loop simulated verification • Zone 3: Monitored'}
          </div>
          <p style={{ fontSize: '0.74rem', color: 'var(--text-muted)', borderTop: '1px solid var(--border-subtle)', paddingTop: '8px' }}>
            Historical alerts and remediation verifications remain archived in immutable audit log.
          </p>
        </div>

        {/* Rover Fleet Status Card: Clearly Labelled SIMULATED ROVER */}
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div className="metric-label">Rover Gateway Status</div>
            <span className="badge badge-success" style={{ fontSize: '0.7rem' }}>
              SIMULATED ROVER
            </span>
          </div>
          <div className="metric-val" style={{ color: 'var(--accent-emerald)' }}>
            ONLINE (IDLE)
          </div>
          <div style={{ fontSize: '0.82rem', color: 'var(--text-secondary)', fontWeight: 600, marginBottom: '4px' }}>
            Unit: ROVER-DEMO-01 &bull; Battery: 95.0%
          </div>
          <p style={{ fontSize: '0.74rem', color: 'var(--text-muted)', borderTop: '1px solid var(--border-subtle)', paddingTop: '8px' }}>
            Physical hardware simulated; command idempotency and physical safety boundaries enforced.
          </p>
        </div>
      </div>

      {/* Farm Risk Conditions Breakdown */}
      <div className="card">
        <div className="card-header">
          <div>
            <h2 className="card-title">Categorical Farm Risk Intelligence</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginTop: '2px' }}>
              Multi-sensor fusion across 5 core agronomic and meteorological risk vectors.
            </p>
          </div>
          <span className="badge" style={{ background: 'var(--accent-emerald-glow)', color: 'var(--accent-emerald)' }}>
            5 Risk Dimensions Monitored
          </span>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '14px', marginTop: '8px' }}>
          <div style={{ background: 'var(--bg-secondary)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-subtle)' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Water Condition</div>
            <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--accent-emerald)', margin: '4px 0' }}>OPTIMAL</div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary)' }}>Zone 2: 28.4% (Simulated Elevation +12%)</div>
          </div>

          <div style={{ background: 'var(--bg-secondary)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-subtle)' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Crop Foliage</div>
            <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--accent-emerald)', margin: '4px 0' }}>OPTIMAL</div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary)' }}>Guy 3 YOLOv8: Canopy healthy</div>
          </div>

          <div style={{ background: 'var(--bg-secondary)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-subtle)' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Pest Pressure</div>
            <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--accent-emerald)', margin: '4px 0' }}>OPTIMAL</div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary)' }}>Trap &amp; visual count: 0 pests</div>
          </div>

          <div style={{ background: 'var(--bg-secondary)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-subtle)' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Disease Outbreak</div>
            <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--accent-amber)', margin: '4px 0' }}>MODERATE</div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary)' }}>Fungal humidity risk: 48% RH</div>
          </div>

          <div style={{ background: 'var(--bg-secondary)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-subtle)' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Atmospheric Heat</div>
            <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--accent-amber)', margin: '4px 0' }}>33.5°C ELEVATED</div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary)' }}>Evapotranspiration alert</div>
          </div>
        </div>
      </div>

      {/* Quick Navigation / Call to Action */}
      <div className="card" style={{ background: 'var(--bg-secondary)' }}>
        <div className="card-header">
          <div>
            <h2 className="card-title">Console Operational Workflows</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginTop: '2px' }}>
              Direct access to expert triage, closed-loop remediation verification, and fleet control.
            </p>
          </div>
        </div>
        <div style={{ display: 'flex', gap: '14px', flexWrap: 'wrap' }}>
          <Link href="/queue" className="btn">
            Open Triage Queue &amp; WHY Layer &rarr;
          </Link>
          <Link href="/closed-loop" className="btn btn-outline">
            Closed-Loop Verification &amp; Evidence Report &rarr;
          </Link>
          <Link href="/fleet" className="btn btn-outline">
            Fleet Telemetry &amp; Commands &rarr;
          </Link>
        </div>
      </div>
    </div>
  );
}
