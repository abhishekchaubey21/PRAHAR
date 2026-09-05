# PRAHAR — Precision Rover for Agricultural Hazard Analysis & Remediation
> *Smart India Hackathon (SIH) 2026 — PS #26180*  
> **Phase 1, 2 & 3 Delivered**: Engineering Foundation, Autonomous Rover Simulator, **AI Decision Layer (Rule-Based Fusion Engine)**, **Closed-Loop Remediation Workflow**, **Supabase Production Data Layer & RLS Policies**, **5-State Offline Synchronization Engine**, and **Frontend Real App Integration**.

---

## 1. Architecture Overview

PRAHAR combines autonomous ground-rover robotics with precision agricultural decision support, offline-first field synchronization, and auditable closed-loop verification.

```
d:/PRAHAR/
├── apps/
│   ├── farmer-app/              # Flutter mobile app (Dart 3 / Flutter 3)
│   │   ├── lib/core/            # 5-state offline storage, sync queue & theme
│   │   ├── lib/domain/          # Shared domain models (Zone, Alert, Verification)
│   │   ├── lib/screens/         # Outdoor-friendly UI with EN/HI toggle, sync bar & alerts
│   │   └── test/                # Automated Flutter widget & offline queue tests
│   │
│   └── expert-console/          # Next.js 14 (App Router) expert/admin console
│       ├── app/layout.tsx       # Shell layout & responsive navigation
│       ├── app/page.tsx         # Farm overview & quick metrics
│       ├── app/queue/page.tsx   # Expert triage queue with live audit trail
│       ├── app/closed-loop/     # Before/After remediation verification dashboard
│       └── app/fleet/page.tsx   # Fleet telemetry & live command simulator
│
├── packages/
│   └── shared/                  # Shared TypeScript contracts & validation schemas
│       ├── src/telemetry.ts     # Telemetry, GPS, sensor bundle types & validators
│       ├── src/detection.ts     # AI hazard detection types (Disease, Pest, Weed, etc.)
│       ├── src/commands.ts      # Command contracts & safety gate validation
│       ├── src/alert.ts         # Bilingual alert templates (EN/HI) & ingestion contracts
│       ├── src/decision.ts      # Centralized decision thresholds & verification models
│       ├── src/sync.ts          # 5-state offline sync contracts & conflict resolution
│       └── src/domain.ts        # Farmer, Farm, Zone entities
│
├── services/
│   └── rover-simulator/         # Autonomous Rover Simulator & Decision Gateway (v0.3)
│       ├── src/engine.ts        # Rover state machine & cycle coordinator
│       ├── src/decision-engine.ts # Rule-based fusion engine & confidence gating
│       ├── src/closed-loop.ts   # Closed-loop remediation & verification coordinator
│       ├── src/persistent-alert-store.ts # Dual-mode persistent store with JSON backup
│       ├── src/sync-engine.ts   # 5-state sync machine (retry, idempotency, conflicts)
│       ├── src/telemetry-gen.ts # Agronomic sensor generator (Moisture, Temp, Humidity, pH)
│       ├── src/detection-gen.ts # Synthetic vision AI hazard detection generator
│       ├── src/command-proc.ts  # Idempotency cache & physical safety enforcer
│       ├── src/server.ts        # HTTP & SSE REST API server (Port 3001)
│       └── src/cli.ts           # Interactive terminal CLI controller
│
├── supabase/
│   ├── migrations/              # Relational SQL schemas with indices & constraints
│   │   ├── 20260905000000_prahar_core_schema.sql           # Core tables
│   │   └── 20260905000001_phase3_production_data_and_rls.sql # RLS & Phase 3 tables
│   ├── seed.sql                 # Synthetic demo data (Demo Farmer, 4 Zones, Rover-01)
│   └── config.toml              # Supabase CLI configuration
│
├── tests/                       # Automated test suite (48 tests across 5 suites)
│   ├── rover-engine.test.ts     # State transitions & telemetry agronomic bounds
│   ├── command-idempotency.test.ts # Duplicate command ID rejection & safety checks
│   ├── offline-queue.test.ts    # Store-and-forward offline event buffering
│   ├── shared-contracts.test.ts # Contract schema validators
│   ├── decision-engine.test.ts  # Rule fusion, confidence gating & deduplication
│   ├── closed-loop-workflow.test.ts # Closed-loop remediation & verification
│   ├── phase3-persistence-rls.test.ts # Supabase schema, RLS policies & persistent store
│   ├── phase3-offline-sync.test.ts # 5-state sync, retry, duplicate sync, conflict resolution
│   └── phase3-e2e-demo.test.ts  # Complete 20-step lifecycle validation
│
├── package.json                 # Monorepo workspaces & development scripts
└── README.md                    # Local setup and architecture guide
```

