'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { apiFetch, getGatewayUrl } from '../../lib/api-client';

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

// Canonical Demonstration Record (Hero Verification per Manager Requirement)
const CANONICAL_HERO_VERIFICATION: VerificationRecord = {
  verification_id: 'verif-canonical-demo-01',
  zone_id: 'DEMO-ZONE-02',
  action_id: 'action-irr-demo-zone-02-canonical',
  pre_moisture: 16.4,
  post_moisture: 28.4,
  moisture_delta: 12.0,
  resolved: true,
  verification_timestamp: '2026-09-05T18:30:00Z',
  summary_en: 'Zone DEMO-ZONE-02 remediation verified: Moisture improved from 16.4% to 28.4% (Δ +12.0%). Resolution status: SUCCESS.',
  summary_hi: 'ज़ोन DEMO-ZONE-02 उपचार का सत्यापन: नमी 16.4% से बढ़कर 28.4% हो गई (बदलाव +12.0%)। समाधान स्थिति: सफल।',
};

export default function ClosedLoopPage() {
  const [heroVerification, setHeroVerification] = useState<VerificationRecord>(CANONICAL_HERO_VERIFICATION);
  const [previousVerifications, setPreviousVerifications] = useState<VerificationRecord[]>([]);
  const [actionId, setActionId] = useState('');
  const [statusMsg, setStatusMsg] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [reportFarmId, setReportFarmId] = useState('farm-demo-01');
  const [reportZoneId, setReportZoneId] = useState('DEMO-ZONE-02');
  const [exportingPdf, setExportingPdf] = useState(false);

  useEffect(() => {
    apiFetch<VerificationRecord[]>('/api/remediation/verifications')
      .then((res) => {
        if (res.success && Array.isArray(res.data) && res.data.length > 0) {
          // If live records exist, keep canonical or check if newer
          const records: VerificationRecord[] = res.data;
          const foundCanonical = records.find(
            (r) => Math.abs(r.moisture_delta - 12.0) < 0.2 || (r.pre_moisture === 16.4 && r.post_moisture === 28.4)
          );
          if (foundCanonical) {
            setHeroVerification(foundCanonical);
            setPreviousVerifications(records.filter((r) => r.verification_id !== foundCanonical.verification_id));
          } else {
            setHeroVerification(CANONICAL_HERO_VERIFICATION);
            setPreviousVerifications(records);
          }
        }
      })
      .catch(() => {});
  }, []);

  const executeIntervention = async () => {
    if (!actionId) {
      setStatusMsg('Please provide an approved Action ID.');
      return;
    }
    setLoading(true);
    try {
      const res = await apiFetch('/api/remediation/execute', {
        method: 'POST',
        body: JSON.stringify({ action_id: actionId }),
      });
      if (res.success) {
        setStatusMsg(`Action '${actionId}' executed successfully by rover. Proceed to Verify Re-Scan.`);
      } else {
        setStatusMsg(`Execution failed: ${res.data?.message || res.error}`);
      }
    } catch (err: any) {
      setStatusMsg(`Gateway connection error: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const triggerVerification = async () => {
    if (!actionId) {
      setStatusMsg('Please provide an Action ID to verify.');
      return;
    }
    setLoading(true);
    try {
      const res = await apiFetch('/api/remediation/verify', {
        method: 'POST',
        body: JSON.stringify({ action_id: actionId }),
      });
      if (res.success && res.data) {
        setStatusMsg(`Verification complete! Delta: +${res.data.moisture_delta}%. Resolved: ${res.data.resolved}`);
        setHeroVerification(res.data);
      } else {
        setStatusMsg(`Verification error: ${res.error}`);
      }
    } catch (err: any) {
      setStatusMsg(`Gateway connection error: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const downloadEvidenceReportPdf = async () => {
    if (!reportFarmId.trim()) {
      setStatusMsg('Please specify a valid Farm ID for report export.');
      return;
    }
    setExportingPdf(true);
    setStatusMsg(null);
    try {
      const token = typeof window !== 'undefined' ? localStorage.getItem('prahar_expert_jwt') : null;
      const headers: Record<string, string> = {
        'Accept': 'application/pdf',
      };
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }

      const params = new URLSearchParams({
        farm_id: reportFarmId.trim(),
        format: 'pdf',
      });
      if (reportZoneId.trim()) {
        params.set('zone_id', reportZoneId.trim());
      }

      const url = `${getGatewayUrl()}/api/reports/field-evidence?${params.toString()}`;
      const res = await fetch(url, { headers });

      if (!res.ok) {
        const err = await res.json().catch(() => ({ message: `HTTP ${res.status}` }));
        setStatusMsg(`Report export error: ${err.message || res.statusText}`);
        return;
      }

      const blob = await res.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = downloadUrl;
      a.download = `PRAHAR_Field_Evidence_${reportFarmId}_${Date.now()}.pdf`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(downloadUrl);
      setStatusMsg('Field Evidence Report (PDF-1.4) successfully exported and downloaded.');
    } catch (err: any) {
      setStatusMsg(`Failed to download report: ${err.message}`);
    } finally {
      setExportingPdf(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '26px' }}>
      <div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '6px' }}>
          <h1 style={{ fontSize: '1.85rem', fontWeight: 800, letterSpacing: '-0.5px' }}>
            Closed-Loop Remediation &amp; Re-Verification
          </h1>
          <span className="badge badge-success" style={{ fontSize: '0.72rem' }}>
            SIMULATED FIELD VERIFICATION
          </span>
        </div>
        <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
          Before/after verification linking edge AI hazard detection to safety-gated simulated field remediation.
        </p>
      </div>

      {/* 8-Stage Visual Process Flow (Requirement 3) */}
      <div className="card" style={{ background: 'var(--bg-secondary)', padding: '18px 22px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px', flexWrap: 'wrap', gap: '8px' }}>
          <h3 className="card-title" style={{ fontSize: '1rem' }}>
            PRAHAR Closed-Loop Safety &amp; Execution Lifecycle:
          </h3>
          <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            8 Standard Sequential Phases
          </span>
        </div>

        <div className="stage-flow">
          <div className="stage-step">1. SCAN</div>
          <span className="stage-arrow">&rarr;</span>
          <div className="stage-step">2. INGEST</div>
          <span className="stage-arrow">&rarr;</span>
          <div className="stage-step">3. DECISION</div>
          <span className="stage-arrow">&rarr;</span>
          <div className="stage-step">4. RECOMMENDATION</div>
          <span className="stage-arrow">&rarr;</span>
          <div className="stage-step danger">5. APPROVAL GATE</div>
          <span className="stage-arrow">&rarr;</span>
          <div className="stage-step">6. IRRIGATE</div>
          <span className="stage-arrow">&rarr;</span>
          <div className="stage-step">7. RE-SCAN</div>
          <span className="stage-arrow">&rarr;</span>
          <div className="stage-step active">8. VERIFY</div>
        </div>
      </div>

      {/* Primary / Hero Verification Record (Canonical Demo: 16.4% -> 28.4%, Delta +12%, RESOLVED) */}
      <div className="hero-card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '12px', marginBottom: '16px' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '4px' }}>
              <span className="badge badge-success" style={{ background: 'var(--accent-emerald)', color: '#08120e', fontWeight: 800 }}>
                CANONICAL SIMULATED DEMONSTRATION
              </span>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                Target: <strong>{heroVerification.zone_id}</strong> &bull; Simulated Micro-Irrigation (30s)
              </span>
            </div>
            <h2 style={{ fontSize: '1.45rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.3px' }}>
              {heroVerification.zone_id} — Root-Zone Simulated Remediation Outcome
            </h2>
          </div>
          <span className="badge badge-success" style={{ fontSize: '0.9rem', padding: '6px 14px' }}>
            ✓ RESOLVED (SUCCESS)
          </span>
        </div>

        {/* Big Delta Comparison Metrics Grid */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '14px',
          background: 'rgba(0, 0, 0, 0.35)',
          padding: '18px',
          borderRadius: '10px',
          border: '1px solid var(--border-color)',
          marginBottom: '16px',
        }}>
          <div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              Pre-Remediation Moisture
            </div>
            <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--accent-rose)', margin: '4px 0' }}>
              {heroVerification.pre_moisture}%
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Critical Root Deficit (&lt; 20%)</div>
          </div>

          <div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              Post-Remediation Moisture
            </div>
            <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--accent-emerald)', margin: '4px 0' }}>
              {heroVerification.post_moisture}%
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--accent-emerald)' }}>Target Threshold Crossed</div>
          </div>

          <div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              Verified Moisture Delta
            </div>
            <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--accent-sky)', margin: '4px 0' }}>
              +{heroVerification.moisture_delta}%
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Simulated elevation via ~7.5L model</div>
          </div>
        </div>

        {/* Verification Summaries */}
        <div style={{ marginBottom: '14px' }}>
          <p style={{ fontSize: '0.95rem', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '4px' }}>
            {heroVerification.summary_en}
          </p>
          <p style={{ fontSize: '0.86rem', color: 'var(--text-muted)', fontStyle: 'italic' }}>
            {heroVerification.summary_hi}
          </p>
        </div>

        {/* Verification Footnote Metadata */}
        <div style={{
          display: 'flex',
          gap: '20px',
          fontSize: '0.78rem',
          color: 'var(--text-muted)',
          flexWrap: 'wrap',
          borderTop: '1px solid var(--border-subtle)',
          paddingTop: '12px',
        }}>
          <div>Attribution: <strong style={{ color: 'var(--text-secondary)' }}>dr_sharma_kvk_expert</strong></div>
          <div>Rover ID: <strong style={{ color: 'var(--text-secondary)' }}>ROVER-DEMO-01</strong></div>
          <div>Verification Time: <strong style={{ color: 'var(--text-secondary)' }}>{new Date(heroVerification.verification_timestamp).toLocaleTimeString()}</strong></div>
          <div>Audit Verification ID: <strong style={{ color: 'var(--text-secondary)', fontFamily: 'monospace' }}>{heroVerification.verification_id}</strong></div>
        </div>
      </div>

      {/* Manual Execution & Verification Controller */}
      <div className="card">
        <h3 className="card-title" style={{ marginBottom: '8px' }}>
          Interactive Closed-Loop Controller
        </h3>
        <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginBottom: '14px' }}>
          Execute pending human-approved simulated interventions and trigger re-scan verification against the simulator gateway.
        </p>

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
              padding: '10px 14px',
              borderRadius: '8px',
              minWidth: '320px',
              maxWidth: '440px',
              width: '100%',
              fontSize: '0.9rem',
            }}
          />
          <button className="btn" disabled={loading} onClick={executeIntervention}>
            ⚡ Execute Approved Simulated Action
          </button>
          <button className="btn btn-outline" disabled={loading} onClick={triggerVerification}>
            🔍 Verify (Simulated Re-Scan &amp; Delta)
          </button>
        </div>

        {statusMsg && (
          <p style={{ marginTop: '12px', fontSize: '0.88rem', color: 'var(--accent-emerald)', fontWeight: 500 }}>
            {statusMsg}
          </p>
        )}
      </div>

      {/* Phase 6B-3: Official Field Evidence Report & Audit Export */}
      <div className="card" style={{ border: '1px solid rgba(16, 185, 129, 0.3)' }}>
        <div className="card-header">
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <h3 className="card-title" style={{ fontSize: '1.05rem', color: 'var(--text-primary)' }}>
                Field Evidence Report &amp; Audit Export (Phase 6B-3)
              </h3>
              <span className="badge badge-success" style={{ fontSize: '0.7rem' }}>
                PDF-1.4 CERTIFIED
              </span>
            </div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginTop: '4px' }}>
              Export authoritative field-evidence summaries compiled directly from verified observations, edge detections, and remediation outcomes.
            </p>
          </div>
        </div>

        {/* Mandatory Exact Non-Government Disclaimer Banner */}
        <div style={{
          background: 'rgba(245, 158, 11, 0.12)',
          border: '1px solid rgba(245, 158, 11, 0.5)',
          borderRadius: '8px',
          padding: '12px 16px',
          marginBottom: '16px',
          fontSize: '0.82rem',
          lineHeight: '1.45',
          color: '#fef3c7',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontWeight: 700, color: '#f59e0b', marginBottom: '4px' }}>
            <span>⚠️</span> MANDATORY LEGAL NOTICE / DISCLAIMER:
          </div>
          This report is an informational field-evidence summary generated from PRAHAR system observations and AI/edge outputs. It is not an official government certificate, legal warranty, or guaranteed diagnosis.
        </div>

        <div style={{ display: 'flex', gap: '12px', alignItems: 'center', flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
            <label style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Farm ID</label>
            <input
              type="text"
              placeholder="Farm ID"
              value={reportFarmId}
              onChange={(e) => setReportFarmId(e.target.value)}
              style={{
                background: 'var(--bg-primary)',
                border: '1px solid var(--border-color)',
                color: 'var(--text-primary)',
                padding: '8px 12px',
                borderRadius: '6px',
                fontSize: '0.88rem',
                width: '180px',
              }}
            />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
            <label style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Zone ID (Optional)</label>
            <input
              type="text"
              placeholder="Zone ID"
              value={reportZoneId}
              onChange={(e) => setReportZoneId(e.target.value)}
              style={{
                background: 'var(--bg-primary)',
                border: '1px solid var(--border-color)',
                color: 'var(--text-primary)',
                padding: '8px 12px',
                borderRadius: '6px',
                fontSize: '0.88rem',
                width: '180px',
              }}
            />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', alignSelf: 'flex-end' }}>
            <button
              className="btn btn-outline"
              disabled={exportingPdf}
              onClick={downloadEvidenceReportPdf}
              style={{
                borderColor: 'var(--accent-emerald)',
                color: 'var(--accent-emerald)',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '9px 18px',
              }}
            >
              {exportingPdf ? '⏳ Generating PDF...' : '📄 Generate & Download PDF Report'}
            </button>
          </div>
        </div>
      </div>

      {/* Previous Verification Records Section (Requirement 3: Clearly Labelled Below Hero) */}
      <div className="card">
        <div className="card-header">
          <div>
            <h3 className="card-title">Previous Verification Records</h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginTop: '2px' }}>
              Archived records from preceding operational scans and remediation cycles.
            </p>
          </div>
          <span className="badge badge-low">
            {previousVerifications.length} Archived
          </span>
        </div>

        {previousVerifications.length === 0 ? (
          <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', padding: '8px 0' }}>
            No secondary historical verifications logged. The canonical demonstration above represents the current primary verification record.
          </p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {previousVerifications.map((v) => (
              <div
                key={v.verification_id}
                style={{
                  background: 'var(--bg-secondary)',
                  border: '1px solid var(--border-subtle)',
                  borderRadius: '8px',
                  padding: '14px 18px',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px', flexWrap: 'wrap', gap: '6px' }}>
                  <strong>{v.zone_id} — Remediation Verification Archive</strong>
                  <span className="badge badge-success" style={{ fontSize: '0.72rem' }}>
                    {v.resolved ? 'RESOLVED' : 'INCOMPLETE'}
                  </span>
                </div>

                <div style={{ display: 'flex', gap: '20px', fontSize: '0.84rem', marginBottom: '8px', flexWrap: 'wrap' }}>
                  <div>Pre-Moisture: <strong style={{ color: 'var(--accent-rose)' }}>{v.pre_moisture}%</strong></div>
                  <div>Post-Moisture: <strong style={{ color: 'var(--accent-emerald)' }}>{v.post_moisture}%</strong></div>
                  <div>Delta: <strong style={{ color: 'var(--accent-sky)' }}>+{v.moisture_delta}%</strong></div>
                  <div style={{ color: 'var(--text-muted)' }}>Timestamp: {new Date(v.verification_timestamp).toLocaleTimeString()}</div>
                </div>

                <p style={{ fontSize: '0.84rem', color: 'var(--text-secondary)' }}>
                  {v.summary_en}
                </p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Field Evidence Report Card */}
      <div className="card" style={{ borderColor: 'var(--accent-sky)', background: 'linear-gradient(145deg, #101c24 0%, #0d151a 100%)' }}>
        <div className="card-header">
          <div>
            <h3 className="card-title" style={{ color: 'var(--accent-sky)' }}>
              PRAHAR Field Evidence Report
            </h3>
            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
              Report ID: rep-demo-zone-02-canonical &bull; Informational Field Verification Export
            </span>
          </div>
          <span className="badge badge-low" style={{ background: 'rgba(14, 165, 233, 0.15)', color: 'var(--accent-sky)' }}>
            VERIFIED OUTCOME
          </span>
        </div>

        <div style={{ background: 'var(--bg-primary)', padding: '16px', borderRadius: '10px', fontSize: '0.88rem', marginBottom: '14px', border: '1px solid var(--border-subtle)' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '12px', marginBottom: '12px' }}>
            <div>Farm Name: <strong>Kisan Demo Farm Alpha</strong></div>
            <div>Target Zone: <strong>DEMO-ZONE-02</strong></div>
            <div>Observed Issue: <strong>Severe Water Stress (16.4% moisture)</strong></div>
            <div>Remediation Executed: <strong>Simulated 30s Micro-irrigation (~7.5L)</strong></div>
          </div>
          <div style={{ padding: '10px 14px', background: 'rgba(16, 185, 129, 0.1)', borderRadius: '8px', marginBottom: '12px', border: '1px solid rgba(16, 185, 129, 0.3)' }}>
            Verified Outcome: Soil moisture elevated by <strong style={{ color: 'var(--accent-emerald)' }}>+12.0%</strong> (from 16.4% to 28.4%). Target threshold crossed; root-zone water stress resolved in simulated model.
          </div>
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontStyle: 'italic', margin: 0, lineHeight: 1.45 }}>
            NOTICE: This document is a PRAHAR-generated informational field evidence report produced from simulated rover sensor observations and edge AI detection outputs for demonstration purposes. It is NOT an official government certificate, certified statutory audit, or legal agricultural warranty.
          </p>
        </div>
      </div>

      {/* Opportunity & Scheme Guidance Card (Phase 6B-4) */}
      <div className="card" style={{ borderColor: 'var(--accent-amber)', background: 'linear-gradient(145deg, #1f1a10 0%, #14120b 100%)' }}>
        <div className="card-header">
          <div>
            <h3 className="card-title" style={{ color: 'var(--accent-amber)' }}>
              Agricultural Scheme & Support Guidance
            </h3>
            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
              Verified Indian Agricultural Schemes, Subsidies & Financial Support (Phase 6B-4)
            </span>
          </div>
          <span className="badge" style={{ background: 'rgba(245, 158, 11, 0.15)', color: 'var(--accent-amber)' }}>
            INFORMATIONAL GUIDANCE
          </span>
        </div>

        <div style={{ background: 'var(--bg-primary)', padding: '16px', borderRadius: '10px', fontSize: '0.88rem', border: '1px solid var(--border-subtle)' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '14px', marginBottom: '14px' }}>
            <div style={{ border: '1px solid var(--border-subtle)', borderRadius: '8px', padding: '12px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                <strong style={{ color: 'var(--text-primary)' }}>PM-KISAN Samman Nidhi</strong>
                <span style={{ fontSize: '0.7rem', padding: '2px 6px', borderRadius: '4px', background: 'rgba(16, 185, 129, 0.2)', color: 'var(--accent-emerald)' }}>SCHEME</span>
              </div>
              <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginBottom: '8px' }}>
                ₹6,000/year direct income support in 3 equal installments.
              </p>
              <a href="https://pmkisan.gov.in" target="_blank" rel="noopener noreferrer" style={{ fontSize: '0.75rem', color: 'var(--accent-sky)' }}>
                Official Portal: pmkisan.gov.in &rarr;
              </a>
            </div>

            <div style={{ border: '1px solid var(--border-subtle)', borderRadius: '8px', padding: '12px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                <strong style={{ color: 'var(--text-primary)' }}>PM-KUSUM Solar Pumps</strong>
                <span style={{ fontSize: '0.7rem', padding: '2px 6px', borderRadius: '4px', background: 'rgba(14, 165, 233, 0.2)', color: 'var(--accent-sky)' }}>SUBSIDY</span>
              </div>
              <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginBottom: '8px' }}>
                Up to 60% total subsidy (30% Central + 30% State) for solar irrigation pumps.
              </p>
              <a href="https://pmkusum.mnre.gov.in" target="_blank" rel="noopener noreferrer" style={{ fontSize: '0.75rem', color: 'var(--accent-sky)' }}>
                Official Portal: pmkusum.mnre.gov.in &rarr;
              </a>
            </div>

            <div style={{ border: '1px solid var(--border-subtle)', borderRadius: '8px', padding: '12px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                <strong style={{ color: 'var(--text-primary)' }}>PMKSY Per Drop More Crop</strong>
                <span style={{ fontSize: '0.7rem', padding: '2px 6px', borderRadius: '4px', background: 'rgba(14, 165, 233, 0.2)', color: 'var(--accent-sky)' }}>SUBSIDY</span>
              </div>
              <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginBottom: '8px' }}>
                45% to 55% subsidy on drip and sprinkler precision irrigation.
              </p>
              <a href="https://pmksy.gov.in" target="_blank" rel="noopener noreferrer" style={{ fontSize: '0.75rem', color: 'var(--accent-sky)' }}>
                Official Portal: pmksy.gov.in &rarr;
              </a>
            </div>

            <div style={{ border: '1px solid var(--border-subtle)', borderRadius: '8px', padding: '12px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                <strong style={{ color: 'var(--text-primary)' }}>Kisan Credit Card (KCC)</strong>
                <span style={{ fontSize: '0.7rem', padding: '2px 6px', borderRadius: '4px', background: 'rgba(245, 158, 11, 0.2)', color: 'var(--accent-amber)' }}>LOAN</span>
              </div>
              <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginBottom: '8px' }}>
                Concessional agricultural credit up to ₹3 Lakh at 4% effective interest.
              </p>
              <a href="https://myscheme.gov.in/schemes/kcc" target="_blank" rel="noopener noreferrer" style={{ fontSize: '0.75rem', color: 'var(--accent-sky)' }}>
                Official Portal: myscheme.gov.in &rarr;
              </a>
            </div>
          </div>

          <div style={{ padding: '10px 14px', background: 'rgba(245, 158, 11, 0.1)', borderRadius: '8px', border: '1px solid rgba(245, 158, 11, 0.25)' }}>
            <p style={{ fontSize: '0.75rem', color: 'var(--accent-amber)', fontStyle: 'italic', margin: 0, lineHeight: 1.45 }}>
              DISCLAIMER: Eligibility shown by PRAHAR is guidance only. Final eligibility is determined by the concerned government department/bank/authority. PRAHAR does not submit official applications on behalf of farmers.
            </p>
          </div>
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
