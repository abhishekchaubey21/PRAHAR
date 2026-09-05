'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

export default function DashboardPage() {
  const [dashboard, setDashboard] = useState<any>(null);
  const [weather, setWeather] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Fetch Farm Risk Dashboard
    fetch('http://localhost:3001/api/analytics/farm-risk')
      .then((res) => res.json())
      .then((data) => {
        if (data.success) setDashboard(data.dashboard);
      })
      .catch(() => {});

    // Fetch Weather Context
    fetch('http://localhost:3001/api/weather/risk')
      .then((res) => res.json())
      .then((data) => {
        if (data.success) setWeather(data.weather);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '6px' }}>
            Farm Precision Overview & Risk Intelligence
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
            Kisan Demo Farm Alpha (3.5 Acres • Crop: Tomato) — Connected to Rover ROVER-DEMO-01
          </p>
        </div>
        {weather && (
          <div style={{
            background: 'var(--bg-secondary)',
            border: '1px solid var(--border-color)',
            padding: '8px 14px',
            borderRadius: '8px',
            fontSize: '0.85rem'
          }}>
            <span style={{ color: 'var(--accent-amber)', fontWeight: 600, marginRight: '8px' }}>
              {weather.provider_label}
            </span>
            &bull; {weather.temperature_c}°C, {weather.relative_humidity_pct}% humidity
          </div>
        )}
      </header>

      {/* Metrics Row with Transparent Demo Composite Indicator */}
      <div className="grid grid-cols-3">
        {/* Composite Indicator Card */}
        <div className="card" style={{ borderColor: 'var(--accent-emerald)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div className="metric-label" style={{ fontWeight: 600 }}>
              PRAHAR Composite Indicator — Demo Metric
            </div>
            <span className="badge badge-low" style={{ fontSize: '0.7rem' }}>
              PROTOTYPE
            </span>
          </div>
          <div className="metric-val" style={{ color: 'var(--accent-emerald)' }}>
            {dashboard ? `${dashboard.composite_indicator.score_out_of_100}/100` : '70/100'}
          </div>
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '8px' }}>
            Formula: (Moisture 35% + Disease 25% + Pest 20% + Heat 20%). Demo indicator for prototype scoring; not scientifically validated agronomic truth.
          </p>
        </div>

        <div className="card">
          <div className="metric-label">Active Field Alerts</div>
          <div className="metric-val" style={{ color: 'var(--accent-amber)' }}>
            {dashboard ? dashboard.active_alerts_count : 2}
          </div>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '8px' }}>
            Zone 2: Low Soil Moisture (17.5%) &bull; Zone 3: Early Blight Risk
          </p>
        </div>

        <div className="card">
          <div className="metric-label">Rover Fleet Status</div>
          <div className="metric-val" style={{ color: 'var(--accent-emerald)' }}>ONLINE</div>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '8px' }}>
            SIMULATED ROVER &bull; Battery: 95.0% &bull; Gateway: :3001
          </p>
        </div>
      </div>

      {/* Farm Risk Conditions Breakdown */}
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">Categorical Farm Risk Intelligence</h2>
          <span className="badge" style={{ background: 'var(--accent-emerald-glow)', color: 'var(--accent-emerald)' }}>
            5 Risk Dimensions Monitored
          </span>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginTop: '10px' }}>
          <div style={{ background: 'var(--bg-secondary)', padding: '12px', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Water Condition</div>
            <div style={{ fontSize: '1.1rem', fontWeight: 'bold', color: 'var(--accent-rose)' }}>STRESSED</div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '4px' }}>Zone 2: 17.5% moisture</div>
          </div>

          <div style={{ background: 'var(--bg-secondary)', padding: '12px', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Crop Condition</div>
            <div style={{ fontSize: '1.1rem', fontWeight: 'bold', color: 'var(--accent-emerald)' }}>OPTIMAL</div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '4px' }}>Canopy foliage stable</div>
          </div>

          <div style={{ background: 'var(--bg-secondary)', padding: '12px', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Pest Pressure</div>
            <div style={{ fontSize: '1.1rem', fontWeight: 'bold', color: 'var(--accent-emerald)' }}>OPTIMAL</div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '4px' }}>No active infestations</div>
          </div>

          <div style={{ background: 'var(--bg-secondary)', padding: '12px', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Disease Risk</div>
            <div style={{ fontSize: '1.1rem', fontWeight: 'bold', color: 'var(--accent-amber)' }}>MODERATE</div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '4px' }}>Fungal humidity alert</div>
          </div>

          <div style={{ background: 'var(--bg-secondary)', padding: '12px', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Atmospheric Heat</div>
            <div style={{ fontSize: '1.1rem', fontWeight: 'bold', color: 'var(--accent-amber)' }}>33.5°C ELEVATED</div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '4px' }}>Heat stress warning</div>
          </div>
        </div>
      </div>

      {/* Quick Navigation */}
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">Operational Navigation</h2>
        </div>
        <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
          <Link href="/queue" className="btn">
            Open Triage Queue & WHY Layer
          </Link>
          <Link href="/closed-loop" className="btn btn-outline">
            Closed-Loop Verification & Field Evidence Report
          </Link>
          <Link href="/fleet" className="btn btn-outline">
            Fleet Telemetry & Commands
          </Link>
        </div>
      </div>
    </div>
  );
}
