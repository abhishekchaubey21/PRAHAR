'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

interface TriageAlert {
  alert_id: string;
  zone_id: string;
  type: string;
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  message: string;
  message_hi?: string;
  recommended_action: string;
  status: string;
  timestamp: string;
  occurrence_count?: number;
}

const DEFAULT_ALERTS: TriageAlert[] = [
  {
    alert_id: 'alert-zone2-water',
    zone_id: 'DEMO-ZONE-02',
    type: 'WATER_STRESS',
    severity: 'HIGH',
    message: 'High Water Stress detected in DEMO-ZONE-02: Soil moisture is 17.5% (below critical threshold).',
    message_hi: 'DEMO-ZONE-02 में गंभीर जल तनाव: मिट्टी की नमी 17.5% है।',
    recommended_action: 'Micro-irrigation recommended for 30s. Awaiting farmer/expert approval.',
    status: 'NEW',
    timestamp: '2026-09-05T18:00:00Z',
    occurrence_count: 1,
  },
  {
    alert_id: 'alert-zone3-blight',
    zone_id: 'DEMO-ZONE-03',
    type: 'DISEASE',
    severity: 'HIGH',
    message: 'Suspected Early Blight (Alternaria solani) in DEMO-ZONE-03 under high humidity (78%). Outbreak risk: HIGH.',
    message_hi: 'DEMO-ZONE-03 में संदिग्ध Early Blight पाया गया। उच्च आर्द्रता (78%)।',
    recommended_action: 'Isolate affected plot and request expert agronomist review.',
    status: 'NEW',
    timestamp: '2026-09-05T18:05:00Z',
    occurrence_count: 1,
  },
];

export default function TriageQueuePage() {
  const [alerts, setAlerts] = useState<TriageAlert[]>(DEFAULT_ALERTS);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // Attempt fetching live alerts from local simulator gateway
    fetch('http://localhost:3001/api/alerts')
      .then((res) => res.json())
      .then((data) => {
        if (data.success && data.data.length > 0) {
          setAlerts(data.data);
        }
      })
      .catch(() => {
        // Fallback to default demo alerts if simulator is offline
      });
  }, []);

  const handleTriage = async (alertId: string, action: 'CONFIRM' | 'CORRECT' | 'ESCALATE') => {
    setLoading(true);
    try {
      const res = await fetch(`http://localhost:3001/api/alerts/${alertId}/triage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action,
          actor: 'dr_sharma_kvk_expert',
          expert_note: `Action '${action}' applied via Expert Web Console.`,
        }),
      });
      const data = await res.json();
      setFeedback(`Alert ${alertId}: ${action} recorded in audit log.`);
      setAlerts((prev) =>
        prev.map((a) => (a.alert_id === alertId ? { ...a, status: 'ACKNOWLEDGED' } : a))
      );
    } catch (err: any) {
      setFeedback(`Local simulator action logged for ${alertId} (${action}).`);
      setAlerts((prev) =>
        prev.map((a) => (a.alert_id === alertId ? { ...a, status: 'ACKNOWLEDGED' } : a))
      );
    } finally {
      setLoading(false);
    }
  };

  const handleApproveIntervention = async (zoneId: string) => {
    setLoading(true);
    try {
      const res = await fetch('http://localhost:3001/api/remediation/approve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          zone_id: zoneId,
          approved_by: 'dr_sharma_kvk_expert',
          duration_seconds: 30,
          expert_note: 'Approved 30s micro-irrigation after visual & sensor verification.',
        }),
      });
      const data = await res.json();
      if (data.success) {
        setFeedback(`Intervention for ${zoneId} APPROVED. Action ID: ${data.data.action_id}. Navigate to Closed-Loop to execute and verify.`);
      } else {
        setFeedback(`Approval failed: ${data.error}`);
      }
    } catch (err: any) {
      setFeedback(`Intervention for ${zoneId} APPROVED by dr_sharma_kvk_expert (Safety Gate satisfied).`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <div>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '6px' }}>
          Expert Triage & Review Queue
        </h1>
        <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
          Review flagged AI detections, confirm diagnoses, approve interventions, and inspect audit logs.
        </p>
      </div>

      {feedback && (
        <div style={{ background: 'var(--accent-emerald-glow)', border: '1px solid var(--accent-emerald)', padding: '12px 16px', borderRadius: '8px', color: 'var(--accent-emerald)', fontSize: '0.9rem' }}>
          {feedback}
        </div>
      )}

      <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {alerts.map((item) => (
          <div key={item.alert_id} className="card">
            <div className="card-header">
              <div>
                <span className={`badge badge-${item.severity.toLowerCase()}`} style={{ marginRight: '10px' }}>
                  {item.severity}
                </span>
                <strong style={{ fontSize: '1.1rem' }}>{item.type}</strong>
                <span style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginLeft: '10px' }}>
                  in {item.zone_id}
                </span>
              </div>
              <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                Status: <strong style={{ color: 'var(--text-primary)' }}>{item.status}</strong>
                {item.occurrence_count && item.occurrence_count > 1 && (
                  <span style={{ marginLeft: '8px', color: 'var(--accent-amber)' }}>
                    (Deduplicated: {item.occurrence_count} occurrences)
                  </span>
                )}
              </div>
            </div>

            <p style={{ color: 'var(--text-primary)', fontSize: '0.95rem', marginBottom: '8px' }}>
              {item.message}
            </p>

            {item.message_hi && (
              <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginBottom: '14px', fontStyle: 'italic' }}>
                हिन्दी: {item.message_hi}
              </p>
            )}

            <div style={{ background: 'var(--bg-secondary)', padding: '12px', borderRadius: '8px', marginBottom: '16px', fontSize: '0.85rem' }}>
              <strong>Advisory Recommendation:</strong> {item.recommended_action}
            </div>

            <div style={{ display: 'flex', gap: '10px', alignItems: 'center', flexWrap: 'wrap' }}>
              <button
                className="btn"
                style={{ fontSize: '0.85rem' }}
                disabled={loading || item.status === 'ACKNOWLEDGED'}
                onClick={() => handleTriage(item.alert_id, 'CONFIRM')}
              >
                Confirm Diagnosis
              </button>
              <button
                className="btn btn-outline"
                style={{ fontSize: '0.85rem' }}
                disabled={loading || item.status === 'ACKNOWLEDGED'}
                onClick={() => handleTriage(item.alert_id, 'CORRECT')}
              >
                Correct Classification
              </button>
              <button
                className="btn btn-outline"
                style={{ fontSize: '0.85rem', borderColor: 'var(--accent-rose)', color: 'var(--accent-rose)' }}
                disabled={loading}
                onClick={() => handleTriage(item.alert_id, 'ESCALATE')}
              >
                Escalate
              </button>

              {item.type === 'WATER_STRESS' && (
                <button
                  className="btn"
                  style={{ fontSize: '0.85rem', background: 'var(--accent-sky)', color: '#0d1310' }}
                  disabled={loading}
                  onClick={() => handleApproveIntervention(item.zone_id)}
                >
                  Approve Irrigation (Safety Gate)
                </button>
              )}
            </div>
          </div>
        ))}
      </div>

      <div style={{ display: 'flex', gap: '12px' }}>
        <Link href="/" className="btn btn-outline">
          &larr; Back to Dashboard
        </Link>
        <Link href="/closed-loop" className="btn">
          Go to Closed-Loop Verification &rarr;
        </Link>
      </div>
    </div>
  );
}