---

## 2. Environment Variables & Security

This repository is **public**. Absolutely NO production secrets, API keys, service-role keys, passwords, or personal credentials are committed to Git. All services run out-of-the-box locally with safe simulated defaults and support environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `3001` | Rover Gateway & Ingestion HTTP Server Port |
| `ROVER_ID` | `ROVER-DEMO-01` | Hardware Identifier for Rover Instance |
| `SUPABASE_URL` | `http://localhost:54321` | Supabase / PostgreSQL API endpoint (optional) |
| `SUPABASE_ANON_KEY` | *(unassigned)* | Public anonymous client key (optional) |
| `SUPABASE_SERVICE_ROLE_KEY` | *(unassigned)* | Private ingestion key for Rover Gateway (optional) |

---

## 3. Database Architecture & Row Level Security (RLS)

### Schema Migrations (`supabase/migrations/`)
- `20260905000000_prahar_core_schema.sql`: Core tables for `farmers`, `farms`, `zones`, `sensor_readings`, `detections`, `alerts`, `rover_commands`, `rover_telemetry`, `offline_sync_events`.
- `20260905000001_phase3_production_data_and_rls.sql`:
  - `profiles`: Extends `auth.users` with roles: `FARMER`, `EXPERT`, `ADMIN`.
  - `remediation_actions`: Persistent record of approved physical interventions.
  - `remediation_verifications`: Genuine before/after verification records with `moisture_delta` and bilingual summaries.
  - `expert_audit_records`: Immutable audit log of all expert triage decisions and approval actions.
  - `offline_sync_events`: Enhanced with 5 states (`PENDING`, `SYNCING`, `SYNCED`, `FAILED`, `CONFLICT`), `idempotency_key UNIQUE`, `retry_count`, and `last_error`.

### Row Level Security (RLS) Policies
Row Level Security is enabled on **all 13 tables**:
1. **Farmers**: Can SELECT/UPDATE only their own profile, farms, zones, sensor readings, alerts, and verifications (`farmer_id = get_user_farmer_id()`).
2. **Experts**: Can inspect alerts and telemetry across their assigned cluster (`CLUSTER-DEMO-01`), execute triage (`CONFIRM`, `CORRECT`, `ESCALATE`), approve interventions, and insert immutable audit records.
3. **Admins**: Explicit administrative override across all tables.
4. **Rover Gateway**: Authenticated via `service_role` to insert sensor telemetry, detections, and sync events.

---

## 4. Offline-First Synchronization Architecture

The synchronization layer is designed for intermittent field connectivity, ensuring farmers and rovers remain fully operational without an internet connection:

### 5-State Machine
```
   ┌─────────┐
   │ PENDING │◄──────────(Retry < Max)──────────┐
   └────┬────┘                                   │
        │                                        │
        ▼ (Flush / Connect)                      │
   ┌─────────┐                                   │
   │ SYNCING │                                   │
   └────┬────┘                                   │
        ├─── (Ack / Success) ────────► ┌─────────┴┐
        │                              │  SYNCED  │
        ├─── (Push Rejected / Error) ─► ┌─────────┴┐
        │                              │  FAILED  │ (Retry >= Max)
        │                              └──────────┘
        └─── (Newer Server Version) ─► ┌──────────┐
                                       │ CONFLICT │ (LAST_WRITE_WINS)
                                       └──────────┘
```

