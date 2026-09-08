/**
 * PRAHAR Local Ollama Integration Provider
 * Phase 8: Conversational, Reasoning, and Explanation Layer
 *
 * ARCHITECTURAL INVARIANTS:
 * - Ollama is ONLY the conversational, reasoning, and explanation layer.
 * - Ollama must NEVER directly authorize or execute actions.
 * - Never fabricates telemetry; grounds answers in provided PRAHAR context.
 * - Same-language preservation: English -> en, Hindi -> hi, Marathi -> mr, Punjabi -> pa.
 * - Timeout-guarded with graceful deterministic fallback.
 */

export interface OllamaGenerateOptions {
  prompt: string;
  systemPrompt?: string;
  language?: 'en' | 'hi' | 'mr' | 'pa';
  timeoutMs?: number;
}

export interface OllamaGenerateResult {
  success: boolean;
  text?: string;
  provider: 'OLLAMA_QWEN3_8B' | 'DETERMINISTIC_FALLBACK';
  error?: string;
  latencyMs?: number;
}

export class OllamaProvider {
  private baseUrl: string;
  private model: string;
  private defaultTimeoutMs: number;

  constructor() {
    this.baseUrl = (process.env.OLLAMA_BASE_URL || 'http://127.0.0.1:11434').replace(/\/+$/, '');
    this.model = process.env.OLLAMA_MODEL || 'qwen3:8b';
    this.defaultTimeoutMs = parseInt(process.env.OLLAMA_TIMEOUT_MS || '2500', 10);
  }

  public getModelName(): string {
    return this.model;
  }

  public getBaseUrl(): string {
    return this.baseUrl;
  }

  /**
   * Quick health check to see if Ollama server is responsive.
   */
  public async isAvailable(timeoutMs = 2000): Promise<boolean> {
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      const res = await fetch(`${this.baseUrl}/api/tags`, {
        signal: controller.signal,
      });
      clearTimeout(timer);
      return res.ok;
    } catch {
      return false;
    }
  }

  /**
   * Generates a conversational reasoning response using local Qwen3 8B.
   */
  public async generateExplanation(options: OllamaGenerateOptions): Promise<OllamaGenerateResult> {
    const startTime = Date.now();
    const timeout = options.timeoutMs || this.defaultTimeoutMs;
    const lang = options.language || 'en';

    const langInstructions: Record<string, string> = {
      en: 'Strictly respond in English.',
      hi: 'Strictly respond in Hindi using Devanagari script (हिंदी). Do NOT switch to English.',
      mr: 'Strictly respond in Marathi using Devanagari script (मराठी). Do NOT switch to English.',
      pa: 'Strictly respond in Punjabi using Gurmukhi script (ਪੰਜਾਬੀ). Do NOT switch to English.',
    };

    const systemPrompt =
      options.systemPrompt ||
      `You are PRAHAR AI, the conversational agricultural reasoning and precision assistant for Indian farmers.
RULES:
1. ${langInstructions[lang] || langInstructions.en}
2. Ground all answers strictly in the provided PRAHAR telemetry context.
3. You are ONLY an advisory explanation layer. You CANNOT execute physical actions or rover actuators.
4. Chemical spraying is strictly prohibited; only organic or precision remediation.
5. Keep your answer direct, practical, and under 4 sentences.`;

    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeout);

      const response = await fetch(`${this.baseUrl}/api/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: controller.signal,
        body: JSON.stringify({
          model: this.model,
          prompt: options.prompt,
          system: systemPrompt,
          stream: false,
          options: {
            temperature: 0.2,
            num_predict: 250,
            stop: ['\nFarmer:', '\nUser:', '<|im_end|>'],
          },
        }),
      });

      clearTimeout(timer);

      if (!response.ok) {
        return {
          success: false,
          provider: 'DETERMINISTIC_FALLBACK',
          error: `Ollama HTTP ${response.status}: ${response.statusText}`,
          latencyMs: Date.now() - startTime,
        };
      }

      const data = (await response.json()) as any;
      let rawText = data?.response || '';

      // Strip any reasoning / thinking block emitted by Qwen3 (e.g. <think>...</think>)
      rawText = rawText.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();

      if (!rawText) {
        return {
          success: false,
          provider: 'DETERMINISTIC_FALLBACK',
          error: 'Empty response from Ollama',
          latencyMs: Date.now() - startTime,
        };
      }

      return {
        success: true,
        text: rawText,
        provider: 'OLLAMA_QWEN3_8B',
        latencyMs: Date.now() - startTime,
      };
    } catch (err: any) {
      return {
        success: false,
        provider: 'DETERMINISTIC_FALLBACK',
        error: err.name === 'AbortError' ? 'Ollama request timed out' : err.message || 'Unknown error',
        latencyMs: Date.now() - startTime,
      };
    }
  }
}
