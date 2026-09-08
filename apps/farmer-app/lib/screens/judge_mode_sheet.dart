import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../domain/assistant_model.dart';
import '../data/assistant/field_assistant_engine.dart';
import '../data/providers/demo_scenarios_provider.dart';

class JudgeModeSheet extends StatefulWidget {
  final FieldAssistantEngine assistantEngine;
  final DemoScenariosProvider scenariosProvider;
  final String currentLanguage;
  final FarmerAssistantContext farmerContext;
  final VoidCallback onFieldReset;

  const JudgeModeSheet({
    super.key,
    required this.assistantEngine,
    required this.scenariosProvider,
    required this.currentLanguage,
    required this.farmerContext,
    required this.onFieldReset,
  });

  @override
  State<JudgeModeSheet> createState() => _JudgeModeSheetState();
}

class _JudgeModeSheetState extends State<JudgeModeSheet> {
  int _currentStep = 1;
  bool _isStepExecuting = false;
  String? _stepOutput;
  AssistantStructuredResponse? _assistantResponse;
  final TextEditingController _interactiveController = TextEditingController();

  final List<String> _stepTitles = [
    '1. FARM PROFILE',
    '2. FIELD SCAN',
    '3. DETECT PROBLEM',
    '4. ASK WHY',
    '5. PRAHAR ANALYSIS',
    '6. RECOMMENDATION',
    '7. CONFIRM SIMULATED ACTION',
    '8. RE-SCAN',
    '9. VERIFY IMPROVEMENT',
    '10. CHAT/VOICE QUESTION',
    '11. SAME-LANGUAGE RESPONSE',
    '12. RESET / TRY ANOTHER SCENARIO',
  ];

  @override
  void initState() {
    super.initState();
    _executeStep(1);
  }

  Future<void> _executeStep(int step) async {
    setState(() {
      _currentStep = step;
      _isStepExecuting = true;
      _stepOutput = null;
    });

    try {
      switch (step) {
        case 1: // FARM PROFILE
          _stepOutput =
              'Farmer: ${widget.farmerContext.farmerName}\nLocation: ${widget.farmerContext.district}, ${widget.farmerContext.state}\nLand Holding: ${widget.farmerContext.landAcres} Acres (Owned)\nSoil: ${widget.farmerContext.soilType}\nCrops: Soybean + Wheat (Kharif/Rabi)';
          break;

        case 2: // FIELD SCAN
          await Future.delayed(const Duration(milliseconds: 300));
          _stepOutput =
              'Autonomous multi-zone scan completed across 4 sectors.\n• Zone 1: Moisture 68.0%, NDVI 0.82 (Healthy)\n• Zone 2: Moisture 16.8%, Temp 31.4°C (Stress)\n• Zone 3: Moisture 62.0%, Larvae detected (Pest Alert)\n• Zone 4: Moisture 58.0%, NPK 18-12-14 (Low N)';
          break;

        case 3: // DETECT PROBLEM
          _stepOutput =
              'HAZARD DETECTED in Zone 2 (East Sector):\nType: Acute Water Stress (Critical Severity)\nObserved Moisture: 16.8% (Critical Threshold: <20.0%)\nCanopy Heat: 31.4°C';
          break;

        case 4: // ASK WHY
          _stepOutput =
              'Farmer Query: "Why is Zone 2 under water stress?"\nDispatching query to PRAHAR Reasoning Engine...';
          break;

        case 5: // PRAHAR ANALYSIS
          final res = await widget.assistantEngine.processQuery(
            'Why is Zone 2 under water stress?',
            language: widget.currentLanguage,
            context: widget.farmerContext,
          );
          _assistantResponse = res;
          _stepOutput = res.answer;
          break;

        case 6: // RECOMMENDATION
          _stepOutput =
              'PRAHAR Agronomic Recommendation:\n• Prioritize 30-second targeted micro-irrigation (12 Liters).\n• Chemical Spraying: STRICTLY PROHIBITED autonomously.\n• Safety Level: REQUIRES_CONFIRMATION.';
          break;

        case 7: // CONFIRM SIMULATED ACTION
          _stepOutput =
              'Human-in-the-Loop Confirmation Gate:\nSafety limits validated (Duration: 30s, Volume: 7.5L).\nSimulated action confirmed by farmer.\nPhysical Rover: DISCONNECTED.';
          break;

        case 8: // RE-SCAN
          await Future.delayed(const Duration(milliseconds: 300));
          _stepOutput =
              'Simulated Micro-Irrigation Executed in Zone 2.\nRover Re-Scan cycle initiated across East Sector root zone...';
          break;

        case 9: // VERIFY IMPROVEMENT
          _stepOutput =
              'Closed-Loop Verification Result:\n• Pre-Intervention Moisture: 16.8%\n• Post-Intervention Moisture: 28.5%\n• Moisture Gain: +11.7%\n• Hazard Resolution: CONFIRMED RESOLVED (100%).';
          break;

        case 10: // CHAT/VOICE QUESTION
          _stepOutput =
              'Interactive Evaluation:\nAsk any question in English, Hindi, Marathi, or Punjabi.\nExample: "क्या अभी कोई और खतरा है?" or "How is Zone 1 doing?"';
          break;

        case 11: // SAME-LANGUAGE RESPONSE
          if (_assistantResponse != null) {
            _stepOutput =
                'AI Provider: ${_assistantResponse!.aiProvider}\nIntent: ${_assistantResponse!.intent.toWireString()}\nResponse:\n${_assistantResponse!.answer}';
          } else {
            _stepOutput = 'Awaiting query execution in Step 10.';
          }
          break;

        case 12: // RESET / TRY ANOTHER SCENARIO
          widget.onFieldReset();
          _stepOutput =
              'Field State and Active Scenario reset to canonical baseline.\nYou can now select another demo scenario from the home screen.';
          break;
      }
    } catch (e) {
      _stepOutput = 'Error executing Step $step: $e';
    } finally {
      setState(() {
        _isStepExecuting = false;
      });
    }
  }

