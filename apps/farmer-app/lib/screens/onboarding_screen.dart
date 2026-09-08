import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/auth_service.dart';
import '../core/storage/session_store.dart';
import '../core/storage/offline_store.dart';
import '../core/localization/app_localizations.dart';
import '../domain/farmer_profile.dart';
import '../data/repositories/farmer_profile_repository.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final FarmerProfileRepository? profileRepository;
  final ISessionStore? sessionStore;
  final IOfflineStore? offlineStore;
  final ApiClient? apiClient;
  final AuthService? authService;
  final String initialLanguage;
  final String? prefilledName;
  final bool isEditing;

  const OnboardingScreen({
    super.key,
    this.profileRepository,
    this.sessionStore,
    this.offlineStore,
    this.apiClient,
    this.authService,
    this.initialLanguage = 'en',
    this.prefilledName,
    this.isEditing = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  late String _selectedLanguage;

  // Controllers & Form State
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _districtController = TextEditingController();
  final _villageController = TextEditingController();
  final _areaController = TextEditingController();
  final _cropsController = TextEditingController();
  final _varietyController = TextEditingController();
  final _sowingDateController = TextEditingController();

  String _selectedState = 'Maharashtra';
  String _ownershipType = 'OWNED';
  String _irrigationStatus = 'PARTIAL';
  String _waterSource = 'BOREWELL';
  String _soilType = 'Black Cotton Loam';
  String _season = 'KHARIF';

  late final FarmerProfileRepository _profileRepo;
  bool _isLoading = false;

  final List<String> _indianStates = [
    'Maharashtra',
    'Punjab',
    'Madhya Pradesh',
    'Uttar Pradesh',
    'Rajasthan',
    'Gujarat',
    'Haryana',
    'Karnataka',
    'Andhra Pradesh',
    'Telangana',
    'Tamil Nadu',
    'Bihar',
    'West Bengal',
    'Odisha',
  ];

  final List<String> _soilTypes = [
    'Black Cotton Loam',
    'Clay Loam',
    'Sandy Loam',
    'Red Soil',
    'Alluvial Soil',
    'Silt Loam',
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    final store = widget.offlineStore ?? StructuredFileOfflineStore();
    final api = widget.apiClient ??
        ApiClient(sessionStore: widget.sessionStore ?? SecureFileSessionStore());
    _profileRepo = widget.profileRepository ??
        FarmerProfileRepository(apiClient: api, offlineStore: store);

    if (widget.prefilledName != null && widget.prefilledName!.isNotEmpty) {
      _nameController.text = widget.prefilledName!;
    }

    _loadExistingState();
  }

  Future<void> _loadExistingState() async {
    setState(() => _isLoading = true);
    try {
      final state = await _profileRepo.getOnboardingState();
      if (mounted) {
        setState(() {
          if (_nameController.text.isEmpty && state.profile.name.isNotEmpty) {
            _nameController.text = state.profile.name;
          }
          if (state.profile.state.isNotEmpty) {
            _selectedState = state.profile.state;
          }
          _districtController.text = state.profile.district;
          _villageController.text = state.profile.village;
          _areaController.text = state.farm.areaAcres.toString();
          _ownershipType = state.farm.ownershipType;
          _irrigationStatus = state.farm.irrigationStatus;
          _waterSource = state.farm.waterSource;
          _soilType = state.farm.soilType;
          _cropsController.text = state.crops.mainCrops.join(', ');
          _season = state.crops.season;
          _varietyController.text = state.crops.variety ?? '';
          _sowingDateController.text = state.crops.sowingDate ?? '';
          _selectedLanguage = state.profile.preferredLanguage;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _villageController.dispose();
    _areaController.dispose();
    _cropsController.dispose();
    _varietyController.dispose();
    _sowingDateController.dispose();
    super.dispose();
  }

  String _t(String key) => AppLocalizations.getText(key, _selectedLanguage);

  void _quickFillCanonicalDemo() {
    setState(() {
      _nameController.text = 'Ramesh Patil';
      _selectedState = 'Maharashtra';
      _districtController.text = 'Amravati';
      _villageController.text = 'Nandgaon Khandeshwar';
      _areaController.text = '4.2';
      _ownershipType = 'OWNED';
      _irrigationStatus = 'PARTIAL';
      _waterSource = 'BOREWELL';
      _soilType = 'Black Cotton Loam';
      _cropsController.text = 'Soybean, Wheat';
      _season = 'KHARIF';
      _varietyController.text = 'JS 335 / GW 322';
      _sowingDateController.text = '2026-06-25';
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedLanguage == 'hi'
              ? 'रमेश पाटिल (4.2 एकड़, महाराष्ट्र) का कैनोनिकल डेटा भरा गया!'
              : 'Canonical Demo Data (Ramesh Patil • 4.2 Acres) loaded!',
        ),
        backgroundColor: PraharTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _completeSetup() async {
    final area = double.tryParse(_areaController.text.trim()) ?? 4.2;
    final cropsList = _cropsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final state = FarmerOnboardingState(
      profile: FarmerProfileModel(
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Ramesh Patil',
        state: _selectedState,
        district: _districtController.text.trim().isNotEmpty
            ? _districtController.text.trim()
            : 'Amravati',
        village: _villageController.text.trim().isNotEmpty
            ? _villageController.text.trim()
            : 'Nandgaon Khandeshwar',
        preferredLanguage: _selectedLanguage,
      ),
      farm: FarmSetupModel(
        areaAcres: area,
        ownershipType: _ownershipType,
        irrigationStatus: _irrigationStatus,
        waterSource: _waterSource,
        soilType: _soilType,
      ),
      crops: CropSetupModel(
        mainCrops: cropsList.isNotEmpty ? cropsList : ['Soybean', 'Wheat'],
        season: _season,
        variety: _varietyController.text.trim().isNotEmpty
            ? _varietyController.text.trim()
            : null,
        sowingDate: _sowingDateController.text.trim().isNotEmpty
            ? _sowingDateController.text.trim()
            : null,
      ),
      isCompleted: true,
      completedAt: DateTime.now().toIso8601String(),
    );

    setState(() => _isLoading = true);
    await _profileRepo.saveOnboardingState(state);

    if (mounted) {
      if (widget.isEditing) {
        Navigator.pop(context, true);
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              authService: widget.authService,
              apiClient: widget.apiClient,
              sessionStore: widget.sessionStore,
              offlineStore: widget.offlineStore,
              initialLanguage: _selectedLanguage,
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08100C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1410),
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'PRAHAR',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: PraharTheme.primaryGreen),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: PraharTheme.borderGreen,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.isEditing ? 'PROFILE EDIT' : 'ONBOARDING',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          // Quick Fill Demo Button in AppBar
          TextButton.icon(
            key: const Key('quick_fill_demo_button'),
            icon: const Icon(Icons.flash_on,
                size: 16, color: PraharTheme.alertAmber),
            label: Text(
              _t('load_demo_btn'),
              style: const TextStyle(
                  color: PraharTheme.alertAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
            onPressed: _quickFillCanonicalDemo,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: PraharTheme.primaryGreen))
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Step Indicator Bar
                  _buildStepIndicator(),
                  // Step Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildCurrentStepContent(),
                    ),
                  ),
                  // Bottom Navigation Controls
                  _buildBottomNavigation(),
                ],
              ),
            ),
    );
  }

  Widget _buildStepIndicator() {
    final titles = [
      _t('step_language_title'),
      _t('step_profile_title'),
      _t('step_farm_title'),
      _t('step_crop_title'),
      _t('step_review_title'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF0E1813),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of 5: ${titles[_currentStep]}',
                style: const TextStyle(
                    color: PraharTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              Text(
                '${((_currentStep + 1) / 5 * 100).toInt()}%',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 5,
            backgroundColor: const Color(0xFF1B2B22),
            valueColor:
                const AlwaysStoppedAnimation<Color>(PraharTheme.primaryGreen),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildLanguageStep();
      case 1:
        return _buildProfileStep();
      case 2:
        return _buildFarmStep();
      case 3:
        return _buildCropStep();
      case 4:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  // STEP 0: Language Selection
  Widget _buildLanguageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('step_language_title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _t('step_language_desc'),
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        ...AppLocalizations.supportedLanguages.map((code) {
          final isSelected = _selectedLanguage == code;
          final name = AppLocalizations.languageDisplayNames[code] ?? code;
          return Card(
            key: Key('lang_option_$code'),
            color: isSelected ? const Color(0xFF13281F) : const Color(0xFF0F1B15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected
                    ? PraharTheme.primaryGreen
                    : PraharTheme.borderGreen,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Radio<String>(
                value: code,
                groupValue: _selectedLanguage,
                activeColor: PraharTheme.primaryGreen,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLanguage = val);
                },
              ),
              title: Text(
                name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey[300],
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle,
                      color: PraharTheme.primaryGreen, size: 20)
                  : null,
              onTap: () => setState(() => _selectedLanguage = code),
            ),
          );
        }),
      ],
    );
  }

  // STEP 1: Farmer Identity
  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('step_profile_title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _t('step_profile_desc'),
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        Text(_t('farmer_name_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('onboarding_name_field'),
          controller: _nameController,
          decoration: InputDecoration(
            hintText: _t('farmer_name_hint'),
            prefixIcon: const Icon(Icons.person, color: PraharTheme.primaryGreen, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter farmer name';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        Text(_t('state_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const Key('onboarding_state_dropdown'),
          value: _selectedState,
          dropdownColor: const Color(0xFF131F19),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.map, color: PraharTheme.primaryGreen, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: _indianStates.map((s) {
            return DropdownMenuItem(value: s, child: Text(s));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedState = val);
          },
        ),
        const SizedBox(height: 14),
        Text(_t('district_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('onboarding_district_field'),
          controller: _districtController,
          decoration: InputDecoration(
            hintText: _t('district_hint'),
            prefixIcon: const Icon(Icons.location_city, color: PraharTheme.primaryGreen, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 14),
        Text(_t('village_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('onboarding_village_field'),
          controller: _villageController,
          decoration: InputDecoration(
            hintText: _t('village_hint'),
            prefixIcon: const Icon(Icons.home, color: PraharTheme.primaryGreen, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  // STEP 2: Farm Details
  Widget _buildFarmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('step_farm_title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _t('step_farm_desc'),
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        Text(_t('land_area_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('onboarding_area_field'),
          controller: _areaController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: _t('land_area_hint'),
            prefixIcon: const Icon(Icons.square_foot, color: PraharTheme.primaryGreen, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: (val) {
            if (val == null || double.tryParse(val.trim()) == null) {
              return 'Please enter valid area in acres';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        Text(_t('ownership_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const Key('onboarding_ownership_dropdown'),
          value: _ownershipType,
          dropdownColor: const Color(0xFF131F19),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.assignment, color: PraharTheme.primaryGreen, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: [
            DropdownMenuItem(value: 'OWNED', child: Text(_t('ownership_owned'))),
            DropdownMenuItem(value: 'TENANT', child: Text(_t('ownership_tenant'))),
            DropdownMenuItem(
                value: 'SHARECROPPER', child: Text(_t('ownership_sharecropper'))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _ownershipType = val);
          },
        ),
        const SizedBox(height: 14),
        Text(_t('irrigation_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const Key('onboarding_irrigation_dropdown'),
          value: _irrigationStatus,
          dropdownColor: const Color(0xFF131F19),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.water_drop, color: PraharTheme.alertSky, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: [
            DropdownMenuItem(
                value: 'IRRIGATED', child: Text(_t('irrigation_irrigated'))),
            DropdownMenuItem(
                value: 'PARTIAL', child: Text(_t('irrigation_partial'))),
            DropdownMenuItem(
                value: 'RAINFED', child: Text(_t('irrigation_rainfed'))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _irrigationStatus = val);
          },
        ),
        const SizedBox(height: 14),
        Text(_t('water_source_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const Key('onboarding_water_source_dropdown'),
          value: _waterSource,
          dropdownColor: const Color(0xFF131F19),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.waves, color: PraharTheme.alertSky, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: [
            DropdownMenuItem(value: 'BOREWELL', child: Text(_t('water_borewell'))),
            DropdownMenuItem(value: 'CANAL', child: Text(_t('water_canal'))),
            DropdownMenuItem(value: 'OPEN_WELL', child: Text(_t('water_open_well'))),
            DropdownMenuItem(value: 'RIVER', child: Text(_t('water_river'))),
            DropdownMenuItem(value: 'RAINFED', child: Text(_t('water_rainfed'))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _waterSource = val);
          },
        ),
        const SizedBox(height: 14),
        Text(_t('soil_type_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const Key('onboarding_soil_dropdown'),
          value: _soilType,
          dropdownColor: const Color(0xFF131F19),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.landscape, color: PraharTheme.alertAmber, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: _soilTypes.map((st) {
            return DropdownMenuItem(value: st, child: Text(st));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _soilType = val);
          },
        ),
      ],
    );
  }

  // STEP 3: Crop Details
  Widget _buildCropStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('step_crop_title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _t('step_crop_desc'),
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        Text(_t('crops_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('onboarding_crops_field'),
          controller: _cropsController,
          decoration: InputDecoration(
            hintText: _t('crops_hint'),
            prefixIcon: const Icon(Icons.grass, color: PraharTheme.primaryGreen, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter at least one main crop';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        // Preset Crop Chips for Quick Selection
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ['Soybean', 'Wheat', 'Cotton', 'Rice', 'Tomato', 'Gram'].map((c) {
            return ActionChip(
              visualDensity: VisualDensity.compact,
              label: Text(c, style: const TextStyle(fontSize: 11)),
              backgroundColor: const Color(0xFF122019),
              onPressed: () {
                final current = _cropsController.text.trim();
                if (current.isEmpty) {
                  _cropsController.text = c;
                } else if (!current.contains(c)) {
                  _cropsController.text = '$current, $c';
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Text(_t('season_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const Key('onboarding_season_dropdown'),
          value: _season,
          dropdownColor: const Color(0xFF131F19),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.calendar_today, color: PraharTheme.primaryGreen, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: [
            DropdownMenuItem(value: 'KHARIF', child: Text(_t('season_kharif'))),
            DropdownMenuItem(value: 'RABI', child: Text(_t('season_rabi'))),
            DropdownMenuItem(value: 'ZAID', child: Text(_t('season_zaid'))),
            DropdownMenuItem(
                value: 'YEAR_ROUND', child: Text(_t('season_year_round'))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _season = val);
          },
        ),
        const SizedBox(height: 14),
        Text(_t('variety_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('onboarding_variety_field'),
          controller: _varietyController,
          decoration: InputDecoration(
            hintText: _t('variety_hint'),
            prefixIcon: const Icon(Icons.eco, color: PraharTheme.primaryGreen, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 14),
        Text(_t('sowing_date_label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('onboarding_sowing_date_field'),
          controller: _sowingDateController,
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD (e.g. 2026-06-25)',
            prefixIcon: const Icon(Icons.event, color: PraharTheme.primaryGreen, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  // STEP 4: Review & Confirm
  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('step_review_title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _t('step_review_desc'),
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        // Review Card
        Card(
          color: const Color(0xFF101F18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: PraharTheme.borderGreen),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewRow(
                  Icons.person,
                  _t('farmer_name_label'),
                  _nameController.text.trim().isNotEmpty
                      ? _nameController.text.trim()
                      : 'Ramesh Patil',
                ),
                const Divider(height: 16, color: PraharTheme.borderGreen),
                _buildReviewRow(
                  Icons.location_on,
                  _t('state_label') + ' & District',
                  '$_selectedState, ${_districtController.text.trim().isNotEmpty ? _districtController.text.trim() : "Amravati"}',
                ),
                const Divider(height: 16, color: PraharTheme.borderGreen),
                _buildReviewRow(
                  Icons.crop_free,
                  _t('land_area_label'),
                  '${_areaController.text.trim().isNotEmpty ? _areaController.text.trim() : "4.2"} Acres ($_ownershipType)',
                ),
                const Divider(height: 16, color: PraharTheme.borderGreen),
                _buildReviewRow(
                  Icons.water_drop,
                  _t('irrigation_label'),
                  '$_irrigationStatus ($_waterSource)',
                ),
                const Divider(height: 16, color: PraharTheme.borderGreen),
                _buildReviewRow(
                  Icons.landscape,
                  _t('soil_type_label'),
                  _soilType,
                ),
                const Divider(height: 16, color: PraharTheme.borderGreen),
                _buildReviewRow(
                  Icons.grass,
                  _t('crops_label'),
                  '${_cropsController.text.trim().isNotEmpty ? _cropsController.text.trim() : "Soybean, Wheat"} ($_season)',
                ),
                const Divider(height: 16, color: PraharTheme.borderGreen),
                _buildReviewRow(
                  Icons.language,
                  _t('step_language_title'),
                  AppLocalizations.languageDisplayNames[_selectedLanguage] ??
                      _selectedLanguage,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Canonical Demo Notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PraharTheme.alertAmber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: PraharTheme.alertAmber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('demo_banner_subtitle'),
                  style: const TextStyle(
                      fontSize: 11, color: PraharTheme.alertAmber),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: PraharTheme.primaryGreen),
        const SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0C1410),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              key: const Key('onboarding_back_button'),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: Text(_t('back_btn')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: PraharTheme.borderGreen),
              ),
              onPressed: () => setState(() => _currentStep--),
            )
          else
            const SizedBox(width: 80),
          ElevatedButton.icon(
            key: _currentStep == 4
                ? const Key('finish_onboarding_button')
                : const Key('onboarding_next_button'),
            icon: Icon(
              _currentStep == 4 ? Icons.check : Icons.arrow_forward,
              size: 16,
            ),
            label: Text(
              _currentStep == 4
                  ? (widget.isEditing ? _t('save_btn') : _t('finish_btn'))
                  : _t('continue_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: PraharTheme.primaryGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              if (_currentStep == 4) {
                _completeSetup();
              } else {
                if (_currentStep == 1 || _currentStep == 2 || _currentStep == 3) {
                  if (!_formKey.currentState!.validate()) return;
                }
                setState(() => _currentStep++);
              }
            },
          ),
        ],
      ),
    );
  }
}
