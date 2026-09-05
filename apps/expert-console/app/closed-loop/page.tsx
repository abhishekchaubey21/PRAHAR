'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

interface VerificationRecord {
  verification_id: string;
  zone_id: string;
  action_id: string;
  pre_moisture: number;
  post_moisture: number;
  moisture_delta: number;
  resolved: boolean;
  verification_timestamp: string;
  summary_en: string;
  summary_hi: string;
}

const DEMO_VERIFICATIONS: VerificationRecord[] = [
  {
    verification_id: 'verif-demo-01',
    zone_id: 'DEMO-ZONE-02',
    action_id: 'action-irr-demo-zone-02-01',
    pre_moisture: 16.8,
    post_moisture: 28.5,
    moisture_delta: 11.7,
    resolved: true,
    verification_timestamp: '2026-09-05T18:30:00Z',
    summary_en: 'Zone DEMO-ZONE-02 remediation verified: Moisture improved from 16.8% to 28.5% (Δ +11.7%). Resolution status: SUCCESS.',
    summary_hi: 'ज़ोन DEMO-ZONE-02 उपचार का सत्यापन: नमी 16.8% से बढ़कर 28.5% हो गई (बदलाव +11.7%)। समाधान स्थिति: सफल।',
  },
];

export default function ClosedLoopPage() {
  const [verifications, setVerifications] = useState<VerificationRecord[]>(DEMO_VERIFICATIONS);
  const [actionId, setActionId] = useState('');
  const [statusMsg, setStatusMsg] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetch('http://localhost:3001/api/remediation/verifications')
      .then((res) => res.json())
      .then((data) => {
        if (data.success && data.data.length > 0) {
          setVerifications(data.data);
        }
      })
      .catch(() => {});
  }, []);

  const executeIntervention = async () => {
    if (!actionId) {
      setStatusMsg('Please provide an approved action_id.');
      return;
    }
    setLoading(true);
    try {
      const res = await fetch('http://localhost:3001/api/remediation/execute', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action_id: actionId }),
      });
      const data = await res.json();
      if (data.success) {
        setStatusMsg(`Action '${actionId}' executed successfully by rover. Proceed to Verify Re-Scan.`);
      } else {
        setStatusMsg(`Execution failed: ${data.data?.message || data.error}`);
      }
    } catch (err: any) {
      setStatusMsg(`Simulator connection error: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const triggerVerification = async () => {
    if (!actionId) {
      setStatusMsg('Please provide an action_id to verify.');
      return;
    }
    setLoading(true);
    try {
      const res = await fetch('http://localhost:3001/api/remediation/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action_id: actionId }),
      });
      const data = await res.json();
      if (data.success) {
        setStatusMsg(`Verification complete! Delta: +${data.data.moisture_delta}%. Resolved: ${data.data.resolved}`);
        setVerifications((prev) => [data.data, ...prev]);
      } else {
        setStatusMsg(`Verification error: ${data.error}`);
      }
    } catch (err: any) {
      setStatusMsg(`Simulator connection error: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <div>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '6px' }}>
          Closed-Loop Remediation & Re-Verification
        </h1>
        <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
          Genuine before/after verification workflow linking AI detection to verified physical outcome.
        </p>
      </div>

      {/* Process Flow Banner */}
      <div className="card" style={{ background: 'var(--bg-secondary)', borderColor: 'var(--border-color)' }}>
        <h3 className="card-title" style={{ fontSize: '0.95rem', marginBottom: '10px' }}>
          Approved Safety-Gated Execution Loop:
        </h3>
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', fontSize: '0.8rem', color: 'var(--text-muted)' }}>
          <span className="badge badge-low">1. SCAN</span> &rarr;
          <span className="badge badge-low">2. INGEST</span> &rarr;
          <span className="badge badge-low">3. DECISION</span> &rarr;
          <span className="badge badge-medium">4. RECOMMENDATION</span> &rarr;
          <span className="badge badge-high">5. APPROVAL GATE</span> &rarr;
          <span className="badge badge-low">6. IRRIGATE</span> &rarr;
          <span className="badge badge-low">7. RE-SCAN</span> &rarr;
          <span className="badge badge-low" style={{ background: 'var(--accent-emerald-glow)', color: 'var(--accent-emerald)' }}>8. VERIFY</span>
        </div>
      </div>

      {/* Manual Execution & Verification Controller */}
      <div className="card">
        <h3 className="card-title" style={{ marginBottom: '12px' }}>
          Execute & Verify Approved Remediation
        </h3>
        <div style={{ display: 'flex', gap: '12px', alignItems: 'center', flexWrap: 'wrap' }}>
          <input
            type="text"
            placeholder="Approved Action ID (e.g. action-irr-demo-zone-02-...)"
            value={actionId}
            onChange={(e) => setActionId(e.target.value)}
            style={{
              background: 'var(--bg-primary)',
              border: '1px solid var(--border-color)',
              color: 'var(--text-primary)',
              padding: '8px 12px',
              borderRadius: '6px',
              minWidth: '320px',
              fontSize: '0.9rem',
            }}
          />
          <button className="btn" disabled={loading} onClick={executeIntervention}>
            Execute Action
          </button>
          <button className="btn btn-outline" disabled={loading} onClick={triggerVerification}>
            Verify (Re-Scan & Compare)
          </button>
        </div>
        {statusMsg && (
          <p style={{ marginTop: '12px', fontSize: '0.85rem', color: 'var(--accent-emerald)' }}>
            {statusMsg}
          </p>
        )}
      </div>

      {/* Verification Records Table */}
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">Before vs After Verification Records</h3>
          <span className="badge" style={{ background: 'var(--accent-emerald-glow)', color: 'var(--accent-emerald)' }}>
            {verifications.length} Verified
          </span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          {verifications.map((v) => (
            <div
              key={v.verification_id}
              style={{
                background: 'var(--bg-secondary)',
                border: '1px solid var(--border-color)',
                borderRadius: '8px',
                padding: '16px',
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                <strong>{v.zone_id} — Remediation Verification</strong>
                <span className={`badge ${v.resolved ? 'badge-low' : 'badge-high'}`} style={v.resolved ? { background: 'var(--accent-emerald-glow)', color: 'var(--accent-emerald)' } : {}}>
                  {v.resolved ? 'RESOLVED (SUCCESS)' : 'INCOMPLETE'}
                </span>
              </div>

              <div style={{ display: 'flex', gap: '24px', fontSize: '0.85rem', marginBottom: '10px' }}>
                <div>Pre-Moisture: <strong style={{ color: 'var(--accent-rose)' }}>{v.pre_moisture}%</strong></div>
                <div>Post-Moisture: <strong style={{ color: 'var(--accent-emerald)' }}>{v.post_moisture}%</strong></div>
                <div>Moisture Delta: <strong>+{v.moisture_delta}%</strong></div>
                <div>Verified: {new Date(v.verification_timestamp).toLocaleTimeString()}</div>
              </div>

              <p style={{ fontSize: '0.85rem', color: 'var(--text-primary)', marginBottom: '4px' }}>
                {v.summary_en}
              </p>
              <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontStyle: 'italic' }}>
                {v.summary_hi}
              </p>
            </div>
          ))}
        </div>
      </div>

      {/* Field Evidence Report Card */}
      <div className="card" style={{ borderColor: 'var(--accent-sky)' }}>
        <div className="card-header">
          <div>
            <h3 className="card-title" style={{ color: 'var(--accent-sky)' }}>
              PRAHAR Field Evidence Report
            </h3>
            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
              Report ID: rep-demo-zone-02-latest &bull; Informational Field Verification
            </span>
          </div>
          <span className="badge badge-low" style={{ background: 'var(--accent-emerald-glow)', color: 'var(--accent-emerald)' }}>
            VERIFIED OUTCOME
          </span>
        </div>

        <div style={{ background: 'var(--bg-secondary)', padding: '14px', borderRadius: '8px', fontSize: '0.85rem', marginBottom: '12px' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '10px', marginBottom: '10px' }}>
            <div>Farm: <strong>Kisan Demo Farm Alpha</strong></div>
            <div>Target Zone: <strong>DEMO-ZONE-02</strong></div>
            <div>Issue: <strong>Severe Water Stress (16.5% moisture)</strong></div>
            <div>Action Taken: <strong>30s Micro-irrigation (~7.5L)</strong></div>
          </div>
          <div style={{ padding: '8px 12px', background: 'var(--bg-primary)', borderRadius: '6px', marginBottom: '10px' }}>
            Outcome: Soil moisture elevated by <strong>+12.0%</strong> (from 16.5% to 28.5%). Water stress condition successfully resolved.
          </div>
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontStyle: 'italic', margin: 0 }}>
            NOTICE: This document is a PRAHAR-generated informational field evidence report produced from autonomous rover sensor observations and edge AI detections. It is NOT an official government certificate, certified statutory audit, or legal agricultural warranty.
          </p>
        </div>
      </div>

      <div>
        <Link href="/queue" className="btn btn-outline">
          &larr; Back to Triage Queue
        </Link>
      </div>
    </div>
  );
}
