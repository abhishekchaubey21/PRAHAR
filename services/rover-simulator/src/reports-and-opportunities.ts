/**
 * PRAHAR Field Evidence Report & Farmer Opportunity Center
 * Aligned with Amendments 1 & 2:
 * - Field Evidence Report: Informational evidence report with mandatory non-official declaration
 * - Opportunity Center: Real, source-backed Indian agricultural schemes with verified official URLs
 */

import {
  FieldEvidenceReport,
  FarmerOpportunity,
  RoverScanPayload,
  RemediationVerification,
} from '@prahar/shared';

// ============================================================================
// 1. Field Evidence Report Generator
// ============================================================================

export class FieldEvidenceReportGenerator {
  public static generateReport(params: {
    farmId: string;
    farmName: string;
    zoneId: string;
    scan: RoverScanPayload;
    actionExecuted: string;
    approvedBy?: string;
    verification?: RemediationVerification;
  }): FieldEvidenceReport {
    const { farmId, farmName, zoneId, scan, actionExecuted, approvedBy, verification } = params;

    const moisture = scan.sensor_readings.find((r) => r.type === 'moisture')?.value ?? 16.5;
    const temperature = scan.sensor_readings.find((r) => r.type === 'temperature')?.value ?? 34.5;
    const humidity = scan.sensor_readings.find((r) => r.type === 'humidity')?.value ?? 48.0;
    const ph = scan.sensor_readings.find((r) => r.type === 'ph')?.value ?? 6.8;

    const primaryDetection = scan.detections[0] || {
      hazard_type: 'WATER_STRESS',
      hazard_name: 'Severe Soil Moisture Depletion',
      severity_hint: 'HIGH',
      confidence: 0.92,
    };

    return {
      report_id: `rep-${zoneId.toLowerCase()}-${Date.now().toString(36)}`,
      report_title: 'PRAHAR Field Evidence Report',
      farm_id: farmId,
      farm_name: farmName,
      zone_id: zoneId,
      generated_at: new Date().toISOString(),
      scan_time: scan.timestamp,
      hazard_summary: {
        hazard_type: primaryDetection.hazard_type,
        hazard_name: primaryDetection.hazard_name,
        severity: primaryDetection.severity_hint || 'HIGH',
        detection_confidence: primaryDetection.confidence,
      },
      sensor_evidence: {
        moisture,
        temperature,
        humidity,
        ph,
      },
      weather_context_summary: 'Regional forecast: negligible rain (< 2mm), midday heat > 33°C.',
      recommendation_made: 'Micro-irrigation recommended for 30s (~7.5L) under mandatory safety gate.',
      action_approved_by: approvedBy,
      action_executed: actionExecuted,
      before_after_metrics: verification
        ? {
            pre_moisture: verification.pre_moisture,
            post_moisture: verification.post_moisture,
            delta: verification.moisture_delta,
            resolution_status: verification.resolved ? 'RESOLVED (SUCCESS)' : 'INCOMPLETE',
          }
        : undefined,
      verification_outcome: verification
        ? `Soil moisture elevated by +${verification.moisture_delta}% (from ${verification.pre_moisture}% to ${verification.post_moisture}%). Condition resolved.`
        : 'Awaiting closed-loop re-scan verification.',
      disclaimer:
        'NOTICE: This document is a PRAHAR-generated informational field evidence report produced from simulated rover sensor observations and edge AI detection outputs for demonstration purposes. It is NOT an official government certificate, certified statutory audit, or legal agricultural warranty.',
    };
  }
}

// ============================================================================
// 2. Farmer Opportunity Center (Source-Backed & Verified Indian Schemes)
// ============================================================================

