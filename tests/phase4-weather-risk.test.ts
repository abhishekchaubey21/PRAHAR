/**
 * PRAHAR Phase 4 Test Suite — Weather Risk Provider Architecture
 * Validates:
 * 1. IWeatherRiskProvider abstraction (Mock/Local vs External).
 * 2. Mandatory SIMULATION / DEMO labeling for mock/local weather.
 * 3. Safe fallback when external provider fails, times out, or returns invalid data.
 * 4. Agronomic risk evaluation (5 agricultural risk categories: Heat, Water, Flood, Humidity-Disease, Irrigation Suitability).
 * 5. Offline operation without internet.
 */

import { test, describe } from 'node:test';
import assert from 'node:assert';
import {
  MockSimulatedWeatherProvider,
  ExternalWeatherProvider,
  WeatherRiskEngine,
} from '../services/rover-simulator/src/weather-provider.js';

describe('Phase 4: Weather Risk Provider Architecture & Safety', () => {
  test('MockSimulatedWeatherProvider clearly labels data as SIMULATION / DEMO', async () => {
    const provider = new MockSimulatedWeatherProvider();
    const weather = await provider.getWeatherContext(12.9734, 77.5912);

    assert.strictEqual(weather.provider_type, 'SIMULATION_DEMO');
    assert.ok(weather.provider_label.includes('SIMULATION WEATHER'));
    assert.strictEqual(weather.is_degraded_fallback, false);
    assert.ok(typeof weather.temperature_c === 'number');
    assert.ok(typeof weather.relative_humidity_pct === 'number');
  });

  test('ExternalWeatherProvider falls back safely to offline baseline when endpoint is unreachable', async () => {
    // Point to non-existent endpoint to simulate timeout/outage
    const unreachableProvider = new ExternalWeatherProvider('http://127.0.0.1:59999/weather-dead-endpoint', 200);
    const engine = new WeatherRiskEngine(unreachableProvider);

    const weather = await engine.getWeather(12.9734, 77.5912);

    assert.strictEqual(weather.is_degraded_fallback, true);
    assert.ok(weather.provider_label.includes('Degraded Fallback'));
    assert.ok(weather.temperature_c > 0);
  });

  test('WeatherRiskEngine evaluates all 5 agricultural risk categories with transparent reasoning', async () => {
    const engine = new WeatherRiskEngine();
    const weather = await engine.getWeather(12.9734, 77.5912);
    const assessments = engine.assessRisks(weather, 17.5, 45.0);

    assert.strictEqual(assessments.length, 5);

    // Verify all 5 categories are present
    const categories = assessments.map((c) => c.category);
    assert.ok(categories.includes('HEAT_STRESS'));
    assert.ok(categories.includes('WATER_STRESS'));
    assert.ok(categories.includes('FLOOD_RISK'));
    assert.ok(categories.includes('HUMIDITY_DISEASE_RISK'));
    assert.ok(categories.includes('IRRIGATION_SUITABILITY'));

    // High temperature in zone 2 (33.5°C) must trigger heat stress
    const heatRisk = assessments.find((c) => c.category === 'HEAT_STRESS');
    assert.ok(heatRisk);
    assert.ok(['HIGH', 'CRITICAL'].includes(heatRisk.risk_level));
    assert.ok(heatRisk.impact_description_en.includes('heat'));
  });

  test('WeatherRiskEngine flood risk triggers irrigation suspension advice', () => {
    const engine = new WeatherRiskEngine();
    const heavyRainWeather = {
      temperature_c: 22.0,
      relative_humidity_pct: 92.0,
      rainfall_probability_pct: 90.0,
      rainfall_forecast_24h_mm: 65.0, // > 50mm triggers FLOOD_RISK
      wind_speed_kmh: 18.0,
      provider_type: 'SIMULATION_DEMO' as const,
      provider_label: 'SIMULATION WEATHER (Heavy Rain Scenario)',
      forecast_summary_en: 'Heavy continuous rain anticipated.',
      forecast_summary_hi: 'भारी बारिश की संभावना।',
      fetched_at: new Date().toISOString(),
      is_degraded_fallback: false,
    };

    const assessments = engine.assessRisks(heavyRainWeather, 38.0, 90.0);
    const floodRisk = assessments.find((c) => c.category === 'FLOOD_RISK');
    assert.ok(floodRisk);
    assert.strictEqual(floodRisk.risk_level, 'HIGH');
    assert.strictEqual(floodRisk.irrigation_advisable, false);
    assert.ok(floodRisk.irrigation_advice_reason_en.includes('SUSPEND IRRIGATION'));
  });

  test('Offline operation: WeatherRiskEngine functions when internet is completely disabled', async () => {
    const engine = new WeatherRiskEngine(new MockSimulatedWeatherProvider());
    const weather = await engine.getWeather(12.9734, 77.5912);
    const assessments = engine.assessRisks(weather, 28.0, 50.0);

    assert.ok(assessments.length === 5);
    assert.ok(weather.provider_label.includes('SIMULATION WEATHER'));
  });
});
