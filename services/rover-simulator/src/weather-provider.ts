/**
 * PRAHAR Weather & Agricultural Risk Provider Architecture
 * Aligned with Amendment 3 & 10: Provider abstraction separating risk engine from providers,
 * mandatory SIMULATION/DEMO labeling for mock data, and graceful degradation on provider failure.
 */

import {
  WeatherContext,
  AgriculturalRiskAssessment,
  RiskCategory,
} from '@prahar/shared';

export interface IWeatherRiskProvider {
  getWeatherContext(lat: number, lng: number): Promise<WeatherContext>;
}

/**
 * Mock/Local Weather Provider
 * Clearly and visibly labeled as SIMULATION / DEMO.
 */
export class MockSimulatedWeatherProvider implements IWeatherRiskProvider {
  private baseTemp: number;
  private baseHumidity: number;
  private rainfallProb: number;

  constructor(options?: { baseTemp?: number; baseHumidity?: number; rainfallProb?: number }) {
    this.baseTemp = options?.baseTemp ?? 33.5;
    this.baseHumidity = options?.baseHumidity ?? 45.0;
    this.rainfallProb = options?.rainfallProb ?? 10.0;
  }

  public async getWeatherContext(lat: number, lng: number): Promise<WeatherContext> {
    return {
      temperature_c: this.baseTemp,
      relative_humidity_pct: this.baseHumidity,
      rainfall_probability_pct: this.rainfallProb,
      rainfall_forecast_24h_mm: this.rainfallProb > 60 ? 15.0 : 0.0,
      wind_speed_kmh: 12.0,
      provider_type: 'SIMULATION_DEMO',
      provider_label: 'SIMULATION WEATHER (Deterministic Agronomic Simulator)',
      forecast_summary_en: 'Hot and dry conditions with negligible rain expected in next 24h.',
      forecast_summary_hi: 'अगले 24 घंटों में गर्म और शुष्क मौसम, वर्षा की नगण्य संभावना।',
      fetched_at: new Date().toISOString(),
      is_degraded_fallback: false,
    };
  }
}

/**
 * External Weather Provider Abstraction
 * Supports real weather endpoints with timeout and graceful degradation.
 */
export class ExternalWeatherProvider implements IWeatherRiskProvider {
  private apiUrl: string;
  private timeoutMs: number;

  constructor(apiUrl?: string, timeoutMs: number = 3000) {
    this.apiUrl = apiUrl || process.env.WEATHER_API_URL || 'https://api.open-meteo.com/v1/forecast';
    this.timeoutMs = timeoutMs;
  }

  public async getWeatherContext(lat: number, lng: number): Promise<WeatherContext> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const url = `${this.apiUrl}?latitude=${lat}&longitude=${lng}&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m`;
      const res = await fetch(url, { signal: controller.signal });
      clearTimeout(timeoutId);

      if (!res.ok) {
        throw new Error(`Weather API responded with status ${res.status}`);
      }

      const data = await res.json();
      const current = data.current || {};

      return {
        temperature_c: current.temperature_2m ?? 30.0,
        relative_humidity_pct: current.relative_humidity_2m ?? 50.0,
        rainfall_probability_pct: current.precipitation ? 75.0 : 5.0,
        rainfall_forecast_24h_mm: current.precipitation ?? 0.0,
        wind_speed_kmh: current.wind_speed_10m ?? 10.0,
        provider_type: 'EXTERNAL_API',
        provider_label: 'LIVE WEATHER (External Meteorological Service)',
        forecast_summary_en: `Live temperature ${current.temperature_2m}°C, humidity ${current.relative_humidity_2m}%.`,
        forecast_summary_hi: `लाइव तापमान ${current.temperature_2m}°C, आर्द्रता ${current.relative_humidity_2m}%।`,
        fetched_at: new Date().toISOString(),
        is_degraded_fallback: false,
      };
    } catch (err: any) {
      clearTimeout(timeoutId);
      throw err; // Caught by WeatherRiskEngine for safe fallback
    }
  }
}

/**
 * Weather Risk Engine
 * Evaluates contextual agricultural risks and guarantees graceful fallback if provider fails.
 */
