# PRAHAR — Engineering Foundation + Rover Simulator v0.1

> **Precision Rover for Agricultural Hazard Analysis & Remediation**  
> *Smart India Hackathon (SIH) 2026 — PS #26180*  
> **Phase 1 Deliverable**: Engineering Foundation, Monorepo, Shared Domain Schemas, Database Migrations, Frontend Skeletons, and Autonomous Rover Simulator (v0.1).

---

## 1. Architecture Overview

PRAHAR combines autonomous ground-rover robotics with precision agricultural decision support. Phase 1 establishes the runnable engineering bedrock:

```
d:/PRAHAR/
├── apps/
│   ├── farmer-app/              # Flutter mobile app skeleton (Dart 3 / Flutter 3)
│   │   ├── lib/core/            # Theme, offline storage & queue abstractions
│   │   ├── lib/domain/          # Shared domain models (Zone, Reading, Detection, Alert)
│   │   ├── lib/screens/         # Home screen with farm status & rover scan action
│   │   └── test/                # Automated Flutter widget & smoke tests
│   │
│   └── expert-console/          # Next.js 14 (App Router) expert/admin console skeleton
│       ├── app/layout.tsx       # Shell layout & responsive navigation
│       ├── app/page.tsx         # Farm overview & quick metrics
│       ├── app/queue/page.tsx   # Expert triage review queue for flagged detections
│       └── app/fleet/page.tsx   # Fleet telemetry & live command simulator
│
├── packages/
│   └── shared/                  # Shared TypeScript contracts & validation schemas
│       ├── src/telemetry.ts     # Telemetry, GPS, sensor bundle types & validators
│       ├── src/detection.ts     # AI hazard detection types (Disease, Pest, Weed, etc.)
│       ├── src/commands.ts      # START_SCAN, STOP, RE_SCAN, IRRIGATE, STATUS contracts
│       ├── src/alert.ts         # Ingestion payload & alert lifecycle schemas
│       └── src/domain.ts        # Farmer, Farm, Zone entities
│
├── services/
│   └── rover-simulator/         # Autonomous Rover Simulator v0.1 (Node.js / TypeScript)
│       ├── src/engine.ts        # Rover state machine & cycle coordinator
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
├── tests/                       # Automated test suite (12 tests)
│   ├── rover-engine.test.ts     # State transitions & telemetry agronomic bounds
│   ├── command-idempotency.test.ts # Duplicate command ID rejection & safety checks
│   ├── offline-queue.test.ts    # Store-and-forward offline event buffering
│   └── shared-contracts.test.ts # Contract schema validators
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
- **Docker / Supabase CLI** (optional for running local Postgres database)

> [!NOTE]
> On Windows systems where PowerShell script execution (`npm.ps1`) is restricted, invoke commands using `npm.cmd` or standard cmd.

---

## 3. Step-by-Step Local Setup

### Step 1: Install Dependencies
From the repository root:
```bash
npm install
```

### Step 2: Build Shared Domain Contracts
Compile the shared TypeScript contracts:
```bash
npm run build:shared
```

### Step 3: Run Automated Test Suite
Run the 12 automated unit and integration tests covering telemetry generation, state machine transitions, command idempotency, safety bounds, and offline event queueing:
```bash
npm test
```

Run the Flutter widget test suite:
```bash
npm run flutter:test
```

---

## 4. Running the Rover Simulator (v0.1)

The simulator models an autonomous agricultural rover operating across 4 farm zones (`DEMO-ZONE-01` through `DEMO-ZONE-04`).

### Mode A: HTTP REST & Streaming Server (Default)
Starts the simulator daemon on `http://localhost:3001`:
```bash
npm run dev:simulator
```

#### Available HTTP Endpoints:
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/rover/status` | Current state, battery level, active zone, and offline queue count |
| `GET` | `/api/rover/telemetry/latest` | Real-time GPS, sensor readings (moisture, temp, humidity, pH), tilt, battery |
| `POST` | `/api/rover/command` | Dispatch rover command (`START_SCAN`, `STOP`, `RE_SCAN`, `IRRIGATE`, `STATUS`) |
| `POST` | `/api/rover/simulate-scan` | Trigger a complete simulated scan cycle for a target zone |
| `POST` | `/api/rover/offline-mode` | Toggle offline mode (`{ "enabled": true/false }`) |
| `GET` | `/api/rover/queue` | Inspect buffered offline events |
| `POST` | `/api/rover/flush-queue` | Flush and sync offline buffer upon reconnect |
| `POST` | `/api/rover/recharge` | Reset rover battery to target percentage |
| `GET` | `/api/rover/telemetry-stream` | Server-Sent Events (SSE) live telemetry stream |

#### Testing Commands via Curl / PowerShell:
```powershell
# 1. Query Status
Invoke-RestMethod -Uri "http://localhost:3001/api/rover/status"

