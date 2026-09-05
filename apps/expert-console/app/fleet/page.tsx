'use client';

import { useState } from 'react';
import Link from 'next/link';

export default function FleetTelemetryPage() {
  const [lastAck, setLastAck] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const sendCommand = async (type: string, payload: any = {}) => {
    setLoading(true);
    const commandId = `web-cmd-${Date.now()}`;
    try {
      const res = await fetch('http://localhost:3001/api/rover/command', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          command_id: commandId,
          rover_id: 'ROVER-DEMO-01',
          command_type: type,
          payload,
        }),
      });
      const data = await res.json();
      setLastAck(JSON.stringify(data, null, 2));
    } catch (err: any) {
      setLastAck(`Simulator connection error: ${err?.message || err}. (Ensure simulator is running on :3001)`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <div>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '6px' }}>
          Rover Fleet Telemetry & Commands
        </h1>
        <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
          Hardware abstraction gateway monitor and simulated actuator control.
        </p>
      </div>

      <div className="grid grid-cols-3">
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">ROVER-DEMO-01</h3>
            <span className="badge badge-success">
              SIMULATED ROVER
            </span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '0.9rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--border-subtle)', paddingBottom: '6px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Current Zone</span>
              <strong style={{ color: 'var(--accent-emerald)' }}>DEMO-ZONE-01</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--border-subtle)', paddingBottom: '6px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Battery Level</span>
              <strong style={{ color: 'var(--text-primary)' }}>95.0%</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--border-subtle)', paddingBottom: '6px' }}>
              <span style={{ color: 'var(--text-muted)' }}>State</span>
              <strong style={{ color: 'var(--accent-sky)' }}>IDLE</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: 'var(--text-muted)' }}>Gateway</span>
              <strong style={{ color: 'var(--text-secondary)' }}>:3001 (REST/SSE)</strong>
            </div>
          </div>
        </div>

        <div className="card" style={{ gridColumn: 'span 2' }}>
          <div className="card-header">
            <h3 className="card-title">Simulate Rover Commands</h3>
          </div>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginBottom: '14px' }}>
            Commands are validated for idempotency via unique <code>command_id</code> and strict safety bounds.
          </p>
          <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
            <button
              className="btn"
              disabled={loading}
              onClick={() => sendCommand('START_SCAN', { zone_id: 'DEMO-ZONE-01' })}
            >
              Start Scan (Zone 1)
            </button>
            <button
              className="btn btn-outline"
              disabled={loading}
              onClick={() => sendCommand('RE_SCAN', { zone_id: 'DEMO-ZONE-02' })}
            >
              Re-Scan (Zone 2)
            </button>
            <button
              className="btn btn-outline"
              disabled={loading}
              onClick={() => sendCommand('IRRIGATE', { zone_id: 'DEMO-ZONE-02', duration_seconds: 30, approved_by: 'dr_sharma_kvk_expert' })}
            >
              Simulate Irrigation (30s)
            </button>
            <button
              className="btn btn-outline"
              style={{ borderColor: 'var(--accent-rose)', color: 'var(--accent-rose)' }}
              disabled={loading}
              onClick={() => sendCommand('STOP', { reason: 'Operator Emergency Pause' })}
            >
              Emergency STOP
            </button>
            <button
              className="btn btn-outline"
              disabled={loading}
              onClick={() => sendCommand('STATUS')}
            >
              Query Status
            </button>
          </div>
        </div>
      </div>

      {lastAck && (
        <div className="card">
          <h3 className="card-title" style={{ marginBottom: '8px' }}>Last Simulator Gateway Response:</h3>
          <pre style={{ background: 'var(--bg-secondary)', padding: '12px', borderRadius: '6px', fontSize: '0.85rem', overflowX: 'auto' }}>
            {lastAck}
          </pre>
        </div>
      )}

      <div>
        <Link href="/" className="btn btn-outline" style={{ display: 'inline-block' }}>
          &larr; Back to Dashboard
        </Link>
      </div>
    </div>
  );
}