export class OpportunityCenter {
  private static readonly SCHEMES: FarmerOpportunity[] = [
    {
      scheme_id: 'PM-KUSUM-SOLAR',
      title_en: 'PM-KUSUM Scheme (Component B & C: Standalone Solar Agriculture Pumps)',
      title_hi: 'पीएम-कुसुम योजना (घटक बी और सी: सोलर कृषि पंप)',
      category: 'SOLAR_PUMP',
      source_type: 'OFFICIAL_GOVERNMENT_SCHEME',
      sponsoring_agency: 'Ministry of New and Renewable Energy (MNRE), Government of India',
      description_en: 'Provides central financial assistance up to 30% (with additional state subsidy up to 30%) for installing standalone solar agricultural pumps and solarizing grid-connected agriculture pumps.',
      description_hi: 'सोलर कृषि पंप लगाने और ग्रिड से जुड़े पंपों के सौरकरण के लिए 30% केंद्रीय वित्तीय सहायता (और राज्य द्वारा 30% अतिरिक्त सब्सिडी) प्रदान की जाती है।',
      eligibility_criteria_en: [
        'Individual farmers, Water User Associations, and Farmer Producer Organizations (FPOs).',
        'Valid agricultural land title in applicant name.',
        'Existing diesel pump to be replaced or grid connection to be solarized.',
      ],
      eligibility_criteria_hi: [
        'व्यक्तिगत किसान, जल उपभोक्ता संघ, और किसान उत्पादक संगठन (FPO)।',
        'आवेदक के नाम पर वैध कृषि भूमि का मालिकाना हक।',
        'प्रतिस्थापित किया जाने वाला डीजल पंप या सौर ऊर्जा से जोड़ा जाने वाला ग्रिड कनेक्शन।',
      ],
      required_documents: [
        'Aadhaar Card',
        'Land Ownership Record (Khatauni / Jamabandi / 7/12 extract)',
        'Bank Account Passbook / Cancelled Cheque',
        'Valid Electricity Consumer Number (for Component C solarization)',
      ],
      official_portal_url: 'https://pmkusum.mnre.gov.in',
      application_procedure_summary_en: 'Apply online through designated State Nodal Agency (SNA) portal linked from MNRE PM-KUSUM official portal. Select empaneled solar pump vendor after state sanction.',
      application_procedure_summary_hi: 'एमएनआरई पीएम-कुसुम पोर्टल से जुड़े राज्य नोडल एजेंसी पोर्टल के माध्यम से ऑनलाइन आवेदन करें। राज्य से स्वीकृति के बाद पैनल में शामिल वेंडर का चयन करें।',
      prahar_assistance_note_en: 'PRAHAR generates field evidence and moisture requirements but does NOT submit government applications directly. Farmers must apply through official state portals.',
      prahar_assistance_note_hi: 'प्रहार खेत साक्ष्य और सिंचाई आवश्यकता उत्पन्न करता है परंतु सरकारी आवेदन सीधे जमा नहीं करता है। किसानों को आधिकारिक राज्य पोर्टल से आवेदन करना होगा।',
    },
    {
      scheme_id: 'PMKSY-PDMC-MICRO-IRRIGATION',
      title_en: 'Per Drop More Crop (PDMC) under Pradhan Mantri Krishi Sinchayee Yojana (PMKSY)',
      title_hi: 'प्रति बूंद अधिक फसल (पीडीएमसी) — प्रधानमंत्री कृषि सिंचाई योजना',
      category: 'MICRO_IRRIGATION',
      source_type: 'OFFICIAL_GOVERNMENT_SCHEME',
      sponsoring_agency: 'Department of Agriculture & Farmers Welfare, Government of India',
      description_en: 'Financial assistance of 55% for Small & Marginal farmers and 45% for other farmers for adoption of micro-irrigation systems (Drip and Sprinkler technologies).',
      description_hi: 'सूक्ष्म-सिंचाई प्रणालियों (ड्रिप और स्प्रिंकलर) को अपनाने के लिए लघु और सीमांत किसानों को 55% तथा अन्य किसानों को 45% की वित्तीय सहायता।',
      eligibility_criteria_en: [
        'All categories of farmers owning cultivable agricultural land.',
        'Registered with state agriculture/horticulture department portal.',
      ],
      eligibility_criteria_hi: [
        'खेती योग्य कृषि भूमि के स्वामी सभी श्रेणियों के किसान।',
        'राज्य कृषि/उद्यान विभाग पोर्टल पर पंजीकृत।',
      ],
      required_documents: [
        'Aadhaar Card',
        'Land Record (ROR / Khasra-Khatauni)',
        'Bank Passbook with IFSC',
        'Soil and Water Test Report (optional in some states)',
      ],
      official_portal_url: 'https://pmksy.gov.in',
      application_procedure_summary_en: 'Register on state horticulture/agriculture department portal, submit land documents and farmer details, obtain administrative sanction, and install through registered micro-irrigation suppliers.',
      application_procedure_summary_hi: 'राज्य उद्यानिकी/कृषि विभाग पोर्टल पर पंजीकरण करें, भूमि दस्तावेज जमा करें और पंजीकृत आपूर्तिकर्ताओं के माध्यम से उपकरण स्थापित कराएं।',
      prahar_assistance_note_en: 'PRAHAR soil moisture telemetry and closed-loop verification metrics can be included as supporting documentation in the PRAHAR Field Evidence Report.',
      prahar_assistance_note_hi: 'प्रहार मिट्टी नमी टेलीमेट्री और सत्यापन मेट्रिक्स को प्रहार फील्ड एविडेंस रिपोर्ट के रूप में सहायक साक्ष्य हेतु उपयोग किया जा सकता है।',
    },
    {
      scheme_id: 'SMAM-PRECISION-AG-SUBSIDY',
      title_en: 'Sub-Mission on Agricultural Mechanization (SMAM)',
      title_hi: 'कृषि यंत्रीकरण पर उप-मिशन (एसएमएएम)',
      category: 'EQUIPMENT_SUBSIDY',
      source_type: 'OFFICIAL_GOVERNMENT_SCHEME',
      sponsoring_agency: 'Ministry of Agriculture & Farmers Welfare, Government of India',
      description_en: 'Subsidies ranging from 40% to 50% for individual farmers (up to 80% for Custom Hiring Centers) on agricultural equipment, robotic scouting platforms, and farm mechanization machinery.',
      description_hi: 'कृषि उपकरणों, रोबोटिक निरीक्षण प्रणालियों और कृषि मशीनीकरण पर व्यक्तिगत किसानों को 40% से 50% सब्सिडी (कस्टम हायरिंग केंद्रों के लिए 80% तक)।',
      eligibility_criteria_en: [
        'Individual farmers with verified Aadhaar and landholding.',
        'Self Help Groups (SHGs) and Cooperative Societies eligible for Custom Hiring Centers.',
      ],
      eligibility_criteria_hi: [
        'सत्यापित आधार और जोत वाले व्यक्तिगत किसान।',
        'कस्टम हायरिंग केंद्रों के लिए स्वयं सहायता समूह और सहकारी समितियां।',
      ],
      required_documents: [
        'Aadhaar Card',
        'Land Records (Khatauni / Patta)',
        'Caste Certificate (if claiming affirmative category subsidies)',
        'Bank Account Details',
      ],
      official_portal_url: 'https://agrimachinery.nic.in',
      application_procedure_summary_en: 'Register on Direct Benefit Transfer (DBT) portal for agricultural mechanization (agrimachinery.nic.in), select equipment category, upload documents, and track subsidy status.',
      application_procedure_summary_hi: 'कृषि मशीनीकरण हेतु प्रत्यक्ष लाभ अंतरण पोर्टल (agrimachinery.nic.in) पर पंजीकरण करें, उपकरण श्रेणी चुनें, और सब्सिडी की स्थिति ट्रैक करें।',
      prahar_assistance_note_en: 'PRAHAR platform provides informational guidance only. Subsidies are disbursed directly to farmer bank accounts by the government.',
      prahar_assistance_note_hi: 'प्रहार मंच केवल सूचनात्मक मार्गदर्शन प्रदान करता है। सब्सिडी सरकार द्वारा सीधे किसान के बैंक खाते में भेजी जाती है।',
    },
    {
      scheme_id: 'PMFBY-CROP-INSURANCE',
      title_en: 'Pradhan Mantri Fasal Bima Yojana (PMFBY)',
      title_hi: 'प्रधानमंत्री फसल बीमा योजना (पीएमएफबीवाई)',
      category: 'CROP_INSURANCE',
      source_type: 'OFFICIAL_GOVERNMENT_SCHEME',
      sponsoring_agency: 'Ministry of Agriculture & Farmers Welfare, Government of India',
      description_en: 'Comprehensive crop insurance covering yield losses due to non-preventable natural risks (drought, dry spells, flood, pest and disease outbreak). Farmers pay minimal premium (2% for Kharif, 1.5% for Rabi, 5% for commercial/horticulture crops).',
      description_hi: 'प्राकृतिक जोखिमों (सूखा, बाढ़, कीट और रोग) से फसल क्षति के लिए व्यापक बीमा। किसान केवल न्यूनतम प्रीमियम (खरीफ 2%, रबी 1.5%, बागवानी 5%) का भुगतान करते हैं।',
      eligibility_criteria_en: [
        'All farmers growing notified crops in notified areas, including sharecroppers and tenant farmers.',
      ],
      eligibility_criteria_hi: [
        'अधिसूचित क्षेत्रों में अधिसूचित फसलें उगाने वाले सभी किसान, जिनमें बटाईदार और किरायेदार किसान भी शामिल हैं।',
      ],
      required_documents: [
        'Aadhaar Card',
        'Sowing Certificate / Patwari Report',
        'Land Ownership Record (LPC / Khasra)',
        'Active Bank Account Passbook',
      ],
      official_portal_url: 'https://pmfby.gov.in',
      application_procedure_summary_en: 'Enroll through bank branch, Common Service Center (CSC), or National Crop Insurance Portal (pmfby.gov.in) before cutoff date. In case of localized crop loss, report within 72 hours via Crop Insurance App.',
      application_procedure_summary_hi: 'अंतिम तिथि से पहले बैंक शाखा, सीएससी या राष्ट्रीय फसल बीमा पोर्टल (pmfby.gov.in) पर नामांकन करें। फसल नुकसान होने पर 72 घंटे के भीतर क्रॉप इंश्योरेंस ऐप पर सूचना दें।',
      prahar_assistance_note_en: 'PRAHAR vision detections and before/after verification logs can be exported in the Field Evidence Report to support 72-hour localized event damage reporting.',
      prahar_assistance_note_hi: 'प्रहार विजन पहचान और सत्यापन लॉग को 72 घंटे के भीतर नुकसान की सूचना देने में सहायक साक्ष्य के रूप में उपयोग किया जा सकता है।',
    },
  ];

  public static getSchemes(): FarmerOpportunity[] {
    return this.SCHEMES;
  }

  public static getSchemeById(id: string): FarmerOpportunity | undefined {
    return this.SCHEMES.find((s) => s.scheme_id === id);
  }
}