# 2. Dispatch START_SCAN with an Idempotency Token (command_id)
$cmd = @{ command_id="scan-001"; command_type="START_SCAN"; payload=@{ zone_id="DEMO-ZONE-01" } } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3001/api/rover/command" -Method Post -Body $cmd -ContentType "application/json"

# 3. Re-send identical command_id (verifies duplicate rejection)
Invoke-RestMethod -Uri "http://localhost:3001/api/rover/command" -Method Post -Body $cmd -ContentType "application/json"

# 4. Dispatch Simulated Micro-Irrigation (30s)
$irrigate = @{ command_id="irr-001"; command_type="IRRIGATE"; payload=@{ zone_id="DEMO-ZONE-02"; duration_seconds=30 } } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3001/api/rover/command" -Method Post -Body $irrigate -ContentType "application/json"
```

### Mode B: Interactive Terminal Controller (CLI)
For rapid local testing without HTTP requests:
```bash
npm run dev:simulator:cli
```
Interactive commands available:
- `status` — View rover state and battery
- `scan [zone]` — Initiate scan on zone (default `DEMO-ZONE-01`)
- `irrigate [zone]` — Simulate micro-irrigation (30s)
- `stop` — Emergency halt
- `offline on` / `offline off` — Toggle disconnected mode
- `queue` — Inspect buffered events
- `flush` — Flush offline store to simulated cloud

---

## 5. Running the Frontend Skeletons

### Expert Triage Web Console (Next.js 14)
Starts the console on `http://localhost:3000`:
```bash
npm run dev:expert
```
- **Overview** (`/`): Health metrics, zone overview, connected rover indicator.
- **Triage Queue** (`/queue`): Expert review queue with flagged cases (Early Blight, Water Stress), sensor context, and Confirm/Correct/Escalate actions.
- **Fleet Telemetry** (`/fleet`): Real-time rover telemetry and command dispatch controls connected directly to the simulator on `:3001`.

### Farmer Mobile App Skeleton (Flutter)
```bash
cd apps/farmer-app
flutter run
```
Provides:
- Farm health overview card
- Live rover state & battery monitor
- One-tap "Scan Now" request trigger
- Plain-language alert feed for smallholder farmers

---

## 6. Supabase Database & Migrations

Local database migrations and demo seed data are pre-configured:
- **Migration**: `supabase/migrations/20260905000000_prahar_core_schema.sql`
  - Creates relational tables: `farmers`, `farms`, `zones`, `sensor_readings`, `detections`, `alerts`, `rover_commands`, `rover_telemetry`, and `offline_sync_events`.
  - Enforces unique `command_id` primary keys for command idempotency.
- **Seed Data**: `supabase/seed.sql`
  - Synthetic demo farmer (`Demo Farmer Alpha`, `+91-00000-00001`).
  - Synthetic plot (`Demo Precision Field Alpha`, 3.5 acres, Tomato).
  - 4 Zones: `DEMO-ZONE-01` (Optimal), `DEMO-ZONE-02` (Water Stressed), `DEMO-ZONE-03` (Disease Prone), `DEMO-ZONE-04` (Alkaline).

To apply using local Supabase CLI:
```bash
npx supabase start
npx supabase db reset
```

---

## 7. Explicit Phase 1 Boundary Guarantees

In accordance with the PRAHAR Engineering Specification v1.0, the following items are intentionally **out of scope** for Phase 1 and will be built in subsequent phases:
- ❌ No voice interaction / TTS / STT.
- ❌ No government scheme discovery.
- ❌ No external weather API integrations.
- ❌ No drone workflows.
- ❌ No advanced predictive yield analytics.
- ❌ No open-domain conversational chatbots.
- ❌ No physical actuators or chemical spraying (IRRIGATE is simulated only).
- ❌ No production cloud deployments.