1. **Local FIFO Queue**: Stores actions locally in `.prahar_data` or device cache.
2. **Idempotency Guarantee**: Every sync payload carries a unique `idempotency_key`. The server rejects duplicate processing safely and returns `is_duplicate: true`.
3. **Retry with Exponential Backoff**: Failed network requests automatically retry up to 5 times before transitioning to `FAILED`.
4. **Conflict Resolution**: `LAST_WRITE_WINS` policy compares ISO timestamps between client and server records, gracefully handling multi-device edge cases.
5. **Reconnect Detection**: Automatically buffers events while offline (`setOnline(false)`) and flushes when reconnected.

---

## 5. Decision Engine & Closed-Loop Safety Gate

### Safety Gate Invariant (Mandatory)
The decision engine **never** auto-triggers physical irrigation. Every physical action requires:
1. Explicit `approved_by` attribution (Farmer or Expert).
2. Rover safety validation (battery $> 10\%$, duration $\le 180$s, volume $\le 50$L).
3. Post-intervention re-scan and comparison with pre-intervention metrics.

### Closed-Loop Workflow
```
SCAN → INGEST → DECISION → RECOMMENDATION → FARMER/EXPERT APPROVAL → SAFETY VALIDATION → IRRIGATE → RE-SCAN → VERIFY
```

---

## 6. Local Setup & Running

### Step 1: Install Dependencies & Build Contracts
```bash
npm install
npm run build:shared
```

### Step 2: Run All Tests
```bash
# Runs 48 automated tests across 5 test suites
npm test

# Runs Flutter unit & widget tests
npm run flutter:test

# Builds Next.js Expert Console production bundle
npm --workspace=@prahar/expert-console run build
```

### Step 3: Run Live Services
```bash
# Terminal 1: Rover Simulator & Ingestion Gateway (Port 3001)
npm run dev:simulator

# Terminal 2: Expert Web Console (Port 3000)
npm run dev:expert

# Terminal 3: Farmer Mobile App (Flutter)
cd apps/farmer-app
flutter run
```

---

## 7. 20-Step End-to-End Validation Lifecycle

The automated test suite in [`tests/phase3-e2e-demo.test.ts`](file:///d:/PRAHAR/tests/phase3-e2e-demo.test.ts) validates the entire 20-step lifecycle:
1. **Authenticate Profile**: Retrieves Farmer / Expert profiles with authorized zones.
2. **Select Farm**: Queries `FARM-DEMO-01`.
3. **View Zones**: Inspects 4 spatial zones and soil moisture levels.
4. **Generate Rover Scan**: Captures simulated scan in dry Zone 2.
5. **Run Decision Engine**: Evaluates heat stress & low moisture rule.
6. **Persist Alert**: Writes bilingual alert into persistent alert store.
7. **View Alert in Farmer App**: Formats plain-language advisory in Hindi/English.
8. **View in Expert Queue**: Triages diagnosis and records expert note.
9. **Approve Irrigation**: Safety Gate passes with `approved_by: "dr_sharma_kvk_expert"`.
10. **Execute Simulated Irrigation**: Rover command processor dispatches 30s irrigation.
11. **Re-Scan**: Triggered to capture post-intervention state.
12. **Generate Verification**: Calculates pre (16.5%) vs post (28.5%) moisture delta (+12.0%).
13. **Persist Verification**: Writes record to `remediation_verifications`.
14. **Display Before/After Result**: Displays verified card on both client apps.
15. **Verify Audit Trail**: Confirms immutable log of triage and approval events.
16. **Toggle Offline Mode**: Rover enters offline buffer mode.
17. **Generate Offline Event**: Telemetry buffered locally in FIFO queue.
18. **Restore Connectivity**: Network restored.
19. **Synchronize Event**: Pushes batch with `idempotency_key`.
20. **Confirm Persistence**: Verifies 0 pending and duplicate push returns `is_duplicate: true`.

---

## 8. Known Limitations (Phase 3 Boundaries)

- **Simulation Mode**: Actuators and sensors are simulated via the high-fidelity `RoverEngine`. Physical hardware integration and autonomous chemical spraying belong to later phases.
- **Voice / Drone / Weather**: Multimodal voice/TTS, weather APIs, drone mapping, and government schemes are intentionally out of scope for Phase 3.
- **Local Persistence**: In local demo mode, persistent records are stored in `.prahar_data/` with JSON file mirroring. When connected to Supabase, PostgreSQL RLS is enforced.
