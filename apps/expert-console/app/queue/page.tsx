import Link from 'next/link';

interface TriageItem {
  id: string;
  zone_id: string;
  zone_name: string;
  hazard_type: string;
  hazard_name: string;
  confidence: number;
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  detected_at: string;
  sensor_context: {
    moisture_pct: number;
    temperature_c: number;
    humidity_pct: number;
    ph: number;
  };
  notes: string;
}

const DEMO_TRIAGE_ITEMS: TriageItem[] = [
  {
    id: 'det-001',
    zone_id: 'DEMO-ZONE-02',
    zone_name: 'Zone 2 - East Sector',
    hazard_type: 'WATER_STRESS',
    hazard_name: 'Severe Soil Moisture Depletion',
    confidence: 0.92,
    severity: 'HIGH',
    detected_at: '2026-09-05T18:00:00Z',
    sensor_context: {
      moisture_pct: 17.5,
      temperature_c: 34.0,
      humidity_pct: 42.0,
      ph: 6.5,
    },
    notes: 'Soil probe reading < 20% moisture. Turgor pressure loss in upper foliage.',
  },
  {
    id: 'det-002',
    zone_id: 'DEMO-ZONE-03',
    zone_name: 'Zone 3 - South Sector',
    hazard_type: 'DISEASE',
    hazard_name: 'Early Blight (Alternaria solani)',
    confidence: 0.86,
    severity: 'MEDIUM',
    detected_at: '2026-09-05T18:05:00Z',
    sensor_context: {
      moisture_pct: 32.0,
      temperature_c: 29.0,
      humidity_pct: 75.0,
      ph: 6.2,
    },
    notes: 'Concentric ring spots identified on basal leaves. High humidity microclimate.',
  },
];

export default function TriageQueuePage() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <div>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '6px' }}>
          Expert Triage Review Queue
        </h1>
        <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
          Flagged AI detections requiring human agronomist verification (P0 Review Interface).
        </p>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {DEMO_TRIAGE_ITEMS.map((item) => (
          <div key={item.id} className="card">
            <div className="card-header">
              <div>
                <span className={`badge badge-${item.severity.toLowerCase()}`} style={{ marginRight: '10px' }}>
                  {item.severity}
                </span>
                <strong style={{ fontSize: '1.1rem' }}>{item.hazard_name}</strong>
                <span style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginLeft: '10px' }}>
                  in {item.zone_name}
                </span>
              </div>
              <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                Confidence: <strong style={{ color: 'var(--text-primary)' }}>{(item.confidence * 100).toFixed(0)}%</strong>
              </div>
            </div>

            <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '14px' }}>
              {item.notes}
            </p>

            <div style={{ background: 'var(--bg-secondary)', padding: '12px', borderRadius: '8px', marginBottom: '16px', display: 'flex', gap: '24px', fontSize: '0.85rem' }}>
              <div>Moisture: <strong>{item.sensor_context.moisture_pct}%</strong></div>
              <div>Temp: <strong>{item.sensor_context.temperature_c}°C</strong></div>
              <div>Humidity: <strong>{item.sensor_context.humidity_pct}%</strong></div>
              <div>Soil pH: <strong>{item.sensor_context.ph}</strong></div>
            </div>

            <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
              <button className="btn" style={{ fontSize: '0.85rem' }}>
                Confirm Diagnosis
              </button>
              <button className="btn btn-outline" style={{ fontSize: '0.85rem' }}>
                Correct Classification
              </button>
              <button className="btn btn-outline" style={{ fontSize: '0.85rem', borderColor: 'var(--accent-rose)', color: 'var(--accent-rose)' }}>
                Escalate to Senior Agronomist
              </button>
            </div>
          </div>
        ))}
      </div>

      <div>
        <Link href="/" className="btn btn-outline" style={{ display: 'inline-block' }}>
          &larr; Back to Dashboard
        </Link>
      </div>
    </div>
  );
}