export class WeatherRiskEngine {
  private provider: IWeatherRiskProvider;
  private fallbackProvider: MockSimulatedWeatherProvider;

  constructor(provider?: IWeatherRiskProvider) {
    this.provider = provider || new MockSimulatedWeatherProvider();
    this.fallbackProvider = new MockSimulatedWeatherProvider();
  }

  public setProvider(provider: IWeatherRiskProvider): void {
    this.provider = provider;
  }

  /**
   * Retrieves weather context with resilient error boundary fallback.
   */
  public async getWeather(lat: number = 26.8467, lng: number = 80.9462): Promise<WeatherContext> {
    try {
      return await this.provider.getWeatherContext(lat, lng);
    } catch (err) {
      // Graceful fallback to simulated baseline
      const fallback = await this.fallbackProvider.getWeatherContext(lat, lng);
      return {
        ...fallback,
        is_degraded_fallback: true,
        provider_label: 'SIMULATION WEATHER (Degraded Fallback — Provider Offline)',
      };
    }
  }

  /**
   * Evaluates all 5 Agricultural Risk Categories combining weather with field sensor context.
   */
  public assessRisks(
    weather: WeatherContext,
    fieldMoisture?: number,
    fieldHumidity?: number
  ): AgriculturalRiskAssessment[] {
    const assessments: AgriculturalRiskAssessment[] = [];

    // 1. HEAT_STRESS
    const isHeatStress = weather.temperature_c >= 32.0;
    assessments.push({
      category: 'HEAT_STRESS',
      risk_level: weather.temperature_c >= 38.0 ? 'CRITICAL' : isHeatStress ? 'HIGH' : 'LOW',
      impact_description_en: isHeatStress
        ? `Elevated atmospheric heat (${weather.temperature_c}°C) accelerates soil evapotranspiration.`
        : `Atmospheric temperature (${weather.temperature_c}°C) is within safe crop bounds.`,
      impact_description_hi: isHeatStress
        ? `उच्च वातावरणीय तापमान (${weather.temperature_c}°C) से मिट्टी का वाष्पीकरण बढ़ रहा है।`
        : `तापमान (${weather.temperature_c}°C) सुरक्षित सीमा में है।`,
      irrigation_advisable: isHeatStress && (fieldMoisture !== undefined ? fieldMoisture < 25.0 : true),
      irrigation_advice_reason_en: isHeatStress
        ? 'Soil cooling via micro-irrigation is recommended during peak heat hours.'
        : 'Normal watering schedule suffices.',
      irrigation_advice_reason_hi: isHeatStress
        ? 'अधिक गर्मी के समय सूक्ष्म-सिंचाई द्वारा मिट्टी को ठंडा रखने की सलाह दी जाती है।'
        : 'सामान्य जल अनुसूची पर्याप्त है।',
      contributing_factors: [`Ambient temperature: ${weather.temperature_c}°C`],
    });

    // 2. WATER_STRESS
    const isWaterStress = (fieldMoisture !== undefined && fieldMoisture < 20.0) || (weather.rainfall_forecast_24h_mm === 0 && weather.temperature_c > 30.0);
    assessments.push({
      category: 'WATER_STRESS',
      risk_level: fieldMoisture !== undefined && fieldMoisture < 20.0 ? 'HIGH' : 'MEDIUM',
      impact_description_en: `Rainfall forecast is ${weather.rainfall_forecast_24h_mm}mm. Evaporation risk is active.`,
      impact_description_hi: `वर्षा का अनुमान ${weather.rainfall_forecast_24h_mm}mm है। वाष्पीकरण का जोखिम बना हुआ है।`,
      irrigation_advisable: isWaterStress,
      irrigation_advice_reason_en: 'Rain is not expected to replenish depleted soil moisture.',
      irrigation_advice_reason_hi: 'कम नमी की भरपाई बारिश से होने की संभावना नहीं है।',
      contributing_factors: [`Rainfall probability: ${weather.rainfall_probability_pct}%`, `24h Rain: ${weather.rainfall_forecast_24h_mm}mm`],
    });

    // 3. FLOOD_RISK
    const isFlood = weather.rainfall_forecast_24h_mm > 50.0;
    assessments.push({
      category: 'FLOOD_RISK',
      risk_level: isFlood ? 'HIGH' : 'LOW',
      impact_description_en: isFlood ? 'High precipitation forecast creates waterlogging risk.' : 'No waterlogging or flooding risk detected.',
      impact_description_hi: isFlood ? 'भारी वर्षा के अनुमान से जलजमाव का जोखिम है।' : 'जलजमाव का कोई जोखिम नहीं है।',
      irrigation_advisable: !isFlood,
      irrigation_advice_reason_en: isFlood ? 'SUSPEND IRRIGATION: High rainfall anticipated.' : 'Irrigation permitted according to soil moisture needs.',
      irrigation_advice_reason_hi: isFlood ? 'सिंचाई स्थगित रखें: भारी वर्षा की संभावना।' : 'नमी की आवश्यकता अनुसार सिंचाई की जा सकती है।',
      contributing_factors: [`Rainfall forecast: ${weather.rainfall_forecast_24h_mm}mm`],
    });

    // 4. HUMIDITY_DISEASE_RISK
    const effectiveHumidity = fieldHumidity ?? weather.relative_humidity_pct;
    const isHighDiseaseRisk = effectiveHumidity >= 70.0;
    assessments.push({
      category: 'HUMIDITY_DISEASE_RISK',
      risk_level: isHighDiseaseRisk ? 'HIGH' : 'LOW',
      impact_description_en: isHighDiseaseRisk
        ? `Sustained relative humidity of ${effectiveHumidity}% favors fungal spore germination.`
        : `Relative humidity (${effectiveHumidity}%) is unfavorable for fungal outbreaks.`,
      impact_description_hi: isHighDiseaseRisk
        ? `लगातार ${effectiveHumidity}% आर्द्रता फफूंद बीजाणुओं के अंकुरण को बढ़ावा देती है।`
        : `आर्द्रता (${effectiveHumidity}%) फफूंद रोगों के लिए प्रतिकूल है।`,
      irrigation_advisable: !isHighDiseaseRisk || (fieldMoisture !== undefined && fieldMoisture < 18.0),
      irrigation_advice_reason_en: isHighDiseaseRisk
        ? 'Avoid overhead watering; prefer targeted soil root micro-irrigation only if soil is dry.'
        : 'Standard application safe.',
      irrigation_advice_reason_hi: isHighDiseaseRisk
        ? 'ऊपर से पानी देने से बचें; केवल जड़ क्षेत्र में सूक्ष्म-सिंचाई करें।`'
        : 'मानक अनुप्रयोग सुरक्षित है।',
      contributing_factors: [`Humidity: ${effectiveHumidity}%`],
    });

    // 5. IRRIGATION_SUITABILITY
    const rainExpectedSoon = weather.rainfall_probability_pct > 60.0 && weather.rainfall_forecast_24h_mm > 10.0;
    const isSuitabilityHigh = !rainExpectedSoon && !isFlood;
    assessments.push({
      category: 'IRRIGATION_SUITABILITY',
      risk_level: isSuitabilityHigh ? 'LOW' : 'HIGH', // Low risk = suitable
      impact_description_en: isSuitabilityHigh
        ? 'Microclimate conditions are optimal for micro-irrigation without runoff waste.'
        : 'Imminent rainfall makes irrigation inefficient and wasteful.',
      impact_description_hi: isSuitabilityHigh
        ? 'मौसम सूक्ष्म-सिंचाई के लिए उपयुक्त है, पानी व्यर्थ नहीं होगा।'
        : 'आसन्न वर्षा के कारण सिंचाई अनुपयुक्त और व्यर्थ होगी।',
      irrigation_advisable: isSuitabilityHigh,
      irrigation_advice_reason_en: isSuitabilityHigh
        ? 'Proceed with approved micro-irrigation.'
        : 'Hold irrigation until rain outcome is observed.',
      irrigation_advice_reason_hi: isSuitabilityHigh
        ? 'स्वीकृत सूक्ष्म-सिंचाई के साथ आगे बढ़ें।'
        : 'बारिश का परिणाम देखने तक सिंचाई रोकें।',
      contributing_factors: [`Rain probability: ${weather.rainfall_probability_pct}%`, `Wind: ${weather.wind_speed_kmh} km/h`],
    });

    return assessments;
  }
}
