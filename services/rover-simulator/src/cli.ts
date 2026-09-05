/**
 * PRAHAR Rover Simulator — Interactive Terminal CLI
 * Allows interactive verification of rover state, commands, offline buffering, and scan cycles.
 */

import readline from 'node:readline';
import { RoverEngine } from './engine.js';
import { RoverCommand } from '@prahar/shared';

const engine = new RoverEngine({ roverId: 'ROVER-CLI-01' });

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function printBanner() {
  console.log('\n=============================================================');
  console.log('  PRAHAR Rover Simulator v0.1 — Interactive CLI Controller');
  console.log('=============================================================');
  console.log('Commands:');
  console.log('  1. status           — View current rover state & battery');
  console.log('  2. scan [zone]      — Trigger simulated scan (default DEMO-ZONE-01)');
  console.log('  3. rescan [zone]    — Trigger re-scan for intervention check');
  console.log('  4. irrigate [zone]  — Trigger simulated micro-irrigation (30s)');
  console.log('  5. stop             — Emergency stop rover');
  console.log('  6. offline on/off   — Toggle simulated offline mode');
  console.log('  7. queue            — View buffered offline events');
  console.log('  8. flush            — Flush & sync offline buffer');
  console.log('  9. telemetry        — Print current telemetry snapshot');
  console.log('  10. exit            — Exit CLI');
  console.log('=============================================================\n');
}

async function handleInput(line: string) {
  const parts = line.trim().split(/\s+/);
  const cmd = parts[0]?.toLowerCase();
  const arg1 = parts[1];

  switch (cmd) {
    case 'status':
    case '1': {
      console.log('\nRover Status:', JSON.stringify(engine.getStatus(), null, 2));
      break;
    }
    case 'scan':
    case '2': {
      const zone = arg1 || 'DEMO-ZONE-01';
      console.log(`\nInitiating scan for ${zone}...`);
      const command: RoverCommand = {
        command_id: `cli-scan-${Date.now()}`,
        rover_id: engine.getRoverId(),
        command_type: 'START_SCAN',
        payload: { zone_id: zone },
        issued_at: new Date().toISOString(),
      };
      const ack = await engine.executeCommand(command);
      console.log('Command ACK:', JSON.stringify(ack, null, 2));
      break;
    }
    case 'rescan':
    case '3': {
      const zone = arg1 || 'DEMO-ZONE-01';
      console.log(`\nInitiating re-scan for ${zone}...`);
      const command: RoverCommand = {
        command_id: `cli-rescan-${Date.now()}`,
        rover_id: engine.getRoverId(),
        command_type: 'RE_SCAN',
        payload: { zone_id: zone },
        issued_at: new Date().toISOString(),
      };
      const ack = await engine.executeCommand(command);
      console.log('Command ACK:', JSON.stringify(ack, null, 2));
      break;
    }
    case 'irrigate':
    case '4': {
      const zone = arg1 || 'DEMO-ZONE-02';
      console.log(`\nSimulating micro-irrigation in ${zone} (30s)...`);
      const command: RoverCommand = {
        command_id: `cli-irrigate-${Date.now()}`,
        rover_id: engine.getRoverId(),
        command_type: 'IRRIGATE',
        payload: { zone_id: zone, duration_seconds: 30, volume_liters: 7.5, approved_by: 'cli_operator' },
        issued_at: new Date().toISOString(),
      };
      const ack = await engine.executeCommand(command);
      console.log('Command ACK:', JSON.stringify(ack, null, 2));
      break;
    }
    case 'stop':
    case '5': {
      console.log('\nStopping rover...');
      const command: RoverCommand = {
        command_id: `cli-stop-${Date.now()}`,
        rover_id: engine.getRoverId(),
        command_type: 'STOP',
        payload: { reason: 'Operator CLI Halt' },
        issued_at: new Date().toISOString(),
      };
      const ack = await engine.executeCommand(command);
      console.log('Command ACK:', JSON.stringify(ack, null, 2));
      break;
    }
    case 'offline':
    case '6': {
      const mode = arg1?.toLowerCase() === 'on';
      engine.setOfflineMode(mode);
      console.log(`\nOffline mode set to: ${mode}`);
      break;
    }
    case 'queue':
    case '7': {
      console.log(`\nBuffered Events (${engine.offlineStore.getCount()} items):`);
      console.log(JSON.stringify(engine.offlineStore.peekAll(), null, 2));
      break;
    }
    case 'flush':
    case '8': {
      const flushed = engine.flushOfflineQueue();
      console.log(`\nFlushed ${flushed.length} buffered events to simulated cloud ingestion.`);
      break;
    }
    case 'telemetry':
    case '9': {
      console.log('\nCurrent Telemetry Snapshot:');
      console.log(JSON.stringify(engine.getTelemetry(), null, 2));
      break;
    }
    case 'exit':
    case '10':
    case 'quit': {
      rl.close();
      process.exit(0);
    }
    default: {
      if (cmd) console.log(`Unknown command '${cmd}'. Type a valid option.`);
      break;
    }
  }

  prompt();
}

function prompt() {
  rl.question('prahar-rover> ', handleInput);
}

printBanner();
prompt();
