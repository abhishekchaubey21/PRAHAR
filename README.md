# PRAHAR — Precision Rover for Agricultural Hazard Analysis & Remediation
> *Smart India Hackathon (SIH) 2026 — PS #26180*  
> **Phase 1 & Phase 2 Delivered**: Engineering Foundation, Monorepo, Shared Domain Schemas, Database Migrations, Frontend Skeletons, Autonomous Rover Simulator, **AI Decision Layer (Rule-Based Fusion Engine)**, **Alert Ingestion & Deduplication**, and **Closed-Loop Remediation Workflow**.

---

## 1. Architecture Overview

PRAHAR combines autonomous ground-rover robotics with precision agricultural decision support.

```
d:/PRAHAR/
├── apps/
│   ├── farmer-app/              # Flutter mobile app (Dart 3 / Flutter 3)
│   │   ├── lib/core/            # Theme, offline storage & queue abstractions
│   │   ├── lib/domain/          # Shared domain models (Zone, Alert, Verification)
│   │   ├── lib/screens/         # Home screen with EN/HI toggle, actionable alerts & verification card
│   │   └── test/                # Automated Flutter widget & verification tests
│   │
│   └── expert-console/          # Next.js 14 (App Router) expert/admin console
│       ├── app/layout.tsx       # Shell layout & responsive navigation
│       ├── app/page.tsx         # Farm overview & quick metrics
│       ├── app/queue/page.tsx   # Expert triage queue (Confirm, Correct, Escalate, Approve)
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
│       └── src/domain.ts        # Farmer, Farm, Zone entities
│
├── services/
│   └── rover-simulator/         # Autonomous Rover Simulator & Decision Gateway (v0.2)
│       ├── src/engine.ts        # Rover state machine & cycle coordinator
│       ├── src/decision-engine.ts # Rule-based fusion engine & confidence gating
│       ├── src/closed-loop.ts   # Closed-loop remediation & verification coordinator
│       ├── src/alert-store.ts   # In-memory store with 24h deduplication & audit trail
│       ├── src/telemetry-gen.ts # Agronomic sensor generator (Moisture, Temp, Humidity, pH)
│       ├── src/detection-gen.ts # Synthetic vision AI hazard detection generator
│       ├── src/command-proc.ts  # Idempotency cache & physical safety enforcer
│       ├── src/offline-store.ts # Local FIFO store & queue for offline operation
│       ├── src/server.ts        # HTTP & SSE REST API server (Port 3001)
│       └── src/cli.ts           # Interactive terminal CLI controller
│
├── supabase/
│   ├── migrations/              # Relational SQL schemas with indices & constraints
│   ├── seed.sql                 # Synthetic demo data (Demo Farmer, 4 Zones, Rover-01)
│   └── config.toml              # Supabase CLI configuration
│
├── tests/                       # Automated test suite (19 tests)
│   ├── rover-engine.test.ts     # State transitions & telemetry agronomic bounds
│   ├── command-idempotency.test.ts # Duplicate command ID rejection & safety checks
│   ├── offline-queue.test.ts    # Store-and-forward offline event buffering
│   ├── shared-contracts.test.ts # Contract schema validators
│   ├── decision-engine.test.ts  # Rule fusion, confidence gating & deduplication
│   └── closed-loop-workflow.test.ts # Closed-loop remediation & verification
│
├── package.json                 # Monorepo workspaces & development scripts
└── README.md                    # Local setup and developer guide
```

---

## 2. Prerequisites

Ensure the following tools are installed on your machine:
- **Node.js**: v20.x or v24.x (`node -v`)
- **npm**: v10.x or v11.x (`npm -v`)
- **Flutter**: v3.24+ or v3.47+ (`flutter --version`)
- **Docker / Supabase CLI** (optional for local Postgres database)

---

## 3. Step-by-Step Local Setup

### Step 1: Install Dependencies
```bash
npm install
```

### Step 2: Build Shared Domain Contracts
```bash
npm run build:shared
```

### Step 3: Run Automated Test Suite (19 Tests)
```bash
npm test
```
Runs 19 unit & integration tests covering telemetry bounds, command idempotency, safety gates, decision rules, confidence gating, alert deduplication, and closed-loop verification.

Run Flutter tests:
```bash
npm run flutter:test
```

---

## 4. Phase 2 Features & The Closed-Loop Workflow

### The Closed-Loop Flow
```
SCAN → INGEST → DECISION → RECOMMENDATION → APPROVAL GATE → SAFETY VALIDATION → IRRIGATE → RE-SCAN → VERIFY
```

