import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../data/repositories/opportunity_repository.dart';

class OpportunityCenterScreen extends StatefulWidget {
  final OpportunityRepository opportunityRepository;
  final bool isHindi;
  final String? currentFarmId;
  final double? landAcres;
  final String? cropType;
  final String? stateName;
  final String? irrigationStatus;
  final String? ownershipType;

  const OpportunityCenterScreen({
    super.key,
    required this.opportunityRepository,
    this.isHindi = false,
    this.currentFarmId,
    this.landAcres,
    this.cropType,
    this.stateName,
    this.irrigationStatus,
    this.ownershipType,
  });

  @override
  State<OpportunityCenterScreen> createState() => _OpportunityCenterScreenState();
}

class _OpportunityCenterScreenState extends State<OpportunityCenterScreen> {
  bool _isLoading = false;
  bool _isOffline = false;
  String? _errorMessage;

  List<OpportunityModel> _opportunities = [];
  List<OpportunityTrackingModel> _trackingRecords = [];
  OpportunityType? _selectedTypeFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOffline = false;
    });

    try {
      final opps = await widget.opportunityRepository.getOpportunities(
        type: _selectedTypeFilter,
      );

      List<OpportunityTrackingModel> tracking = [];
      try {
        tracking = await widget.opportunityRepository.getTracking();
      } catch (_) {
        // Tracking read requires live backend; if offline or fails, keep empty
      }

      if (mounted) {
        setState(() {
          _opportunities = opps;
          _trackingRecords = tracking;
          _isOffline = widget.opportunityRepository.isLastFetchOffline;
          _isLoading = false;
        });
      }
    } on NetworkUnavailableException {
      if (mounted) {
        setState(() {
          _opportunities = [];
          _isOffline = true;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  OpportunityTrackingModel? _getTrackingFor(String oppId) {
    try {
      return _trackingRecords.firstWhere(
        (t) => t.opportunityId == oppId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHi = widget.isHindi;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHi ? 'अवसर एवं सरकारी योजना केंद्र' : 'Opportunity & Scheme Center',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              isHi ? 'सत्यापित कृषि योजनाएं एवं मार्गदर्शन' : 'Verified Agricultural Schemes & Guidance',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isHi ? 'रीफ्रेश' : 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isOffline) _buildOfflineBanner(),
          if (_errorMessage != null) _buildErrorBanner(),
          _buildCategoryFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _opportunities.isEmpty
                    ? _buildEmptyState()
                    : _buildOpportunityList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    final isHi = widget.isHindi;
    return Container(
      key: const Key('opportunity_offline_banner'),
      width: double.infinity,
      color: Colors.amber.shade900.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isHi
                  ? 'ऑफ़लाइन मोड: कैश्ड कैटलॉग प्रदर्शित। पात्रता जांच एवं ट्रैकिंग हेतु इंटरनेट आवश्यक है।'
                  : 'Offline Mode: Displaying cached catalogue. Eligibility and tracking require connectivity.',
              style: const TextStyle(color: Colors.amber, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    final isHi = widget.isHindi;
    return Container(
      key: const Key('opportunity_error_banner'),
      width: double.infinity,
      color: PraharTheme.alertRose.withOpacity(0.25),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: PraharTheme.alertRose, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? (isHi ? 'त्रुटि उत्पन्न हुई' : 'An error occurred'),
              style: const TextStyle(color: PraharTheme.alertRose, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _loadData,
            child: Text(isHi ? 'पुनः प्रयास' : 'Retry', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final isHi = widget.isHindi;
    final categories = <OpportunityType?>[
      null,
      OpportunityType.scheme,
      OpportunityType.subsidy,
      OpportunityType.loan,
      OpportunityType.insurance,
      OpportunityType.support,
    ];

    String getLabel(OpportunityType? type) {
      if (type == null) return isHi ? 'सभी' : 'All';
      switch (type) {
        case OpportunityType.scheme:
          return isHi ? 'योजनाएं' : 'Schemes';
        case OpportunityType.subsidy:
          return isHi ? 'सब्सिडी' : 'Subsidies';
        case OpportunityType.loan:
          return isHi ? 'ऋण (लोन)' : 'Loans';
        case OpportunityType.insurance:
          return isHi ? 'फसल बीमा' : 'Insurance';
        case OpportunityType.support:
          return isHi ? 'सहायता' : 'Support';
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: categories.map((type) {
          final isSelected = _selectedTypeFilter == type;
          final typeKey = type != null ? type.toDbString().toLowerCase() : 'all';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              key: Key('category_filter_$typeKey'),
              label: Text(getLabel(type)),
              selected: isSelected,
              selectedColor: PraharTheme.primaryGreen.withOpacity(0.25),
              checkmarkColor: PraharTheme.primaryGreen,
              labelStyle: TextStyle(
                color: isSelected ? PraharTheme.primaryGreen : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              backgroundColor: PraharTheme.cardBg,
              side: BorderSide(
                color: isSelected ? PraharTheme.primaryGreen : PraharTheme.borderGreen,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedTypeFilter = type;
                });
                _loadData();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOpportunityList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: _opportunities.length,
      itemBuilder: (context, index) {
        final opp = _opportunities[index];
        final tracking = _getTrackingFor(opp.id);
        return _buildOpportunityCard(opp, tracking);
      },
    );
  }

  Widget _buildOpportunityCard(OpportunityModel opp, OpportunityTrackingModel? tracking) {
    final isHi = widget.isHindi;

    Color typeColor = PraharTheme.primaryGreen;
    switch (opp.type) {
      case OpportunityType.subsidy:
        typeColor = PraharTheme.alertSky;
        break;
      case OpportunityType.loan:
        typeColor = PraharTheme.alertAmber;
        break;
      case OpportunityType.insurance:
        typeColor = Colors.purpleAccent;
        break;
      case OpportunityType.support:
        typeColor = Colors.tealAccent;
        break;
      case OpportunityType.scheme:
        typeColor = PraharTheme.primaryGreen;
        break;
    }

    return Card(
      key: Key('opportunity_card_${opp.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openOpportunityDetail(opp),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: typeColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      opp.type.toDbString(),
                      style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified, color: Colors.greenAccent, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'VERIFIED',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (tracking != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: PraharTheme.alertAmber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: PraharTheme.alertAmber.withOpacity(0.5)),
                      ),
                      child: Text(
                        isHi ? tracking.status.labelHi() : tracking.status.labelEn(),
                        style: const TextStyle(color: PraharTheme.alertAmber, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isHi ? opp.titleHi : opp.titleEn,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                opp.departmentAuthority,
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
              const SizedBox(height: 8),
              Text(
                isHi ? opp.benefitsSummaryHi : opp.benefitsSummaryEn,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isHi ? 'विवरण एवं पात्रता जांचें →' : 'View Details & Check Eligibility →',
                    style: const TextStyle(fontSize: 12, color: PraharTheme.primaryGreen, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: PraharTheme.primaryGreen),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isHi = widget.isHindi;
    return Center(
      key: const Key('opportunity_empty_state'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: Colors.white30),
          const SizedBox(height: 12),
          Text(
            isHi ? 'कोई योजना उपलब्ध नहीं है।' : 'No opportunities found for this category.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(backgroundColor: PraharTheme.primaryGreen),
            child: Text(isHi ? 'पुनः लोड करें' : 'Reload'),
          ),
        ],
      ),
    );
  }

  void _openOpportunityDetail(OpportunityModel opp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PraharTheme.darkBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _OpportunityDetailSheet(
        opportunity: opp,
        repository: widget.opportunityRepository,
        initialTracking: _getTrackingFor(opp.id),
        isHindi: widget.isHindi,
        currentFarmId: widget.currentFarmId,
        landAcres: widget.landAcres,
        cropType: widget.cropType,
        stateName: widget.stateName,
        irrigationStatus: widget.irrigationStatus,
        ownershipType: widget.ownershipType,
        onTrackingUpdated: (newTracking) {
          setState(() {
            _trackingRecords.removeWhere((t) => t.opportunityId == opp.id);
            _trackingRecords.insert(0, newTracking);
          });
        },
      ),
    );
  }
}

class _OpportunityDetailSheet extends StatefulWidget {
  final OpportunityModel opportunity;
  final OpportunityRepository repository;
  final OpportunityTrackingModel? initialTracking;
  final bool isHindi;
  final String? currentFarmId;
  final double? landAcres;
  final String? cropType;
  final String? stateName;
  final String? irrigationStatus;
  final String? ownershipType;
  final ValueChanged<OpportunityTrackingModel> onTrackingUpdated;

  const _OpportunityDetailSheet({
    required this.opportunity,
    required this.repository,
    this.initialTracking,
    required this.isHindi,
    this.currentFarmId,
    this.landAcres,
    this.cropType,
    this.stateName,
    this.irrigationStatus,
    this.ownershipType,
    required this.onTrackingUpdated,
  });

  @override
  State<_OpportunityDetailSheet> createState() => _OpportunityDetailSheetState();
}

class _OpportunityDetailSheetState extends State<_OpportunityDetailSheet> {
  bool _isEvaluating = false;
  EligibilityEvaluationModel? _evaluation;
  String? _evaluationError;

  bool _isSavingTracking = false;
  late ApplicationTrackingStatus _currentStatus;
  late TextEditingController _notesController;
  final Set<String> _checkedDocs = {};

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.initialTracking?.status ?? ApplicationTrackingStatus.notStarted;
    _notesController = TextEditingController(text: widget.initialTracking?.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkEligibility() async {
    setState(() {
      _isEvaluating = true;
      _evaluationError = null;
    });

    try {
      final res = await widget.repository.checkEligibility(
        opportunityId: widget.opportunity.id,
        farmId: widget.currentFarmId,
        landAcres: widget.landAcres,
        cropType: widget.cropType,
        state: widget.stateName,
        irrigationStatus: widget.irrigationStatus,
        ownershipType: widget.ownershipType,
      );

      if (mounted) {
        setState(() {
          _evaluation = res;
          _isEvaluating = false;
        });
      }
    } on NetworkUnavailableException {
      if (mounted) {
        setState(() {
          _evaluationError = widget.isHindi
              ? 'पात्रता मूल्यांकन के लिए सक्रिय इंटरनेट कनेक्शन आवश्यक है।'
              : 'Eligibility evaluation requires an active internet connection.';
          _isEvaluating = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _evaluationError = e.message;
          _isEvaluating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _evaluationError = e.toString();
          _isEvaluating = false;
        });
      }
    }
  }

  Future<void> _saveTracking() async {
    setState(() {
      _isSavingTracking = true;
    });

    try {
      final updated = await widget.repository.updateTracking(
        opportunityId: widget.opportunity.id,
        status: _currentStatus,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      widget.onTrackingUpdated(updated);

      if (mounted) {
        setState(() {
          _isSavingTracking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isHindi ? 'स्थिति सफलतापूर्वक अपडेट की गई' : 'Status updated successfully',
            ),
            backgroundColor: PraharTheme.primaryGreen,
          ),
        );
      }
    } on NetworkUnavailableException {
      if (mounted) {
        setState(() {
          _isSavingTracking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isHindi
                  ? 'ट्रैकिंग अपडेट हेतु सक्रिय इंटरनेट आवश्यक है'
                  : 'Active internet required to update tracking status',
            ),
            backgroundColor: PraharTheme.alertRose,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingTracking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: PraharTheme.alertRose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final opp = widget.opportunity;
    final isHi = widget.isHindi;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ListView(
            controller: scrollController,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title & Category
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHi ? opp.titleHi : opp.titleEn,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opp.departmentAuthority,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: PraharTheme.borderGreen, height: 24),

              // Overview Section
              _buildSectionTitle(isHi ? 'विवरण एवं लाभ' : 'Overview & Benefits'),
              Text(
                isHi ? opp.descriptionHi : opp.descriptionEn,
                style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PraharTheme.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PraharTheme.borderGreen),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHi ? 'मुख्य लाभ:' : 'Key Benefit:',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PraharTheme.primaryGreen),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHi ? opp.benefitsSummaryHi : opp.benefitsSummaryEn,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isHi ? 'लक्षित किसान वर्ग:' : 'Target Profile:',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHi ? opp.targetProfileHi : opp.targetProfileEn,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Eligibility Assistant Section
              _buildSectionTitle(isHi ? 'पात्रता सहायक (Deterministic Guidance)' : 'Eligibility Assistant'),
              _buildEligibilitySection(),
              const SizedBox(height: 20),

              // Required Documents Checklist
              _buildSectionTitle(isHi ? 'आवश्यक दस्तावेज चेकलिस्ट' : 'Required Documents Checklist'),
              ...opp.requiredDocuments.map((doc) {
                final isChecked = _checkedDocs.contains(doc);
                return CheckboxListTile(
                  dense: true,
                  value: isChecked,
                  activeColor: PraharTheme.primaryGreen,
                  title: Text(doc, style: const TextStyle(fontSize: 13, color: Colors.white)),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _checkedDocs.add(doc);
                      } else {
                        _checkedDocs.remove(doc);
                      }
                    });
                  },
                );
              }),
              const SizedBox(height: 20),

              // Application Steps & Official Link
              _buildSectionTitle(isHi ? 'आवेदन प्रक्रिया' : 'Application Steps'),
              ...opp.applicationSteps.map((step) => _buildStepCard(step)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.open_in_new, color: Colors.lightBlueAccent, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Official Government Portal',
                          style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opp.officialPortalUrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12, decoration: TextDecoration.underline),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isHi
                          ? 'नोट: यह बाहरी सरकारी पोर्टल सूचनात्मक नेविगेशन हेतु है। प्रहार मंच किसानों की ओर से स्वतः आवेदन जमा नहीं करता।'
                          : 'Notice: External government URLs are provided for informational navigation only. PRAHAR does not automatically submit applications.',
                      style: const TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Application Tracking Section
              _buildSectionTitle(isHi ? 'मेरी आवेदन स्थिति (Application Tracking)' : 'My Application Tracking'),
              _buildTrackingSection(),
              const SizedBox(height: 24),

              // Mandatory Guidance Disclaimer
              _buildMandatoryDisclaimer(opp.disclaimer),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PraharTheme.primaryGreen),
      ),
    );
  }

  Widget _buildEligibilitySection() {
    final isHi = widget.isHindi;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PraharTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PraharTheme.borderGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHi
                ? 'अपने खेत व प्रोफाइल विवरण के आधार पर पात्रता की जांच करें:'
                : 'Evaluate guidance based on your farm profile and land records:',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          if (_isEvaluating)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('check_eligibility_button'),
                icon: const Icon(Icons.fact_check, size: 18),
                label: Text(isHi ? 'पात्रता जांचें' : 'Check Eligibility'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PraharTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _checkEligibility,
              ),
            ),
          if (_evaluationError != null) ...[
            const SizedBox(height: 8),
            Text(_evaluationError!, style: const TextStyle(color: PraharTheme.alertRose, fontSize: 12)),
          ],
          if (_evaluation != null) ...[
            const SizedBox(height: 14),
            _buildEvaluationResultBadge(_evaluation!),
            const SizedBox(height: 10),
            if (_evaluation!.matchedCriteriaEn.isNotEmpty) ...[
              Text(
                isHi ? 'सत्यापित मानदंड:' : 'Matched Criteria:',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.greenAccent),
              ),
              ...(_evaluation!.matchedCriteriaEn).map(
                (c) => Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check, size: 14, color: Colors.greenAccent),
                      const SizedBox(width: 4),
                      Expanded(child: Text(c, style: const TextStyle(fontSize: 12, color: Colors.white))),
                    ],
                  ),
                ),
              ),
            ],
            if (_evaluation!.missingInformationEn.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                isHi ? 'अधूरी जानकारी:' : 'Missing Information:',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
              ),
              ...(_evaluation!.missingInformationEn).map(
                (m) => Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.amberAccent),
                      const SizedBox(width: 4),
                      Expanded(child: Text(m, style: const TextStyle(fontSize: 12, color: Colors.white))),
                    ],
                  ),
                ),
              ),
            ],
            if (_evaluation!.unmatchedCriteriaEn.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                isHi ? 'अपात्र मानदंड:' : 'Unmatched Criteria:',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PraharTheme.alertRose),
              ),
              ...(_evaluation!.unmatchedCriteriaEn).map(
                (u) => Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.close, size: 14, color: PraharTheme.alertRose),
                      const SizedBox(width: 4),
                      Expanded(child: Text(u, style: const TextStyle(fontSize: 12, color: Colors.white))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEvaluationResultBadge(EligibilityEvaluationModel eval) {
    Color badgeColor = PraharTheme.primaryGreen;
    switch (eval.status) {
      case EligibilityResultStatus.likelyEligible:
        badgeColor = Colors.greenAccent;
        break;
      case EligibilityResultStatus.mayBeEligible:
        badgeColor = Colors.amberAccent;
        break;
      case EligibilityResultStatus.insufficientInformation:
        badgeColor = Colors.lightBlueAccent;
        break;
      case EligibilityResultStatus.likelyNotEligible:
        badgeColor = PraharTheme.alertRose;
        break;
    }

    return Container(
      key: const Key('eligibility_status_badge'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor),
      ),
      child: Center(
        child: Text(
          widget.isHindi ? eval.status.labelHi() : eval.status.labelEn(),
          style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildStepCard(OpportunityApplicationStepModel step) {
    final isHi = widget.isHindi;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PraharTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PraharTheme.borderGreen),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: PraharTheme.primaryGreen.withOpacity(0.25),
            child: Text(
              '${step.stepNumber}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PraharTheme.primaryGreen),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHi ? step.titleHi : step.titleEn,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  isHi ? step.descriptionHi : step.descriptionEn,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingSection() {
    final isHi = widget.isHindi;
    final statuses = ApplicationTrackingStatus.values;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PraharTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PraharTheme.borderGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<ApplicationTrackingStatus>(
            key: const Key('tracking_status_dropdown'),
            value: _currentStatus,
            dropdownColor: PraharTheme.cardBg,
            decoration: InputDecoration(
              labelText: isHi ? 'मेरी वर्तमान आवेदन स्थिति' : 'Current Application Status',
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: statuses.map((st) {
              return DropdownMenuItem(
                value: st,
                child: Text(
                  isHi ? st.labelHi() : st.labelEn(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _currentStatus = val;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('tracking_notes_field'),
            controller: _notesController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: isHi ? 'टिप्पणी / संदर्भ संख्या (वैकल्पिक)' : 'Notes / Ref Number (Optional)',
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isHi
                ? 'नोट: USER_SUBMITTED यह दर्शाता है कि आपने आधिकारिक पोर्टल पर स्वयं आवेदन जमा किया है। प्रहार आपकी ओर से आवेदन नहीं भेजता।'
                : 'Note: USER_SUBMITTED indicates you have manually submitted an application at the official portal. PRAHAR does not submit on your behalf.',
            style: const TextStyle(fontSize: 11, color: Colors.white60, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('save_status_button'),
              icon: _isSavingTracking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 16),
              label: Text(isHi ? 'स्थिति सहेजें' : 'Save Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PraharTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSavingTracking ? null : _saveTracking,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMandatoryDisclaimer(String disclaimer) {
    return Container(
      key: const Key('mandatory_disclaimer_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              disclaimer,
              style: const TextStyle(color: Colors.amber, fontSize: 11, fontStyle: FontStyle.italic, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
