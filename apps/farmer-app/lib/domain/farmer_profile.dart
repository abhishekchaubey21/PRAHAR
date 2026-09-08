/// PRAHAR Farmer App — Farmer Profile, Farm Setup & Onboarding Models
/// Aligned with Phase 7A: Comprehensive Farmer Identity, Farm Topology, and Crop Profile.

class FarmerProfileModel {
  final String name;
  final String state;
  final String district;
  final String village;
  final String preferredLanguage; // 'en', 'hi', 'mr', 'pa'

  const FarmerProfileModel({
    required this.name,
    required this.state,
    required this.district,
    required this.village,
    this.preferredLanguage = 'en',
  });

  factory FarmerProfileModel.fromJson(Map<String, dynamic> json) {
    return FarmerProfileModel(
      name: json['name'] as String? ?? '',
      state: json['state'] as String? ?? 'Maharashtra',
      district: json['district'] as String? ?? 'Amravati',
      village: json['village'] as String? ?? 'Nandgaon Khandeshwar',
      preferredLanguage: json['preferred_language'] as String? ??
          json['language'] as String? ??
          'en',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'state': state,
        'district': district,
        'village': village,
        'preferred_language': preferredLanguage,
      };

  FarmerProfileModel copyWith({
    String? name,
    String? state,
    String? district,
    String? village,
    String? preferredLanguage,
  }) {
    return FarmerProfileModel(
      name: name ?? this.name,
      state: state ?? this.state,
      district: district ?? this.district,
      village: village ?? this.village,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}

class FarmSetupModel {
  final double areaAcres;
  final String ownershipType; // 'OWNED', 'TENANT', 'SHARECROPPER'
  final String irrigationStatus; // 'IRRIGATED', 'PARTIAL', 'RAINFED'
  final String waterSource; // 'BOREWELL', 'CANAL', 'OPEN_WELL', 'RIVER', 'RAINFED'
  final String soilType;

  const FarmSetupModel({
    required this.areaAcres,
    required this.ownershipType,
    required this.irrigationStatus,
    required this.waterSource,
    required this.soilType,
  });

  double get landAcres => areaAcres;

  factory FarmSetupModel.fromJson(Map<String, dynamic> json) {
    return FarmSetupModel(
      areaAcres: (json['area_acres'] as num?)?.toDouble() ?? 4.2,
      ownershipType: json['ownership_type'] as String? ?? 'OWNED',
      irrigationStatus: json['irrigation_status'] as String? ?? 'PARTIAL',
      waterSource: json['water_source'] as String? ?? 'BOREWELL',
      soilType: json['soil_type'] as String? ?? 'Black Cotton Loam',
    );
  }

  Map<String, dynamic> toJson() => {
        'area_acres': areaAcres,
        'ownership_type': ownershipType,
        'irrigation_status': irrigationStatus,
        'water_source': waterSource,
        'soil_type': soilType,
      };

  FarmSetupModel copyWith({
    double? areaAcres,
    String? ownershipType,
    String? irrigationStatus,
    String? waterSource,
    String? soilType,
  }) {
    return FarmSetupModel(
      areaAcres: areaAcres ?? this.areaAcres,
      ownershipType: ownershipType ?? this.ownershipType,
      irrigationStatus: irrigationStatus ?? this.irrigationStatus,
      waterSource: waterSource ?? this.waterSource,
      soilType: soilType ?? this.soilType,
    );
  }
}

class CropSetupModel {
  final List<String> mainCrops;
  final String season; // 'KHARIF', 'RABI', 'ZAID', 'YEAR_ROUND'
  final String? variety;
  final String? sowingDate;

  const CropSetupModel({
    required this.mainCrops,
    required this.season,
    this.variety,
    this.sowingDate,
  });

  factory CropSetupModel.fromJson(Map<String, dynamic> json) {
    final rawCrops = json['main_crops'];
    List<String> crops = ['Soybean', 'Wheat'];
    if (rawCrops is List) {
      crops = rawCrops.map((e) => e.toString()).toList();
    } else if (rawCrops is String) {
      crops = rawCrops.split(',').map((e) => e.trim()).toList();
    }

    return CropSetupModel(
      mainCrops: crops,
      season: json['season'] as String? ?? 'KHARIF',
      variety: json['variety'] as String? ?? 'JS 335 / GW 322',
      sowingDate: json['sowing_date'] as String? ?? '2026-06-25',
    );
  }

  Map<String, dynamic> toJson() => {
        'main_crops': mainCrops,
        'season': season,
        'variety': variety,
        'sowing_date': sowingDate,
      };

  CropSetupModel copyWith({
    List<String>? mainCrops,
    String? season,
    String? variety,
    String? sowingDate,
  }) {
    return CropSetupModel(
      mainCrops: mainCrops ?? this.mainCrops,
      season: season ?? this.season,
      variety: variety ?? this.variety,
      sowingDate: sowingDate ?? this.sowingDate,
    );
  }
}

class FarmerOnboardingState {
  final FarmerProfileModel profile;
  final FarmSetupModel farm;
  final CropSetupModel crops;
  final bool isCompleted;
  final String? completedAt;

  const FarmerOnboardingState({
    required this.profile,
    required this.farm,
    required this.crops,
    this.isCompleted = false,
    this.completedAt,
  });

  factory FarmerOnboardingState.fromJson(Map<String, dynamic> json) {
    return FarmerOnboardingState(
      profile: json['profile'] != null
          ? FarmerProfileModel.fromJson(json['profile'] as Map<String, dynamic>)
          : const FarmerProfileModel(
              name: 'Ramesh Patil',
              state: 'Maharashtra',
              district: 'Amravati',
              village: 'Nandgaon Khandeshwar',
            ),
      farm: json['farm'] != null
          ? FarmSetupModel.fromJson(json['farm'] as Map<String, dynamic>)
          : const FarmSetupModel(
              areaAcres: 4.2,
              ownershipType: 'OWNED',
              irrigationStatus: 'PARTIAL',
              waterSource: 'BOREWELL',
              soilType: 'Black Cotton Loam',
            ),
      crops: json['crops'] != null
          ? CropSetupModel.fromJson(json['crops'] as Map<String, dynamic>)
          : const CropSetupModel(
              mainCrops: ['Soybean', 'Wheat'],
              season: 'KHARIF',
              variety: 'JS 335 / GW 322',
              sowingDate: '2026-06-25',
            ),
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'farm': farm.toJson(),
        'crops': crops.toJson(),
        'is_completed': isCompleted,
        'completed_at': completedAt,
      };

  /// Canonical Deterministic Demo Dataset for SIH Evaluation
  static FarmerOnboardingState canonicalDemo() {
    return const FarmerOnboardingState(
      profile: FarmerProfileModel(
        name: 'Ramesh Patil',
        state: 'Maharashtra',
        district: 'Amravati',
        village: 'Nandgaon Khandeshwar',
        preferredLanguage: 'en',
      ),
      farm: FarmSetupModel(
        areaAcres: 4.2,
        ownershipType: 'OWNED',
        irrigationStatus: 'PARTIAL',
        waterSource: 'BOREWELL',
        soilType: 'Black Cotton Loam',
      ),
      crops: CropSetupModel(
        mainCrops: ['Soybean', 'Wheat'],
        season: 'KHARIF',
        variety: 'JS 335 / GW 322',
        sowingDate: '2026-06-25',
      ),
      isCompleted: true,
      completedAt: '2026-09-08T00:00:00Z',
    );
  }
}
