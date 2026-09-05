import Link from 'next/link';

export default function DashboardPage() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <header>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '6px' }}>
          Farm Precision Overview
        </h1>
        <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
          Demo Field Alpha (3.5 Acres • Crop: Tomato) — Connected to Rover ROVER-DEMO-01
        </p>
      </header>

      {/* Metrics Row */}
      <div className="grid grid-cols-3">
        <div className="card">
          <div className="metric-label">Active Flagged Hazards</div>
          <div className="metric-val" style={{ color: 'var(--accent-amber)' }}>2</div>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '8px' }}>
            1 Water Stress, 1 Suspected Early Blight
          </p>
        </div>

        <div className="card">
          <div className="metric-label">Monitored Zones</div>
          <div className="metric-val">4</div>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '8px' }}>
            Zone 1, Zone 2, Zone 3, Zone 4
          </p>
        </div>

        <div className="card">
          <div className="metric-label">Rover Fleet Status</div>
          <div className="metric-val" style={{ color: 'var(--accent-emerald)' }}>ONLINE</div>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '8px' }}>
            Simulator v0.1 • Battery: 95% • Port :3001
          </p>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">Phase 1 Foundation Actions</h2>
        </div>
        <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
          <Link href="/queue" className="btn">
            Open Triage Queue
          </Link>
          <Link href="/fleet" className="btn btn-outline">
            Inspect Rover Telemetry
          </Link>
        </div>
      </div>
    </div>
  );
}