1. **Safety Gate — No Autonomous Irrigation**:
   - The decision engine **never** auto-triggers physical actions.
   - Any physical action (`IRRIGATE`) requires explicit `approved_by` attribution (Farmer or Expert), duration limit ($\le 180$s), volume limit ($\le 50$L), and battery health check ($> 10\%$).
2. **Confidence Gating**:
   - Detections with `confidence < 0.70` suppress action recommendations and route to the Expert Review Queue.
3. **Alert Deduplication**:
   - Active alerts in the same zone for the same hazard are deduplicated over a 24-hour window, updating timestamp and counts rather than creating duplicate spam.
4. **Bilingual Advisory Engine**:
   - Advisory messages and recommended actions are generated in both English and Hindi.
5. **Auditable Expert Actions**:
   - Expert triage actions (`CONFIRM`, `CORRECT`, `ESCALATE`, `APPROVE_INTERVENTION`) record `actor`, `timestamp`, `zone_id`, `alert_id`, `action`, `previous_state`, `new_state`, and `expert_note`.
6. **Genuine Before/After Verification**:
   - Post-remediation re-scan measures pre- vs. post-intervention state and computes `moisture_delta` and resolution status.

---

## 5. Running the Services Locally

### 1. Rover Simulator & Decision Gateway (Port 3001)
```bash
npm run dev:simulator
```

#### Key API Endpoints:
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/ingest/scan` | Ingest scan cycle & evaluate decision rules |
| `GET` | `/api/alerts` | List active & historical alerts (bilingual) |
| `POST` | `/api/alerts/:id/triage` | Expert triage: `CONFIRM`, `CORRECT`, `ESCALATE` with audit log |
| `POST` | `/api/remediation/approve` | Safety Gate: Approve intervention (`approved_by`) |
| `POST` | `/api/remediation/execute` | Execute approved action with rover safety checks |
| `POST` | `/api/remediation/verify` | Trigger re-scan and compute before/after verification delta |
| `GET` | `/api/remediation/verifications` | List all verified closed-loop remediation records |
| `GET` | `/api/audit/history` | Inspect expert triage audit trail |
| `GET` | `/api/rover/status` | Current rover state, battery, active zone |
| `POST` | `/api/rover/command` | Dispatch rover command (Idempotent via `command_id`) |

### 2. Expert Web Console (Port 3000)
```bash
npm run dev:expert
```
- **Overview** (`/`): Farm precision overview and rover state.
- **Triage Queue** (`/queue`): Review flagged AI detections, confirm diagnoses, approve interventions.
- **Closed-Loop Verification** (`/closed-loop`): Execute approved actions, trigger verification re-scans, view before/after comparison delta table.
- **Fleet Monitor** (`/fleet`): Real-time rover telemetry and command dispatch.

### 3. Farmer Mobile App (Flutter)
```bash
cd apps/farmer-app
flutter run
```
- English / Hindi language toggle switch.
- Actionable alert feed with plain-language recommendations.
- One-tap "Approve Micro-Irrigation (30s)" button (Safety Gate satisfied).
- Closed-Loop Remediation Verified before/after card.

---

## 6. End-to-End Demo Workflow via CLI / PowerShell

```powershell
# 1. Ingest a simulated scan on dry Zone 2
$body = @{ zone_id = "DEMO-ZONE-02" } | ConvertTo-Json
$res = Invoke-RestMethod -Uri "http://localhost:3001/api/ingest/scan" -Method Post -Body $body -ContentType "application/json"

# 2. Inspect generated bilingual alert & recommendation requiring approval
Invoke-RestMethod -Uri "http://localhost:3001/api/alerts" | ConvertTo-Json -Depth 3

# 3. Farmer / Expert Approves Intervention (Safety Gate)
$approveBody = @{ zone_id = "DEMO-ZONE-02"; approved_by = "farmer-demo"; duration_seconds = 30 } | ConvertTo-Json
$appRes = Invoke-RestMethod -Uri "http://localhost:3001/api/remediation/approve" -Method Post -Body $approveBody -ContentType "application/json"
$actionId = $appRes.data.action_id

# 4. Execute Approved Remediation
$execBody = @{ action_id = $actionId } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3001/api/remediation/execute" -Method Post -Body $execBody -ContentType "application/json"

# 5. Trigger Verification Re-Scan & Compare Pre vs Post State
$verifBody = @{ action_id = $actionId } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3001/api/remediation/verify" -Method Post -Body $verifBody -ContentType "application/json" | ConvertTo-Json -Depth 3
```