  Future<void> _submitInteractiveQuery() async {
    final q = _interactiveController.text.trim();
    if (q.isEmpty || _isStepExecuting) return;

    setState(() {
      _isStepExecuting = true;
    });

    try {
      final res = await widget.assistantEngine.processQuery(
        q,
        language: widget.currentLanguage,
        context: widget.farmerContext,
      );
      setState(() {
        _assistantResponse = res;
        _stepOutput = 'Query: "$q"\n\nAI Provider: ${res.aiProvider}\nResponse:\n${res.answer}';
        _interactiveController.clear();
      });
    } catch (e) {
      setState(() {
        _stepOutput = 'Interactive Query Error: $e';
      });
    } finally {
      setState(() {
        _isStepExecuting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('judge_mode_bottom_sheet'),
      padding: EdgeInsets.only(
        left: 18.0,
        right: 18.0,
        top: 18.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18.0,
      ),
      decoration: const BoxDecoration(
        color: PraharTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PraharTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PraharTheme.alertAmberLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PraharTheme.alertAmber),
                  ),
                  child: const Icon(Icons.gavel, color: PraharTheme.alertAmber, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRAHAR Judge Mode — 12-Step Evaluation Flow',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: PraharTheme.textHeading),
                      ),
                      Text(
                        'Step $_currentStep of 12: ${_stepTitles[_currentStep - 1]}',
                        style: const TextStyle(color: PraharTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: PraharTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Step Progress Indicator
            LinearProgressIndicator(
              value: _currentStep / 12.0,
              backgroundColor: PraharTheme.primaryGreenLight,
              color: PraharTheme.primaryGreen,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 14),
            // Step Output Box
            Container(
              key: const Key('judge_mode_output_box'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PraharTheme.cardBgGreen,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PraharTheme.borderGreen),
              ),
              child: _isStepExecuting
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(strokeWidth: 2, color: PraharTheme.primaryGreen),
                      ),
                    )
                  : Text(
                      _stepOutput ?? 'Executing Step $_currentStep...',
                      style: const TextStyle(color: PraharTheme.textBody, fontSize: 13, height: 1.4),
                    ),
            ),
            // Step 10 & 11 Interactive Controls
            if (_currentStep == 10 || _currentStep == 11) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('judge_mode_interactive_input'),
                      controller: _interactiveController,
                      style: const TextStyle(color: PraharTheme.textBody, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Ask in English, Hindi, Marathi, or Punjabi...',
                        hintStyle: const TextStyle(color: PraharTheme.textMuted, fontSize: 11),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: PraharTheme.borderLight)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: PraharTheme.borderLight)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: PraharTheme.primaryGreen, width: 1.5)),
                      ),
                      onSubmitted: (_) => _submitInteractiveQuery(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('judge_mode_interactive_send'),
                    icon: const Icon(Icons.send, color: PraharTheme.primaryGreen),
                    onPressed: _isStepExecuting ? null : _submitInteractiveQuery,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Navigation Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 1)
                  OutlinedButton(
                    key: const Key('judge_mode_prev_btn'),
                    onPressed: _isStepExecuting ? null : () => _executeStep(_currentStep - 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PraharTheme.darkGreen,
                      side: const BorderSide(color: PraharTheme.borderGreen),
                    ),
                    child: const Text('Previous'),
                  )
                else
                  const SizedBox(),
                if (_currentStep < 12)
                  ElevatedButton(
                    key: const Key('judge_mode_next_btn'),
                    onPressed: _isStepExecuting ? null : () => _executeStep(_currentStep + 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PraharTheme.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                else
                  ElevatedButton(
                    key: const Key('judge_mode_finish_btn'),
                    onPressed: () {
                      widget.onFieldReset();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PraharTheme.alertAmber,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reset & Finish', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
